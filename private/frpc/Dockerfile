FROM alpine:3.22

RUN apk add --no-cache tzdata

COPY frpc.toml /etc/frp/frpc.toml
COPY frpc /usr/bin/frpc
RUN mkdir -p /var/log/frpc

EXPOSE 80
EXPOSE 443
EXPOSE 2000-3000
EXPOSE 2000-3000/udp

# bind_port
EXPOSE 7000
# admin_port
EXPOSE 7400

ENTRYPOINT ["/usr/bin/frpc", "-c", "/etc/frp/frpc.toml"]