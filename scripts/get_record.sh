#!/bin/bash

SERVER="$1"
ID="$2"
if [ -z "SERVER" ] || [ -z "$ID" ] ; then
	echo "usage: ./get_record server record_id"
	exit 1
fi

echo "curl -X GET $SERVER:8080/$ID"
curl -X GET "$SERVER:8080/$ID" 
