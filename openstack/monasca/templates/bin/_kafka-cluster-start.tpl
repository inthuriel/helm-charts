{{- define "kafka_cluster_start_tpl" -}}
#!/bin/bash

# set some env variables from the openstack env properly based on env
. /container.init/common-start

function process_config {
  # use defaults if no specific node configuration available
  cp /monasca-etc-common/kafka-cluster-consumer.properties /opt/kafka/current/config/consumer.properties
  cp /monasca-etc-common/kafka-cluster-server.properties /opt/kafka/current/config/server.properties
  cp /monasca-etc-common/kafka-cluster-zookeeper.properties /opt/kafka/current/config/zookeeper.properties
  cp /monasca-etc-common/kafka-cluster-log4j.properties /opt/kafka/current/config/log4j.properties

  export HOSTNUM=$(hostname|sed 's/[^0-9]*//g') 
  export MONASCA_KAFKA_ENDPOINT_ID=$(($HOSTNUM + 1))


  MONASCA_KAFKA_SERVER_VAR="$(hostname).kafka"
  # substitute injected ENV
  sed -i "s,MONASCA_KAFKA_ENDPOINT_ID,$MONASCA_KAFKA_ENDPOINT_ID,g" /opt/kafka/current/config/server.properties
  sed -i "s,MONASCA_KAFKA_ENDPOINT_HOST_INTERNAL,${MONASCA_KAFKA_SERVER_VAR},g" /opt/kafka/current/config/server.properties
}

function start_application {
  # make sure Zookeeper is around
  echo -n "Check that Zookeeper is up ..."
  if ! nc -zv zk {{.Values.monasca_zookeeper_port_internal}}; then
    echo "Zookeeper is not yet up"
    exit 1
  fi

  echo " ok"

  # uncomment for debugging
  #sleep 30000

  # make sure healthcheck topic is there
  ( sleep 60; /opt/kafka/current/bin/kafka-topics.sh --create --topic "healthcheck" --if-not-exists --partitions 1 --replication-factor 1 --zookeeper zk:{{.Values.monasca_zookeeper_port_internal}}) &

  echo "Start Kafka with lock /var/opt/kafka/container.lock"
  exec chpst -v -L /var/opt/kafka/container.lock /opt/kafka/current/bin/kafka-server-start.sh /opt/kafka/current/config/server.properties
}

function diagnose_application {
  echo "Disk status"
  df

  echo ""
  echo "Kafka could not be started: dump config"
  echo "server.properties --------------"
  cat /opt/kafka/current/config/server.properties
  echo ""
  echo "zookeeper.properties -----------"
  cat /opt/kafka/current/config/zookeeper.properties

  echo ""
  echo "Check whether Zookeeper can be reached (nc)"
  for i in $(seq 1 10); do
    sleep 1
    echo -n "."
    nc -zv zk {{.Values.monasca_zookeeper_port_internal}}
  done
}

process_config

start_application

diagnose_application
{{ end }}