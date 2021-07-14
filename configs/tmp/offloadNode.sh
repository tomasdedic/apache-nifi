#!/bin/sh

FQDN=$(hostname -f)
nodeUrl="https://${FQDN}:9443"

keystore=${NIFI_HOME}/config-data/certs/admin/keystoreAdmin.jks
keystorePasswd=$(jq -r .keyStorePassword ${NIFI_HOME}/config-data/certs/admin/config.json)
keyPasswd=$(jq -r .keyPassword ${NIFI_HOME}/config-data/certs/admin/config.json)
truststore=${NIFI_HOME}/config-data/certs/truststore.jks
truststorePasswd=$(jq -r .trustStorePassword ${NIFI_HOME}/config-data/certs/config.json)
secureArgs=" --truststore ${truststore} --truststoreType JKS --truststorePasswd ${truststorePasswd} --keystore ${keystore} --keystoreType JKS --keystorePasswd ${keystorePasswd} "

# get primaryNode in cluster
baseUrl=$(${NIFI_TOOLKIT_HOME}/bin/cli.sh nifi get-nodes -ot json -u ${nodeUrl} ${secureArgs} | \
  jq -r ".cluster.nodes[] | select (.roles[]==\"Primary Node\")| .address")
primaryUrl="https://${baseUrl}:9443"
echo primarynode ${primaryUrl}

offloadNode() {
    echo "Gracefully disconnecting node '$FQDN' from cluster"
    ${NIFI_TOOLKIT_HOME}/bin/cli.sh nifi get-nodes -ot json -u ${primaryUrl} ${secureArgs} > nodes.json
    nnid=$(jq --arg FQDN "$FQDN" '.cluster.nodes[] | select(.address==$FQDN) | .nodeId' nodes.json)
    echo "Disconnecting node ${nnid}"
    ${NIFI_TOOLKIT_HOME}/bin/cli.sh nifi disconnect-node -nnid $nnid -u ${primaryUrl} ${secureArgs}
    echo ""
    echo "Wait until node has state 'DISCONNECTED'"
    while [[ "${node_state}" != "DISCONNECTED" ]]; do
        sleep 1
        ${NIFI_TOOLKIT_HOME}/bin/cli.sh nifi get-nodes -ot json -u ${primaryUrl} ${secureArgs} > nodes.json
        node_state=$(jq -r --arg FQDN "$FQDN" '.cluster.nodes[] | select(.address==$FQDN) | .status' nodes.json)
        echo "state is '${node_state}'"
    done
    echo ""
    echo "Node '${nnid}' was disconnected"
    echo "Offloading node"
    ${NIFI_TOOLKIT_HOME}/bin/cli.sh nifi offload-node -nnid $nnid -u ${primaryUrl} ${secureArgs}
    echo ""
    echo "Wait until node has state 'OFFLOADED'"
    while [[ "${node_state}" != "OFFLOADED" ]]; do
        sleep 1
        ${NIFI_TOOLKIT_HOME}/bin/cli.sh nifi get-nodes -ot json -u ${primaryUrl} ${secureArgs} > nodes.json
        node_state=$(jq -r --arg FQDN "$FQDN" '.cluster.nodes[] | select(.address==$FQDN) | .status' nodes.json)
        echo "state is '${node_state}'"
    done
}

deleteNode() {
    echo "Deleting node '$FQDN' from cluster"
    ${NIFI_TOOLKIT_HOME}/bin/cli.sh nifi get-nodes -ot json -u ${primaryUrl} ${secureArgs} > nodes.json
    nnid=$(jq --arg FQDN "$FQDN" '.cluster.nodes[] | select(.address==$FQDN) | .nodeId' nodes.json)
    echo "Deleting node ${nnid}"
    ${NIFI_TOOLKIT_HOME}/bin/cli.sh nifi delete-node -nnid ${nnid} -u ${primaryUrl} ${secureArgs}
    echo "Node deleted"
}
