FROM ubuntu:trusty

RUN echo Asia/Hong_Kong | tee /etc/timezone && dpkg-reconfigure --frontend noninteractive tzdata

RUN apt-get update && apt-get install -y curl

RUN curl http://dl.hhvm.com/conf/hhvm.gpg.key | apt-key add - && \
    echo deb http://dl.hhvm.com/ubuntu trusty main | tee /etc/apt/sources.list.d/hhvm.list && \
    apt-get update && \
    apt-get install -y hhvm nginx && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www

COPY nginx-hhvm /etc/nginx/sites-available/hhvm

RUN rm -f /etc/nginx/sites-enabled/default && ln -s /etc/nginx/sites-available/hhvm /etc/nginx/sites-enabled/

RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    ln -sf /dev/stderr /var/log/hhvm/error.log

VOLUME ["/var/www"]

EXPOSE 5000

CMD service hhvm start && nginx -g "daemon off;"

