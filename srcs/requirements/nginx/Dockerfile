FROM alpine:3.23

RUN apk update && \
    apk add --no-cache nginx openssl

RUN mkdir -p /etc/nginx/ssl

# Create a self-signed X.509 certificate to encrypt TLS connections so as to enable HTTPS
RUN openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/C=FI/ST=Uusimaa/L=Helsinki/O=Hive/CN=piyu.42.fr"

COPY conf/nginx.conf /etc/nginx/http.d/default.conf

# Documents the port number the application listens on. It is not published to the host
# unless running docker with --publish-all or -P option
EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
