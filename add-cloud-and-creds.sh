#!/bin/sh -e

MAAS_INTERNAL=10.0.0.2
CLOUD_YAML=~/cloud.yaml
CREDS_YAML=~/credentials.yaml
CLOUD_NAME=mymaas
CREDS_NAME=anyuser
API_KEY=$(cat ~/admin-api-key)

cat > $CLOUD_YAML << HERE
clouds:
  $CLOUD_NAME:
    type: maas
    auth-types: [oauth1]
    endpoint: http://$MAAS_INTERNAL:5240/MAAS
HERE

cat > $CREDS_YAML << HERE
credentials:
  $CLOUD_NAME:
    $CREDS_NAME:
      auth-type: oauth1
      maas-oauth: $API_KEY
HERE

juju add-cloud --client $CLOUD_NAME $CLOUD_YAML
juju add-credential --client -f $CREDS_YAML $CLOUD_NAME
