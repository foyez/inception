FROM alpine:3.23

RUN apk update && apk add --no-cache mariadb mariadb-client

RUN rm -f /etc/my.cnf.d/mariadb-server.cnf

COPY conf/my.cnf /etc/my.cnf.d/inception.cnf
COPY tools/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 3306

ENTRYPOINT [ "/entrypoint.sh" ]