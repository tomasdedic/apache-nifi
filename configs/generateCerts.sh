#!/bin/bash
# generate node cert function
{{- $caserver := include "ca.server" . }}
{{- $nifiserver := include "apache-nifi.fullname" . }}
#!/bin/bash
generate_node_cert() {
 "${NIFI_TOOLKIT_HOME}"/bin/tls-toolkit.sh client \
  -t {{ .Values.ca.token }} \
{{- if .Values.properties.webProxyHost }}
  --subjectAlternativeNames {{ .Values.properties.webProxyHost }}, $(hostname -f) \
{{- else }}
  --subjectAlternativeNames {{ $nifiserver }}.{{ .Release.Namespace }}.svc \
{{- end }}
  -D "CN=$(hostname -f), OU=NIFI" \
  -p {{ .Values.ca.service.port }}
}

# generate admin cert function
generate_admin_cert() {
"${NIFI_TOOLKIT_HOME}"/bin/tls-toolkit.sh client \
  -t {{ .Values.ca.token }} \
{{- if .Values.properties.webProxyHost }}
  --subjectAlternativeNames {{ .Values.properties.webProxyHost }},{{ $nifiserver }}.{{ .Release.Namespace }}.svc \
{{- else }}
  --subjectAlternativeNames {{ $nifiserver }}.{{ .Release.Namespace }}.svc \
{{- end }}
  -p {{ .Values.ca.service.port }} \
  -D "CN={{ .Values.ca.admin.cn }}, OU=NIFI" \
  -T PKCS12
  export PASS=$(jq -r .keyStorePassword config.json)
  openssl pkcs12 -in "keystore.pkcs12" -out "keyAdmin.pem" -nocerts -nodes -password "env:PASS"
  openssl pkcs12 -in "keystore.pkcs12" -out "crtAdmin.pem" -clcerts -nokeys -password "env:PASS"
  keytool -importkeystore -srckeystore keystore.pkcs12 -srcstoretype pkcs12 -srcstorepass $(jq -r .keyStorePassword config.json) -destkeystore keystoreAdmin.jks -deststoretype jks -deststorepass $(jq -r .keyStorePassword config.json)
  openssl pkcs12 -export -inkey "keyAdmin.pem" -in "crtAdmin.pem" -out "certAdmin.p12" -passout pass:
}
cd /data/config-data
if [ "$REGENERATE_CERTIFICATES" = true ];then
  rm -rf certs
fi
if [ ! -d certs ];then
  mkdir certs
  cd certs
  generate_node_cert
else
  cd certs
  if ([ ! -f config.json ] || [ ! -f keystore.jks ] || [ ! -f truststore.jks ]);then
  rm -f *
  generate_node_cert
  fi
fi

if [ ! -d admin ];then
  mkdir admin
  cd admin
  #generate admin client cert for browser
  generate_admin_cert
else
  cd admin
  if [ ! -f config.json ] || [ ! -f keystore.pkcs12 ];then
  rm -f *
  generate_admin_cert
  fi
fi
