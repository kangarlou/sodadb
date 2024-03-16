#!/bin/bash

REGISTRY=${REGISTRY:-$1}
IMAGE_TAG=v1.0.0
NODE1=$(kubectl get nodes -o json | jq -r '.items[0].metadata.name')

kubectl create ns redsoda &> /dev/null
kubectl create ns bluesoda &> /dev/null

if [ -z "$REGISTRY" ]; then
	echo "usage: ./install_sodadb.sh registry"
	exit 1
fi

cat <<EOF | kubectl apply -f -
apiVersion: multitenancy.acn.azure.com/v1alpha1
kind: PodNetwork
metadata:
  annotations:
  name: redsoda-network
spec:
  subnetGUID: 2dc43e25-b11c-434b-9ead-b8b70e294fb8
  subnetResourceID: /subscriptions/e3e8712f-8cda-4bce-8945-724815ce1fe3/resourceGroups/kubecon-demo/providers/Microsoft.Network/virtualNetworks/redsoda/subnets/sodadb-redsoda-server
  vnetGUID: c10b7416-20e4-4bc5-9a72-08eb0338572c
---
apiVersion: multitenancy.acn.azure.com/v1alpha1
kind: PodNetwork
metadata:
  annotations:
  name: bluesoda-network
spec:
  subnetGUID: a8063ba5-8c98-4d64-a085-c68e76514fa6
  subnetResourceID: /subscriptions/e3e8712f-8cda-4bce-8945-724815ce1fe3/resourceGroups/kubecon-demo/providers/Microsoft.Network/virtualNetworks/bluesoda/subnets/sodadb-bluesoda-server
  vnetGUID: 133ce8f4-bc9a-4616-aa98-47f53758f152
EOF

sleep 2

REDSODA_PN_UID=$(kubectl get podnetwork redsoda-network -o=jsonpath={.metadata.uid})
BLUESODA_PN_UID=$(kubectl get podnetwork bluesoda-network -o=jsonpath={.metadata.uid})

cat <<EOF | kubectl apply -f -
apiVersion: multitenancy.acn.azure.com/v1alpha1
kind: PodNetworkInstance
metadata:
  labels:
    managed: "true"
    owner: redsoda-network
  name: redsoda-sodadb-pni
  namespace: redsoda
  ownerReferences:
  - apiVersion: multitenancy.acn.azure.com/v1alpha1
    kind: PodNetwork
    name: redsoda-network
    uid: ${REDSODA_PN_UID}
spec:
  podIPReservationSize: 1
  podnetwork: redsoda-network
---
apiVersion: multitenancy.acn.azure.com/v1alpha1
kind: PodNetworkInstance
metadata:
  labels:
    managed: "true"
    owner: bluesoda-network
  name: bluesoda-sodadb-pni
  namespace: bluesoda
  ownerReferences:
  - apiVersion: multitenancy.acn.azure.com/v1alpha1
    kind: PodNetwork
    name: bluesoda-network
    uid: ${BLUESODA_PN_UID}
spec:
  podIPReservationSize: 1
  podnetwork: bluesoda-network
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: redsoda
  name: sodadb-redsoda
  labels:
    app: sodadb
    kubernetes.azure.com/pod-network: redsoda-network
    kubernetes.azure.com/pod-network-instance: redsoda-sodadb-pni
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sodadb
  template:
    metadata:
      labels:
        app: sodadb
        sodadb-instance: redsoda
        kubernetes.azure.com/pod-network: redsoda-network
        kubernetes.azure.com/pod-network-instance: redsoda-sodadb-pni
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: "kubernetes.io/hostname"
                operator: In
                values:
                - ${NODE1}
      containers:
      - name: sodadb
        image: ${REGISTRY}/sodadb:${IMAGE_TAG}
        command: ["/root/sodadb"]
        args:
        - -company=Coca-Cola
        - -network_interface=eth1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
        imagePullPolicy: Always
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: bluesoda
  name: sodadb-bluesoda
  labels:
    app: sodadb
    kubernetes.azure.com/pod-network: bluesoda-network
    kubernetes.azure.com/pod-network-instance: bluesoda-sodadb-pni
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sodadb
  template:
    metadata:
      labels:
        app: sodadb
        sodadb-instance: bluesoda
        kubernetes.azure.com/pod-network: bluesoda-network
        kubernetes.azure.com/pod-network-instance: bluesoda-sodadb-pni
    spec:
      affinity:
         nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: "kubernetes.io/hostname"
                operator: NotIn
                values:
                - ${NODE1}
      containers:
      - name: sodadb
        image: ${REGISTRY}/sodadb:${IMAGE_TAG}
        command: ["/root/sodadb"]
        args:
        - -company=Pepsi
        - -network_interface=eth1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
        imagePullPolicy: Always
EOF
