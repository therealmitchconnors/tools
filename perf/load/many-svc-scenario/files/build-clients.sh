#!/bin/bash

# retrieve all fortio instances, outputting clients.json for fortio-commander to use

kubectl get pods -l app=fortio-client --all-namespaces -o json | jq '[.items[] | {name: .metadata.namespace, uri: (.status.podIP + ":8080")}]' > clients.json