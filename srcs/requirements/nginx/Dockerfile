FROM alpine:3.23

RUN apk update && apk add --no-cache nginx openssl

COPY conf/nginx.conf /etc/nginx/http.d/default.conf
COPY tools/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 443

ENTRYPOINT [ "/entrypoint.sh" ]