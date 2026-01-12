FROM nginx:stable-alpine

ARG TZ=UTC
ARG LOCALE=en_US.UTF-8

LABEL maintainer="Maikel Carballo"

RUN apk add -U --no-cache tzdata openssl && \
    cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone && \
    apk del tzdata

ENV TZ=${TZ}
ENV LANG=${LOCALE}
ENV LANGUAGE=${LOCALE}
ENV LC_ALL=${LOCALE}

WORKDIR /var/www/html

# Crear directorio para verificación de Let's Encrypt
RUN mkdir -p /var/www/certbot

# Copiar script de inicialización SSL (nombre diferente para no sobrescribir el original)
COPY ./ssl/docker-entrypoint.sh /ssl-entrypoint.sh
RUN chmod +x /ssl-entrypoint.sh

COPY ./nginx/default.conf.template /etc/nginx/templates/default.conf.template

ENTRYPOINT ["/ssl-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
