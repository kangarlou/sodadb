# syntax=docker/dockerfile:1

FROM --platform=linux/amd64 alpine:3.19.1
RUN apk add curl tcpdump traceroute bind-tools bash
COPY ./bin/sodadb ./scripts /root
CMD ["/root/sodadb", "-network_interface", "eth0"]
