FROM --platform=$BUILDPLATFORM golang:1.21 as build

ARG TARGETPLATFORM
#RUN echo "nameserver 192.168.11.1" > /etc/resolv.conf

FROM nginx:1.25.3-bookworm
ENV DOCROOT=/srv/www/bounca \
    LOGDIR=/var/log/bounca \
    ETCDIR=/etc/bounca \
    UWSGIDIR=/etc/uwsgi \
    NGINXDIR=/etc/nginx \
    BOUNCA_USER=www-data \
    BOUNCA_GROUP=www-data

RUN apt-get update \
  && apt-get install -qy \
    gettext netcat-traditional nginx python3 python3-dev python3-setuptools python-is-python3 uwsgi uwsgi-plugin-python3 virtualenv python3-virtualenv python3-pip \
    wget ca-certificates openssl \
  && apt-get install -qy python3-psycopg2

RUN wget -P /srv/www --content-disposition https://gitlab.com/bounca/bounca/-/package_files/102483429/download \
  && tar -xzvf /srv/www/bounca.tar.gz -C /srv/www \
  && rm /srv/www/bounca.tar.gz

RUN mkdir -pv ${LOGDIR} ${DOCROOT} ${ETCDIR} /etc/nginx/sites-available /etc/nginx/sites-enabled \
  && rm -fv /etc/nginx/conf.d/default.conf \
  && rmdir /etc/nginx/conf.d \
  && ln -s /etc/nginx/sites-enabled /etc/nginx/conf.d \
  && cp -v ${DOCROOT}/etc/nginx/bounca /etc/nginx/sites-available/bounca.conf \
  && ln -s /etc/nginx/sites-available/bounca.conf /etc/nginx/sites-enabled/bounca.conf \
  && cp -v ${DOCROOT}/etc/uwsgi/bounca.ini /etc/uwsgi/apps-available/bounca.ini \
  && ln -s /etc/uwsgi/apps-available/bounca.ini /etc/uwsgi/apps-enabled/bounca.ini \
  && chown -R ${BOUNCA_USER}:${BOUNCA_GROUP} ${LOGDIR} ${DOCROOT} ${ETCDIR} ${UWSGIDIR} ${NGINXDIR} \
  && chown ${BOUNCA_USER}:${BOUNCA_GROUP} /var/run /var/cache/nginx


RUN sed -i '/psycopg2-binary/d' ${DOCROOT}/requirements.txt

RUN pip install --no-cache-dir --break-system-packages -r ${DOCROOT}/requirements.txt

RUN ln -sfT /dev/stdout "/var/log/nginx/bounca-access.log" \
  && ln -sfT /dev/stdout "/var/log/nginx/bounca-error.log" \
  && apt-get clean \
  && rm -rfv /tmp/* /var/tmp/* /var/lib/apt/lists/* ${DOCROOT}/.git \
  ;

COPY files/ /docker-entrypoint.d/

WORKDIR ${DOCROOT}

VOLUME ${DOCROOT}
