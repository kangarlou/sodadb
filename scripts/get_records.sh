#!/bin/bash

SERVER="$1"
if [ -z "SERVER" ]; then
	echo "usage: ./get_records server"
	exit 1
fi

echo "curl -X GET $SERVER:8080/"
curl -X GET "$SERVER:8080/" 
