#!/bin/bash
source ./bin/restFunctions.sh
if ! nodeState;then
  echo "$err"
  exit 1
fi

