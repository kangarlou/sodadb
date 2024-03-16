#!/bin/bash

SERVER="$1"
ID="$2"
if [ -z "SERVER" ] || [ -z "$ID" ] ; then
	echo "usage: ./delete_record server record_id"
	exit 1
fi

echo "curl -X DELETE $SERVER:8080/$ID"
curl -X DELETE "$SERVER:8080/$ID" 
