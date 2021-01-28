#!/bin/sh

PROFILE=admin

~/maas-login.sh >/dev/null 2>&1

RACK_ID=$(maas $PROFILE rack-controllers read | jq -r .[].system_id)

while [ $(maas $PROFILE rack-controller list-boot-images $RACK_ID | jq -r '.status') != 'synced' ]; do
   sleep 2
   echo -n "."
done

echo "The boot images are available. MAAS is ready for node enlistment."
