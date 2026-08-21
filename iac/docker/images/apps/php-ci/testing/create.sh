#!/bin/bash -e

mysql -uroot -pCHANGE_ME  -e  "CREATE DATABASE IF NOT EXISTS shop_app_testing DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;"
mysql -uroot -pCHANGE_ME  -e  "GRANT ALL PRIVILEGES ON shop_app_testing.* TO 'shop_app'@'%'; ALTER USER 'shop_app'@'%';"
