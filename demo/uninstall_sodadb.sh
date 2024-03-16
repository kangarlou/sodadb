#!/bin/bash

kubectl delete deploy sodadb-redsoda -n redsoda
kubectl delete deploy sodadb-bluesoda -n bluesoda
sleep 2
kubectl delete pn redsoda-network bluesoda-network
sleep 5
kubectl delete ns redsoda bluesoda
