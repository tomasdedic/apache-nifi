#!/bin/bash

FQDN=$(hostname -f)
nodeUrl="https://${FQDN}:9443"

keystore=${NIFI_HOME}/config-data/certs/admin/keystoreAdmin.jks
keystorePasswd=$(jq -r .keyStorePassword ${NIFI_HOME}/config-data/certs/admin/config.json)
keyPasswd=$(jq -r .keyPassword ${NIFI_HOME}/config-data/certs/admin/config.json)
truststore=${NIFI_HOME}/config-data/certs/truststore.jks
truststorePasswd=$(jq -r .trustStorePassword ${NIFI_HOME}/config-data/certs/config.json)
secureArgs=" --truststore ${truststore} --truststoreType JKS --truststorePasswd \"${truststorePasswd}\" --keystore ${keystore} --keystoreType JKS --keystorePasswd \"${keystorePasswd}\" "

baseUrl=$(${NIFI_TOOLKIT_HOME}/bin/cli.sh nifi get-nodes -ot json -u ${nodeUrl} ${secureArgs} | \
  jq -r ".cluster.nodes[] | select (.roles[]==\"Primary Node\")| .address")
if [[ ! $? = 0 ]];then
  echo "Cannot parse server response"
  exit 1
fi
primaryUrl="https://${baseUrl}:9443"
echo primarynode ${primaryUrl}

nodeState() {
#node_state=$(curl --connect-timeout 5 -ks -H "Host: nifi" \
#  --cert ${NIFI_HOME}/config-data/certs/admin/crtAdmin.pem --cert-type pem \
#  --key ${NIFI_HOME}/config-data/certs/admin/keyAdmin.pem --key-type pem \
#  https://${primaryUrl}:9443/nifi-api/controller/cluster | \
#  jq -r ".cluster.nodes[] | select((.address==\"$(hostname -f)\") or .address==\"localhost\") | .status") && echo $stat
#
${NIFI_TOOLKIT_HOME}/bin/cli.sh nifi get-nodes -ot json -u ${primaryUrl} ${secureArgs} > nodes.json
node_state=$(jq -r --arg FQDN "$FQDN" '.cluster.nodes[] | select(.address==$FQDN) | .status' nodes.json)
echo $FQDN $node_state
if [[ ! $? = 0 ]];then
  echo "Cannot parse server response"
  exit 1
fi
if [[ ! $node_state = "CONNECTED" ]]; then
  echo "Node $FQDN not in CONNECTED state. "
  exit 1
fi
}
nodeState
