ARG PHP_IMAGE=php:8.2.4-cli-buster
ARG COMPOSER_IMAGE=composer:2.5.5
ARG DOCKER_PHP_EXETENSION_INSTALLER=1.5.15

FROM ${COMPOSER_IMAGE} as composer
FROM ${PHP_IMAGE}

RUN apt-get update && apt-get install -y unzip

ADD https://github.com/mlocati/docker-php-extension-installer/releases/download/2.7.7/install-php-extensions /usr/local/bin/

RUN chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions pdo_mysql amqp sockets swoole redis memcached

RUN mv $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY /docker/php/docker-php-opcache.ini $PHP_INI_DIR/conf.d/docker-php-opcache.ini

# Copy Composer
COPY --from=composer /usr/bin/composer /usr/bin/composer

WORKDIR /app

COPY ./ /app

# Composer
RUN composer install --no-dev --classmap-authoritative
RUN php artisan key:generate
RUN php artisan optimize
RUN php artisan config:cache
RUN php artisan route:cache
