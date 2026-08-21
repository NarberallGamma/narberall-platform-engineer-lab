#!/bin/bash

echo "start composer install"
composer install
echo "finish composer install"
composer dump-autoload --optimize
echo "finish dump autoload"
sleep 1000
