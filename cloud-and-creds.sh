#!/bin/sh -e

MAAS_INTERNAL=10.0.0.2
CLOUD_YAML=~/cloud.yaml
CREDS_YAML=~/credentials.yaml
CLOUD_NAME=maas-one
CREDS_NAME=maas-one
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

# Remove the existing cloud if this is being re-run.
if juju clouds 2>/dev/null | grep $CLOUD_NAME; then
           juju remove-cloud $CLOUD_NAME
fi

juju add-cloud --client $CLOUD_NAME $CLOUD_YAML
juju add-credential --client -f $CREDS_YAML $CLOUD_NAME
