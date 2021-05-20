#!/bin/bash
if [ "$#" -ne 1 ]; then
  echo "$(basename "$0") userName"
  exit
fi
pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}
CERT_DIR=/opt/nifi/nifi-current/config-data/certs
USER=$1
USERCERTDIR="$CERT_DIR/$USER"
if [ ! -d $USERCERTDIR ];then
    mkdir $USERCERTDIR
    pushd $USERCERTDIR
    ${NIFI_TOOLKIT_HOME}/bin/tls-toolkit.sh client \
    -c "{{ template "ca.server" . }}" \
    -t {{ .Values.ca.token }} \
  {{- if .Values.properties.webProxyHost }}
    --subjectAlternativeNames {{ .Values.properties.webProxyHost }} \
  {{- else }}
    --subjectAlternativeNames {{ template "apache-nifi.fullname" . }}.{{ .Release.Namespace }}.svc \
  {{- end }}
    -p {{ .Values.ca.service.port }} \
    -D "CN=$USER, OU=NIFI" \
    -T PKCS12 &&
    export PASS=$(jq -r .keyStorePassword config.json) &&
    openssl pkcs12 -in "keystore.pkcs12" -out "key_${USER}.pem" -nocerts -nodes -password "env:PASS" &&
    openssl pkcs12 -in "keystore.pkcs12" -out "crt_${USER}.pem" -clcerts -nokeys -password "env:PASS" &&
    openssl pkcs12 -export -inkey "key_${USER}.pem" -in "crt_${USER}.pem" -out "cert_${USER}.p12" -passout pass:
    if  [ $? -eq 0 ]; then
   echo ""
   echo "certificates for user $USER are in $USERCERTDIR"
   echo "use oc cp $(hostname):$USERCERTDIR/cert_${USER}.p12 ./cert_${USER}.p12 to copy to local"
   else
     echo "CSR request for user $USER failed"
   fi
   popd
  else
    echo "userdir $USERCERTDIR exist, use certificate or delete"
  fi
