# Author: Ardalan Kangarlou

IMAGE_TAG=v1.0.0

default: build

build: sodadb.go
	go mod tidy
	GOOS=linux GOARCH=amd64 go build -o ./bin/sodadb sodadb.go
	GOOS=darwin GOARCH=amd64 go build -o ./bin/sodadb-darwin-amd64 sodadb.go

image: clean build
	docker build --platform linux/amd64 -t sodadb:${IMAGE_TAG} .	
	docker tag sodadb:${IMAGE_TAG} ${REGISTRY}/sodadb:${IMAGE_TAG} 
	docker push ${REGISTRY}/sodadb:${IMAGE_TAG}

uninstall:
	-kubectl delete deploy -l app=sodadb

clean:
	-rm ./bin/*
	-docker rmi sodadb:${IMAGE_TAG} ${REGISTRY}/sodadb:${IMAGE_TAG}
