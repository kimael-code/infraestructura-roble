FROM postgres:17

ARG LOCALE=en_US.UTF-8
ARG TZ=UTC

LABEL maintainer="Maikel Carballo"

# Extract locale components (e.g., en_US from en_US.UTF-8)
RUN LOCALE_BASE=$(echo ${LOCALE} | cut -d'.' -f1) && \
    localedef -i ${LOCALE_BASE} -c -f UTF-8 -A /usr/share/locale/locale.alias ${LOCALE}

ENV LANG=${LOCALE}
ENV TZ=${TZ}
