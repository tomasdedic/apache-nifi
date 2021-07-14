#!/bin/bash
source ./bin/restFunctions.sh
if ! getOtherNode;then
  echo "$err"
  exit 1
fi
askNodeUrl=$otherNode
localNodeID=$(getLocalNodeID)
nodesNumber=$(getNodesNumber $askNodeUrl)
if [[ $nodesNumber -gt 1 ]];then
  if nodeDisconnect $askNodeUrl $localNodeID;then
  state="DISCONNECTED"
    while  ! nodeState "$state" "$askNodeUrl" ; do
        sleep 1
        echo "node state is not ${state}"
    done
  else
    echo $err
  fi
  if nodeOffload $askNodeUrl $localNodeID;then
  state="OFFLOADED"
    while  ! nodeState "$state" "$askNodeUrl" ; do
        sleep 1
        echo "node state is not ${state}"
    done
  else
    echo $err
  fi
  if ! nodeDelete $askNodeUrl $localNodeID;then
    echo $err
  fi
else
  if ! nodeDisconnect $askNodeUrl $localNodeID;then
    echo $err
  fi
fi
