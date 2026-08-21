FROM php:8.4-fpm

ENV DEBIAN_FRONTEND=noninteractive

RUN usermod -u 1000 www-data
RUN groupmod -g 1000 www-data
RUN usermod -s /bin/bash www-data

RUN echo "[INFO] Install essential utils"
RUN apt update
RUN apt install -y gnupg2 curl wget git locales tzdata nano vim jq unzip postfix postgresql-client libfcgi0ldbl lsb-release ssh

RUN echo "[INFO] Generate en_US.UTF-8 default locale"
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN locale-gen en_US.UTF-8
RUN update-locale LANG=en_US.UTF-8
RUN export LC_ALL=en_US.UTF-8

RUN echo "[INFO] Set timezone"
RUN rm -f /etc/localtime
RUN ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime

RUN echo "[INFO] Install php requirements"
RUN apt install -y libicu-dev libpq-dev libzip-dev zip libpng-dev

RUN echo "[INFO] Install php packages"
RUN docker-php-ext-install opcache
RUN docker-php-ext-configure intl
RUN docker-php-ext-install intl
RUN docker-php-ext-install bcmath
RUN docker-php-ext-install sockets
RUN docker-php-ext-install pdo_pgsql
RUN docker-php-ext-install zip
RUN docker-php-ext-install gd

RUN echo "[INFO] Install xdebug"
RUN pecl install xdebug-3.4.2
    # - docker-php-ext-enable xdebug

RUN echo "[INFO] Install dump-init"
RUN curl -sL https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64 -o /usr/local/bin/dumb-init
RUN chmod +x /usr/local/bin/dumb-init

RUN echo "[INFO] Install composer"
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN echo "[INFO] copy services postfix"
RUN cp -f /etc/services /var/spool/postfix/etc/services
RUN chown -R postfix /var/spool/postfix/

RUN mkdir /run/php-fpm
