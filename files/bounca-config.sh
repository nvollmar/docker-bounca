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

  echo "
psql:
  dbname: ${DB_NAME:-bounca}
  username: ${DB_USER:-bounca}
  password: ${DB_PWD:-bounca}
  host: ${DB_HOST:-postgres}
  port: ${DB_PORT:-5432}

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
  #username: ${SMTP_USERNAME:-}
  #password: ${SMTP_PASSWORD:-}
  connection: ${SMTP_CONNECTION:-none}
  admin: ${ADMIN_MAIL:-admin@example.com}
  from: ${FROM_MAIL:-no-reply@example.com}

certificate-engine:
  # allowed values: ed25519, rsa
  # Ed25519 is a a modern, fast and safe key algorithm, however not supported by all operating systems, like MacOS.
  # Keep the 'rsa' option if unsure. Root and intermediate keys are 4096 bits, client and server certificates
  # use 2048 bits keys.
  key_algorithm: rsa

registration:
  # allowed values: mandatory, optional, off
  email_verification: off" > ${CONFIG_FILE}
fi

# netcat test PSQL
if [ "$(nc -zv "${DB_HOST:-postgres}" "${DB_PORT:-5432}"; echo $?)" -ne 0 ]; then
  echo "${DB_HOST:-postgres} PSQL server is not reachable on port ${DB_PORT:-5432}"
  exit 1
fi

cd "${DOCROOT}" && pwd
python3 manage.py migrate
python3 manage.py collectstatic

if [ -z "${BOUNCA_FQDN+x}" ]; then
  echo "BOUNCA_FQDN variable should be defined but is not, exiting..." >/dev/stderr
  exit 1
elif [[ -n "${BOUNCA_FQDN}" ]]; then
  python3 manage.py site "${BOUNCA_FQDN}"
fi

# Remove the home parameter which was set to use virtual env in default configuration
sed -i '/^home/d' /etc/uwsgi/apps-enabled/bounca.ini
sed -i 's#chmod-socket = 700#chmod-socket = 777#g' /etc/uwsgi/apps-enabled/bounca.ini

# Check Nginx config
nginx -t

# Start uwsgi
mkdir -pv /run/uwsgi/app/bounca
chown -R www-data:www-data /srv/www/bounca /run/uwsgi
uwsgi --ini /etc/uwsgi/apps-enabled/bounca.ini --die-on-term &
