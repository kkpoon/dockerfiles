FROM ubuntu:trusty

RUN echo Asia/Hong_Kong | tee /etc/timezone && dpkg-reconfigure --frontend noninteractive tzdata

COPY installer.sh /tmp/installer.sh

RUN sh /tmp/installer.sh
RUN rm /tmp/installer.sh

RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    ln -sf /dev/stdout /var/log/php5-fpm.log && \
    ln -sf /dev/stdout /var/tmp/phd/log/daemons.log

VOLUME ["/data/storage", "/data/repo"]

EXPOSE 80

CMD su -c "/opt/phacility/phabricator/bin/config set phabricator.base-uri '$BASE_URL'" - phabricator && \
service php5-fpm restart && \
service ssh restart && \
su -c "/opt/phacility/phabricator/bin/phd start" - phd-user && \
nginx -g "daemon off;"
