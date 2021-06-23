#!/bin/sh -e

#    Licensed to the Apache Software Foundation (ASF) under one or more
#    contributor license agreements.  See the NOTICE file distributed with
#    this work for additional information regarding copyright ownership.
#    The ASF licenses this file to You under the Apache License, Version 2.0
#    (the "License"); you may not use this file except in compliance with
#    the License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

scripts_dir='/opt/nifi-registry/scripts'

[ -f "${scripts_dir}/common.sh" ] && . "${scripts_dir}/common.sh"

# Perform idempotent changes of configuration to support secure environments
echo 'Configuring environment with SSL settings'

: ${KEYSTORE_PATH:?"Must specify an absolute path to the keystore being used."}
if [ ! -f "${KEYSTORE_PATH}" ]; then
    echo "Keystore file specified (${KEYSTORE_PATH}) does not exist."
    exit 1
fi
: ${KEYSTORE_TYPE:?"Must specify the type of keystore (JKS, PKCS12, PEM) of the keystore being used."}
: ${KEYSTORE_PASSWORD:?"Must specify the password of the keystore being used."}

: ${TRUSTSTORE_PATH:?"Must specify an absolute path to the truststore being used."}
if [ ! -f "${TRUSTSTORE_PATH}" ]; then
    echo "Keystore file specified (${TRUSTSTORE_PATH}) does not exist."
    exit 1
fi
: ${TRUSTSTORE_TYPE:?"Must specify the type of truststore (JKS, PKCS12, PEM) of the truststore being used."}
: ${TRUSTSTORE_PASSWORD:?"Must specify the password of the truststore being used."}

prop_replace 'nifi.registry.security.keystore'           "${KEYSTORE_PATH}"
prop_replace 'nifi.registry.security.keystoreType'       "${KEYSTORE_TYPE}"
prop_replace 'nifi.registry.security.keystorePasswd'     "${KEYSTORE_PASSWORD}"
prop_replace 'nifi.registry.security.keyPasswd'          "${KEY_PASSWORD:-$KEYSTORE_PASSWORD}"
prop_replace 'nifi.registry.security.truststore'         "${TRUSTSTORE_PATH}"
prop_replace 'nifi.registry.security.truststoreType'     "${TRUSTSTORE_TYPE}"
prop_replace 'nifi.registry.security.truststorePasswd'   "${TRUSTSTORE_PASSWORD}"

# Disable HTTP and enable HTTPS
prop_replace 'nifi.registry.web.http.port'   ''
prop_replace 'nifi.registry.web.http.host'   ''
prop_replace 'nifi.registry.web.https.port'  "${NIFI_REGISTRY_WEB_HTTPS_PORT:-18443}"
prop_replace 'nifi.registry.web.https.host'  "${NIFI_REGISTRY_WEB_HTTPS_HOST:-$HOSTNAME}"

# Establish initial user and an associated admin identity
sed -i -e 's|<property name="Initial User Identity admin">.*</property>|<property name="Initial User Identity 1">'"${INITIAL_ADMIN_IDENTITY}"'</property>|'  ${NIFI_REGISTRY_HOME}/conf/authorizers.xml
sed -i -e 's|<property name="Initial Admin Identity">.*</property>|<property name="Initial Admin Identity">'"${INITIAL_ADMIN_IDENTITY}"'</property>|'  ${NIFI_REGISTRY_HOME}/conf/authorizers.xml
