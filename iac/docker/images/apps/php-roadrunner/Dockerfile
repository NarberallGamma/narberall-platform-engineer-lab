ARG PHP_IMAGE=php:7.4-cli-bullseye
ARG COMPOSER_IMAGE=composer:1.10
ARG ROADRUNNER=spiralscout/roadrunner:1.9.2

FROM ${ROADRUNNER} AS roadrunner
FROM ${COMPOSER_IMAGE} AS composer
FROM ${PHP_IMAGE}

RUN apt-get update && apt-get install -y unzip

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions pdo_mysql amqp-^1.10 bcmath calendar exif ffi gd gettext imagick intl mysqli pcntl redis-^5.3 shmop sockets sysvmsg sysvsem sysvshm xsl zip

RUN mv $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
#COPY /docker/php/docker-php-opcache.ini $PHP_INI_DIR/conf.d/docker-php-opcache.ini

# Copy Composer
COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY --from=roadrunner /usr/bin/rr /usr/local/bin/rr

WORKDIR /app
COPY ./ /app

RUN composer install
RUN php vendor/doctrine/orm/bin/doctrine orm:generate-proxies
