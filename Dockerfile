FROM nginx:latest

ARG BOUNCA_FILE_VERSION=102483429

ENV BOUNCA_FILE_VERSION=${BOUNCA_FILE_VERSION} \
    DOCROOT=/srv/www/bounca \
    LOGDIR=/var/log/bounca \
    ETCDIR=/etc/bounca \
    UWSGIDIR=/etc/uwsgi \
    NGINXDIR=/etc/nginx \
    BOUNCA_USER=www-data \
    BOUNCA_GROUP=www-data

COPY files/bounca-config.sh /docker-entrypoint.d/bounca-config.sh

RUN apt-get update && \
    apt-get install -qy \
    gettext netcat-traditional nginx python3 python3-dev python3-setuptools \
    python-is-python3 uwsgi uwsgi-plugin-python3 virtualenv python3-virtualenv \
    python3-pip wget ca-certificates openssl python3-psycopg2 net-tools && \
    wget -P /srv/www --content-disposition https://gitlab.com/bounca/bounca/-/package_files/${BOUNCA_FILE_VERSION}/download && \
    tar -xzvf /srv/www/bounca.tar.gz -C /srv/www && \
    rm /srv/www/bounca.tar.gz && \
    mkdir -pv ${LOGDIR} ${DOCROOT} ${ETCDIR} /etc/nginx/sites-available /etc/nginx/sites-enabled && \
    rm -fv /etc/nginx/conf.d/default.conf && \
    rmdir /etc/nginx/conf.d && \
    ln -s /etc/nginx/sites-enabled /etc/nginx/conf.d && \
    cp -v ${DOCROOT}/etc/nginx/bounca /etc/nginx/sites-available/bounca.conf && \
    ln -s /etc/nginx/sites-available/bounca.conf /etc/nginx/sites-enabled/bounca.conf && \
    cp -v ${DOCROOT}/etc/uwsgi/bounca.ini /etc/uwsgi/apps-available/bounca.ini && \
    ln -s /etc/uwsgi/apps-available/bounca.ini /etc/uwsgi/apps-enabled/bounca.ini && \
    chown -R ${BOUNCA_USER}:${BOUNCA_GROUP} ${LOGDIR} ${DOCROOT} ${ETCDIR} ${UWSGIDIR} ${NGINXDIR} && \
    chown ${BOUNCA_USER}:${BOUNCA_GROUP} /var/run /var/cache/nginx && \
    sed -i '/psycopg2-binary/d' ${DOCROOT}/requirements.txt && \
    pip install --no-cache-dir --break-system-packages -r ${DOCROOT}/requirements.txt && \
    chmod +x /docker-entrypoint.d/bounca-config.sh && \
    ln -sfT /dev/stdout "/var/log/nginx/bounca-access.log" && \
    ln -sfT /dev/stdout "/var/log/nginx/bounca-error.log" && \
    apt-get clean && \
    rm -rfv /tmp/* /var/tmp/* /var/lib/apt/lists/* ${DOCROOT}/.git

WORKDIR ${DOCROOT}

EXPOSE 8080
