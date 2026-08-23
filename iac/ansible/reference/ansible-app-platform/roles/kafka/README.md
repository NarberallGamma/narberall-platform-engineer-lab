1. After a node is lost or brought back, format storage on that node after the playbook run:

preprod: /opt/kafka/bin/kafka-storage.sh format -t AAAAAAAAAAAAAAAAAAAAAA -c /etc/kafka/server.properties
prod: /opt/kafka/bin/kafka-storage.sh format -t BBBBBBBBBBBBBBBBBBBBBB -c /etc/kafka/server.properties
ift /opt/kafka/bin/kafka-storage.sh format -t CCCCCCCCCCCCCCCCCCCCCC -c /etc/kafka/server.properties
To run the format command, the compose entrypoint may be replaced with sleep and the container restarted. After the command finishes, restore the intended start command (without sleep).

2. After a cluster is initialized from scratch, or when more than one node was lost, add the admin user used by kafka-configurator. Do this after storage is initialized on all new nodes (step 1) and the container is restarted without sleep:

/opt/kafka/bin/kafka-configs.sh --bootstrap-server 10.10.9.45:9094 --command-config /etc/kafka/client.properties --alter --add-config 'SCRAM-SHA-512=[iterations=4096,password=mypass]'  --entity-type users --entity-name admin

Replace 10.10.9.45:9094 with another cluster host if needed.
Replace mypass with the Kafka admin password (from Vault or the kafka-configurator job secret).
All commands run inside the running container.
