FROM phpdockerio/php:7.4-fpm

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    nano \
    && apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

WORKDIR "/app"

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --version 2.7.7 \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer \
    && cd /usr/local/bin/

COPY composer.sh /composer.sh
RUN chmod +x /composer.sh

ENTRYPOINT ["sh","/composer.sh"]
