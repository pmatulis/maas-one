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

# Add the cloud. If it already exists, update it.
if ! juju clouds 2>/dev/null | grep $CLOUD_NAME; then
   juju add-cloud --client $CLOUD_NAME $CLOUD_YAML
else
   juju update-cloud --client $CLOUD_NAME -f $CLOUD_YAML
fi

# Add the credential. If it already exists, update it.
if ! juju credentials 2>/dev/null | grep $CREDS_NAME; then
   juju add-credential --client -f $CREDS_YAML $CLOUD_NAME
else
   juju update-credential --client $CLOUD_NAME $CREDS_NAME -f $CREDS_YAML
fi

