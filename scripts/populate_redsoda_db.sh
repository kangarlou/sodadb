#!/bin/bash

id=0
SERVER="$1"
BRANDS=("RedClassic" "DietRed" "CherryRed" "Redelicious")
REVENUES=(1000000000 600000000 200000000 400000000)
FORMULAS=("???????????" "%%%%%%%%%%%" "#########" "@@@@@@@@@")

if [ -z "$SERVER" ]; then
	echo "usage: ./populate_coke_db.sh server"
	exit 1
fi

for i in ${!BRANDS[@]}; do
	JSON_INPUT=$(printf "'{\"id\":%d, \"brand\":\"%s\", \"revenue\":%d, \"soda_formula\":\"%s\"}'" $i ${BRANDS[$i]} ${REVENUES[$i]} ${FORMULAS[$i]})
    echo "curl --header \"Content-Type: application/json\" --header \"Accept: application/json\" -X POST -s ${SERVER}:8080 -d ${JSON_INPUT}"
	curl --header "Content-Type: application/json" --header "Accept: application/json" -X POST -s ${SERVER}:8080 -d '{"id":'$i', "brand":"'${BRANDS[$i]}'", "revenue":'${REVENUES[$i]}', "soda_formula":"'${FORMULAS[$i]}'"}'  & 
done

wait

