1. При потере/поднятии какой-либо ноды требуется после раскатки плейбука на ней инициализировать хранилище командой:
preprod: /opt/kafka/bin/kafka-storage.sh format -t AAAAAAAAAAAAAAAAAAAAAA -c /etc/kafka/server.properties
prod: /opt/kafka/bin/kafka-storage.sh format -t BBBBBBBBBBBBBBBBBBBBBB -c /etc/kafka/server.properties
ift /opt/kafka/bin/kafka-storage.sh format -t CCCCCCCCCCCCCCCCCCCCCC -c /etc/kafka/server.properties
Для этого может понадобиться в композе заменить entrypoint на sleep и перезапустить контейнер. После выполнения команды надо вернуть целевую команду запуска (без sleep)

2. После инициализации кластера с нуля или когда были потеряны более чем 1 нода, требуется добавить пользователя admin, который используется нашим kafka-configurator. Это нужно сделать после инициализации хранилища на всех новых нодах(пп1) и перезапуска контейнера без опции sleep:

/opt/kafka/bin/kafka-configs.sh --bootstrap-server 10.10.9.45:9094 --command-config /etc/kafka/client.properties --alter --add-config 'SCRAM-SHA-512=[iterations=4096,password=mypass]'  --entity-type users --entity-name admin

10.10.9.45:9094 заменить при необходимости на любой другой хост кластера
mypass заменить на пароль админа кафки(взять в вольте или секрете джобы kafka-configurator)
Все команды выполняются внутри запущенного контейнера
