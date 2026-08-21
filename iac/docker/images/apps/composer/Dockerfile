FROM php:8.1-fpm-buster

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    nano \
    curl \
    git \
    libmemcached-dev \
    libz-dev \
    libpq-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    libssl-dev \
    libmcrypt-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    && sed -i 's|mozilla/DST_Root_CA_X3.crt|!mozilla/DST_Root_CA_X3.crt|g' /etc/ca-certificates.conf \
    && update-ca-certificates \
    && apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

RUN docker-php-ext-install gd zip
RUN docker-php-ext-configure gd

WORKDIR "/app"

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --version 2.3.5 \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer \
    && cd /usr/local/bin/

COPY composer.sh /composer.sh
RUN chmod +x /composer.sh

ENTRYPOINT ["sh","/composer.sh"]
