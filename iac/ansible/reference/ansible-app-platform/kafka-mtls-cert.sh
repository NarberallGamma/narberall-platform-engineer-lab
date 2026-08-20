#!/bin/bash

function cert {
  CERTNAME=$1
  IP_INT=$2
  IP_EXT=$3
  CA=$4
  step certificate create ${CERTNAME} ${CERTNAME}.crt ${CERTNAME}.pkcs1.key --ca ${CA}.crt --ca-key ${CA}.key --san ${CERTNAME} --san ${IP_INT} --san ${IP_EXT} --kty RSA --size 2048 --profile leaf --not-after 120000h --no-password --insecure
  openssl pkcs8 -topk8 -inform PEM -outform PEM -in ${CERTNAME}.pkcs1.key -out ${CERTNAME}.key -nocrypt
  cat ${CERTNAME}.crt ${CERTNAME}.key >${CERTNAME}.pem
}

function client_cert {
  CERTNAME=$1
  CA=$2

  [ -f "${CERTNAME}.keystore.jks" ] && { echo "Ошибка: файл ${CERTNAME}.keystore.jks существует"; exit 1; }
  [ -f "${CERTNAME}.truststore.jks" ] && { echo "Ошибка: файл ${CERTNAME}.truststore.jks существует"; exit 1; }

  keytool -genkey -keystore ${CERTNAME}.keystore.jks -alias localhost -validity 3650 -keyalg RSA -keysize 2048 -storepass $pass -keypass $pass -dname "CN=${CERTNAME}"
  keytool -keystore ${CERTNAME}.keystore.jks -alias localhost -certreq -file ${CERTNAME}.crt -storepass $pass -keypass $pass
  openssl x509 -req -CA ${CA}.crt -CAkey ${CA}.key -in ${CERTNAME}.crt -out ${CERTNAME}-signed.crt -days 3650 -CAcreateserial
  keytool -keystore ${CERTNAME}.keystore.jks -alias CARoot -import -file ${CA}.crt -storepass $pass -keypass $pass  -noprompt
  keytool -keystore ${CERTNAME}.keystore.jks -alias localhost -import -file ${CERTNAME}-signed.crt -storepass $pass -keypass $pass  -noprompt
  keytool -keystore ${CERTNAME}.truststore.jks -alias CARoot -import -file ${CA}.crt -storepass $pass -keypass $pass  -noprompt

  rm ${CERTNAME}-signed.crt ${CERTNAME}.crt
}

#rm *crt *key *jks *csr *pem *srl
pass=$1


#PREPROD
#openssl req -new -x509 -keyout preprod-ca.key -out preprod-ca.crt -days 10000 -subj "/CN=PLATFORM PREPROD ROOT CA" -nodes -newkey rsa:2048
#cert kafka-public-preprod-0001 10.10.9.45 203.0.113.21 preprod-ca
#cert kafka-public-preprod-0002 10.10.9.154 203.0.113.22 preprod-ca
#cert kafka-public-preprod-0003 10.10.9.161 203.0.113.23 preprod-ca

#PROD
#openssl req -new -x509 -keyout prod-ca.key -out prod-ca.crt -days 10000 -subj "/CN=PLATFORM PROD ROOT CA" -nodes -newkey rsa:2048
#cert kafka-public-prod-0001 10.10.9.207 203.0.113.31 prod-ca
#cert kafka-public-prod-0002 10.10.9.122 203.0.113.32 prod-ca
#cert kafka-public-prod-0003 10.10.9.38 203.0.113.33 prod-ca

#IFT
#openssl req -new -x509 -keyout ift-ca.key -out ift-ca.crt -days 10000 -subj "/CN=PLATFORM IFT ROOT CA" -nodes -newkey rsa:2048
#cert kafka-public-ift-0001 10.10.9.248 203.0.113.11 ift-ca
#cert kafka-public-ift-0002 10.10.9.76 203.0.113.12 ift-ca
#cert kafka-public-ift-0003 10.10.9.33 203.0.113.13 ift-ca

#client_cert client-ift-app ift-ca
#client_cert client-preprod-app preprod-ca
#client_cert client-prod-app prod-ca
#client_cert ift-admin ift-ca
#client_cert monolith-ift ift-ca
#client_cert monolith-preprod preprod-ca
#client_cert monolith-prod prod-ca
