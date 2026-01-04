FROM nginx:alpine

RUN apk add --no-cache certbot openssl bash gettext

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME /etc/letsencrypt
VOLUME /var/www/certbot

ENTRYPOINT ["/entrypoint.sh"]
