#!/bin/bash
source ./bin/restFunctions.sh
if ! getOtherNode ; then
  echo $err
  exit 1
else
  askNode=$otherNode
fi
if  ! nodeState "CONNECTED" $askNode; then
  echo $err
  exit 1
fi
