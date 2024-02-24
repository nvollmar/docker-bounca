#!/usr/bin/env bash

set -euo pipefail
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin
CONFIG_FILE=/etc/bounca/services.yaml

# Setup config file if it does not exist
if [[ ! -f ${CONFIG_FILE} ]]; then

  if [ -z "${BOUNCA_DJANGO_SECRET+x}" ]; then
    BOUNCA_DJANGO_SECRET=$(openssl rand -base64 20)
    echo "...generating random BOUNCA_DJANGO_SECRET."
  fi

  cat <<EOF >${CONFIG_FILE}
psql:
  dbname: ${POSTGRES_DB:-bounca}
  username: ${POSTGRES_USER:-bounca}
  password: ${POSTGRES_PASSWORD:-bounca}
  host: ${POSTGRES_HOST:-postgres}
  port: ${POSTGRES_PORT:-5432}

admin:
  enabled: True
  superuser_signup: True

django:
  debug: True
  secret_key: '${BOUNCA_DJANGO_SECRET}'
  hosts:
    - localhost
    - 127.0.0.1
    - 172.16.0.0/12
    - ${BOUNCA_FQDN:-bounca}

mail:
  host: ${SMTP_HOST:-localhost}
  port: ${SMTP_PORT:-25}
  username: ${SMTP_USER:-}
  password: ${SMTP_PASSWORD:-}
  connection: ${SMTP_CONNECTION:-none}
  admin: ${DJANGO_SUPERUSER_EMAIL:-admin@example.com}
  from: ${FROM_EMAIL:-no-reply@example.com}

certificate-engine:
  key_algorithm: rsa

registration:
  email_verification: off
EOF
fi

# wait for postgres
while true; do
  if nc -zv "${POSTGRES_HOST:-postgres}" "${POSTGRES_PORT:-5432}" > /dev/null; then
    echo "${POSTGRES_HOST:-postgres} PSQL server is reachable on port ${POSTGRES_PORT:-5432}. Let's go!"
    break
  else
    echo "${POSTGRES_HOST:-postgres} PSQL server is not reachable on port ${POSTGRES_PORT:-5432}. Waiting..."
    sleep 3
  fi
done

# cd "${DOCROOT}"
python3 manage.py migrate
python3 manage.py collectstatic --noinput

if [ -z "${BOUNCA_FQDN+x}" ]; then
  echo "BOUNCA_FQDN variable should be defined but is not, exiting..." >/dev/stderr
  exit 1
elif [[ -n "${BOUNCA_FQDN}" ]]; then
  python3 manage.py site "${BOUNCA_FQDN}"
fi

# Create Django Superuser
if [ -n "${DJANGO_SUPERUSER_PASSWORD-}" ]; then
  python3 manage.py createsuperuser \
    --noinput \
    --username "${DJANGO_SUPERUSER_NAME:-superuser}" \
    --email "${DJANGO_SUPERUSER_EMAIL:-superuser@example.com}" >/dev/null || true
fi

# Remove the home parameter which was set to use virtual env in default configuration
sed -i '/^home/d' /etc/uwsgi/apps-enabled/bounca.ini
sed -i 's#chmod-socket = 700#chmod-socket = 777#g' /etc/uwsgi/apps-enabled/bounca.ini

# Set non-default port
sed -i 's#80#8080#g' /etc/nginx/sites-available/bounca.conf

# Check Nginx config
nginx -t

# Start uwsgi
mkdir -pv /run/uwsgi/app/bounca
uwsgi --ini /etc/uwsgi/apps-enabled/bounca.ini --die-on-term &
