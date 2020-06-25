#!/bin/sh

set -eu

URL=http://localhost:5240/MAAS

if [ "$#" -ne "0" ]; then

        PROFILE=$1
        API_KEY_FILE=~/${PROFILE}-api-key

else

        PROFILE=admin
        API_KEY_FILE=~/admin-api-key

fi

# Log in to be able to issue further commands
maas login $PROFILE $URL - < $API_KEY_FILE
