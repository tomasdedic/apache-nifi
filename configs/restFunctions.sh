#!/bin/bash
adminCrt=${NIFI_HOME}/config-data/certs/admin/crtAdmin.pem
adminKey=${NIFI_HOME}/config-data/certs/admin/keyAdmin.pem
hostNode="$(hostname -f)"
hostNodeUrl="https://${hostNode}:9443"

getPrimaryNode()
{
err=""
getPrimaryNode=$(curl --connect-timeout 5 -ks \
  --cert ${adminCrt} --cert-type pem \
  --key ${adminKey} --cert-type pem \
  $hostNodeUrl/nifi-api/controller/cluster | \
  jq -r ".cluster.nodes[] | select(.roles[]==\"Primary Node\") | .address" 2>/dev/null)
if [[ ! $? -eq 0 ]];then
  err="getPrimaryNode: Cannot get primaryNode"
  echo "$err" >&2
  return 1
fi
if [ ! -z ${getPrimaryNode} ];then
primaryNodeUrl="https://${getPrimaryNode}:9443"
echo $primaryNodeUrl
else
  return 1
fi
}

getNodesNumber()
{
err=""
if [[ $# -eq 0 ]] ; then
  askNodeUrl=$hostNodeUrl
else
  askNodeUrl=$1
fi
nodeCount=$(curl --connect-timeout 5 -ks \
  --cert ${adminCrt} --cert-type pem \
  --key ${adminKey} --cert-type pem \
  $askNodeUrl/nifi-api/controller/cluster | \
  jq -r ".cluster.nodes[] | select(.status==\"CONNECTED\") | .address" 2>/dev/null| wc -l)
if [ ! $? -eq 0 ];then
  err="getNodesNumber: Cannot parse server response"
  # echo "$err" >&2
  return 1
fi
echo $nodeCount
}

#getOtherNode
getOtherNode()
{
err=""
testNode=$(curl --connect-timeout 5 -ks \
  --cert ${adminCrt} --cert-type pem \
  --key ${adminKey} --cert-type pem \
  $hostNodeUrl/nifi-api/controller/cluster | \
  jq -r ".cluster.nodes[]" 2>/dev/null)
if [[ ! $? -eq 0 ]] || [[ -z $testNode ]];then
  err="getOtherNode: Cannot parse server response"
  # echo "$err" >&2
  return 1
fi
otherNode=$(echo "$testNode"|jq -r ".| select(.status==\"CONNECTED\" and .address !=\"$hostNode\") | .address" 2>/dev/null)
if [ ! $? -eq 0 ];then
  err="getOtherNode: Cannot get other node"
  # echo "$err" >&2
  return 1
fi
if [ -z $otherNode ];then
  #echo "Only one node remains"
  otherNode=$hostNode
else
  otherNode=$(echo $otherNode|head -n 1)
fi

if [ ! -z ${otherNode} ];then
otherNode="https://${otherNode}:9443"
#echo $otherNode
else
  return 1
fi
}

#nodeID
getLocalNodeID()
{
err=""
localNodeID=$(curl --connect-timeout 5 -ks \
  --cert ${adminCrt} --cert-type pem \
  --key ${adminKey} --cert-type pem \
  $hostNodeUrl/nifi-api/controller/cluster | \
  jq -r ".cluster.nodes[] | select(.address==\"$hostNode\") | .nodeId" 2>/dev/null)
if [ ! $? -eq 0 ] || [ -z $localNodeID ];then
  err="getLocalNodeID: Cannot get nodeID"
  # echo "$err" >&2
  exit 1
fi
echo $localNodeID
}

nodeDisconnect()
{
err=""
if [ $# -eq 2 ] ; then
  askNodeUrl=$1
  nodeID=$2
else
  askNodeUrl=$(getOtherNode)
  nodeID=$(getLocalNodeID)
fi
#disconnectNode
nodeDisconnectPayload()
{
cat <<EOF
  {
   "node": {"nodeId": "$nodeID", "status": "DISCONNECTING"}
  }
EOF
}

curl -ks --output nul -H 'Content-Type: application/json' -X PUT --data "$(nodeDisconnectPayload)" --connect-timeout 5 \
  --cert ${adminCrt} --cert-type pem \
  --key ${adminKey} --cert-type pem \
  $askNodeUrl/nifi-api/controller/cluster/nodes/${nodeID}
if [[ ! $? -eq 0 ]];then
  err="nodeDisconnect: Cannot disconnect node"
  # echo "$err" >&2
  return 1
fi
}

nodeOffload()
{
err=""
if [ $# -eq 2 ] ; then
  askNodeUrl=$1
  nodeID=$2
else
  askNodeUrl=$(getOtherNode)
  nodeID=$(getLocalNodeID)
fi
nodeOffloadPayload()
{
cat <<EOF
  {
   "node": {"nodeId": "$nodeID", "status": "OFFLOADING"}
  }
EOF

}
curl -ks --output nul -H 'Content-Type: application/json' -X PUT --data "$(nodeOffloadPayload)" --connect-timeout 5 \
  --cert ${adminCrt} --cert-type pem \
  --key ${adminKey} --cert-type pem \
  $askNodeUrl/nifi-api/controller/cluster/nodes/${nodeID}
if [ ! $? -eq 0 ];then
  err="nodeOffload: Cannot offload node"
  # echo "$err" >&2
  return 1
fi
}

nodeDelete()
{
err=""
if [ $# -eq 2 ] ; then
  askNodeUrl=$1
  nodeID=$2
else
  askNodeUrl=$(getOtherNode)
  nodeID=$nodeID
fi
curl --output nul -X DELETE --connect-timeout 5 -ks \
  --cert ${adminCrt} --cert-type pem \
  --key ${adminKey} --cert-type pem \
  $askNodeUrl/nifi-api/controller/cluster/nodes/${nodeID}
if [ ! $? -eq 0 ];then
  err="nodeDelete: Cannot delete node"
  # echo "$err" >&2
  return 1
fi
}

nodeState()
{
err=""
if [ $# -eq 2 ] ; then
  state=$1
  askNodeUrl=$2
elif [ $# -eq 1 ] ; then
  state=$1
  askNodeUrl=$hostNodeUrl
else
  state="CONNECTED"
  askNodeUrl=$hostNodeUrl
fi
nodeState=$(curl --connect-timeout 5 -ks \
  --cert ${adminCrt} --cert-type pem \
  --key ${adminKey} --cert-type pem \
  $askNodeUrl/nifi-api/controller/cluster | \
  jq -r ".cluster.nodes[] | select(.address==\"$hostNode\") | .status" 2>/dev/null)
if [ ! $? -eq 0 ] || [ -z $nodeState ];then
  err="nodeState: Cannot get node state"
  # echo "$err" >&2
  return 1
fi
#echo $nodeState
if [[ $nodeState = "$state" ]]; then
  err=""
  return 0
else
  err="nodeState: Not in $state state"
  return 1
fi
}
