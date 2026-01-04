FROM alpine:3.22

RUN apk add --no-cache tzdata

COPY frps.toml /etc/frp/frps.toml
COPY frps /usr/bin/frps
RUN mkdir -p /var/log/frps

VOLUME /etc/frp/logs

EXPOSE 80
EXPOSE 443
EXPOSE 2000-3000
EXPOSE 2000-3000/udp

# bind_port
EXPOSE 7000
# admin_port
EXPOSE 7400

ENTRYPOINT ["/usr/bin/frps", "-c", "/etc/frp/frps.toml"]
