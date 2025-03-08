FROM nginxinc/nginx-unprivileged:1.27-bookworm

ARG BOUNCA_FILE_VERSION=111380104

ENV BOUNCA_FILE_VERSION=${BOUNCA_FILE_VERSION} \
    DOCROOT=/srv/www/bounca \
    LOGDIR=/var/log/bounca \
    ETCDIR=/etc/bounca \
    UWSGIDIR=/etc/uwsgi \
    NGINXDIR=/etc/nginx \
    BOUNCA_USER=nginx \
    BOUNCA_GROUP=nginx

COPY files/bounca-config.sh /docker-entrypoint.d/bounca-config.sh

USER root

RUN apt-get update && \
    apt-get install -qy \
      gettext netcat-traditional nginx python3 python3-dev python3-setuptools \
      python-is-python3 uwsgi uwsgi-plugin-python3 python3-pip \
      wget ca-certificates openssl python3-psycopg2 && \
    mkdir -pv ${LOGDIR} ${DOCROOT} ${ETCDIR} /etc/nginx/sites-available /etc/nginx/sites-enabled /run/uwsgi/app/bounca && \
    wget -P /tmp --content-disposition https://gitlab.com/bounca/bounca/-/package_files/${BOUNCA_FILE_VERSION}/download && \
    tar -xzvf /tmp/bounca.tar.gz -C /srv/www && \
    pip install --no-cache-dir --break-system-packages -r ${DOCROOT}/requirements.txt && \
    rm -rfv /etc/nginx/conf.d && \
    ln -s /etc/nginx/sites-enabled /etc/nginx/conf.d && \
    cp -v ${DOCROOT}/etc/nginx/bounca /etc/nginx/sites-available/bounca.conf && \
    ln -s /etc/nginx/sites-available/bounca.conf /etc/nginx/sites-enabled/bounca.conf && \
    sed -i 's#80#8080#g' /etc/nginx/sites-available/bounca.conf && \
    cp -v ${DOCROOT}/etc/uwsgi/bounca.ini /etc/uwsgi/apps-available/bounca.ini && \
    ln -s /etc/uwsgi/apps-available/bounca.ini /etc/uwsgi/apps-enabled/bounca.ini && \
    sed -i 's/www-data/nginx/g' /etc/uwsgi/apps-available/bounca.ini && \
    chown -R ${BOUNCA_USER}:${BOUNCA_GROUP} ${LOGDIR} ${DOCROOT} ${ETCDIR} ${NGINXDIR} ${UWSGIDIR} \
      /var/run /var/cache/nginx /var/log/uwsgi /run/uwsgi && \
    sed -i '/psycopg2-binary/d' ${DOCROOT}/requirements.txt && \
    chmod +x /docker-entrypoint.d/bounca-config.sh && \
    ln -sfT /dev/stdout "/var/log/nginx/bounca-access.log" && \
    ln -sfT /dev/stdout "/var/log/nginx/bounca-error.log" && \
    apt-get clean && \
    rm -rfv /tmp/* /var/tmp/* /var/lib/apt/lists/* ${DOCROOT}/.git

USER nginx

WORKDIR ${DOCROOT}

EXPOSE 8080
