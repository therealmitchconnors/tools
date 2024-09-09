FROM fortio/fortio:latest as fsource

# Minimal image with just the binary and certs
FROM alpine:latest as release
# Install Bash
RUN apk add --no-cache bash
RUN apk add --no-cache curl
RUN apk add --no-cache kubectl
RUN apk add --no-cache jq

# Set the default shell to Bash
SHELL ["/bin/bash", "-c"]
COPY --from=fsource /usr/bin/fortio /usr/bin/fortio
EXPOSE 8078
EXPOSE 8079
EXPOSE 8080
EXPOSE 8081
# configmap (dynamic flags)
VOLUME /etc/fortio
# data files etc
VOLUME /var/lib/fortio
WORKDIR /var/lib/fortio
ENTRYPOINT ["/usr/bin/fortio"]
# start the server mode (grpc ping on 8079, http echo and UI on 8080, redirector on 8081) by default
CMD ["server", "-config-dir", "/etc/fortio"]