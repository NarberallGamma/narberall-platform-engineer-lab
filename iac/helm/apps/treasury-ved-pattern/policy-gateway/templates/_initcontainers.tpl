{{/*
Init containers for policy-gateway (rendered into base-chart via initContainersTemplate).
*/}}
{{- define "policy-gateway.initContainers" -}}
{{- $app := .Values -}}
{{- $keysImport := $app.keysImport | default dict -}}
{{- $bootstrap := $app.bootstrap | default dict -}}
{{- $keysImportEnabled := $keysImport.enabled | default false -}}
{{- $importImage := $keysImport.image | default dict -}}
{{- $bootstrapImage := $bootstrap.image | default dict -}}
{{- $initImage := "" -}}
{{- $initPullPolicy := "IfNotPresent" -}}
{{- if $keysImportEnabled -}}
{{- $initImage = printf "%s:%s" ($importImage.repository | default "example.registry/estate/hsm-bootstrap") ($importImage.tag | default "0.1.0") -}}
{{- $initPullPolicy = $importImage.pullPolicy | default "IfNotPresent" -}}
{{- else -}}
{{- $initImage = printf "%s:%s" ($bootstrapImage.repository | default "example.registry/csp/cryptopro") ($bootstrapImage.tag | default "latest") -}}
{{- $initPullPolicy = $bootstrapImage.pullPolicy | default "IfNotPresent" -}}
{{- end -}}
- name: prepare-data-dirs
  image: example.registry/platform/eclipse-temurin:11-jre
  imagePullPolicy: IfNotPresent
  securityContext:
    runAsUser: 0
  command:
    - /bin/bash
    - -c
    - |
      set -e
      mkdir -p /data/data /data/cprocsp/users/cprouser /data/cprocsp/keys/cprouser /data/cprocsp/dsrf
      chown -R 10001:10001 /data
  volumeMounts:
    - name: policy-gateway-data
      mountPath: /data
- name: bootstrap
  image: {{ $initImage | quote }}
  imagePullPolicy: {{ $initPullPolicy }}
  securityContext:
    runAsUser: 0
  command:
    - sh
    - /scripts/bootstrap-cryptopro-keys.sh
  env:
    - name: treasury.policy-gateway.dgtry.mode
      value: {{ $bootstrap.dgtryMode | default "PREGEN" | quote }}
    - name: KEYS_IMPORT_ENABLED
      value: {{ $keysImportEnabled | quote }}
    - name: KEYS_IMPORT_FORCE
      value: {{ $keysImport.force | default false | quote }}
    - name: KEYS_ARCHIVE
      value: {{ $keysImport.archivePath | default "/archives/keys.tar.gz" | quote }}
  volumeMounts:
    - name: bootstrap-script
      mountPath: /scripts
      readOnly: true
    - name: policy-gateway-data
      mountPath: /var/opt/cprocsp/keys/cprouser
      subPath: cprocsp/keys/cprouser
- name: create-truststore
  image: example.registry/platform/eclipse-temurin:11-jre
  command:
    - /bin/bash
    - -c
    - |
      set -e
      JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
      cp "$JAVA_HOME/lib/security/cacerts" /tmp/kafka-truststore/kafka-truststore.jks
      keytool -storepasswd -keystore /tmp/kafka-truststore/kafka-truststore.jks -storepass changeit -new changeit
      keytool -import -noprompt -trustcacerts \
        -file /tmp/kafka-ca.crt \
        -alias kafka-ca \
        -keystore /tmp/kafka-truststore/kafka-truststore.jks \
        -storepass changeit \
        -storetype JKS
      echo "Kafka CA certificate imported successfully into system truststore"
  volumeMounts:
    - name: kafka-ca-cert
      mountPath: /tmp/kafka-ca.crt
      subPath: ca.crt
      readOnly: true
    - name: kafka-truststore
      mountPath: /tmp/kafka-truststore
{{- end -}}
