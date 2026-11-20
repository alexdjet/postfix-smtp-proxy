FROM debian:buster

RUN sed -i 's|deb.debian.org|archive.debian.org|g' /etc/apt/sources.list \
    && sed -i '/security.debian.org/d' /etc/apt/sources.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    postfix \
    ca-certificates \
    libsasl2-modules \
    bash \
    curl \
    cron \
    && rm -rf /var/lib/apt/lists/*

COPY config/main.cf /etc/postfix/main.cf

COPY config/sasl_passwd /etc/postfix/sasl_passwd
COPY config/sender_canonical /etc/postfix/sender_canonical
COPY config/sender_relay /etc/postfix/sender_relay
COPY config/generic /etc/postfix/generic

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ./scripts/auto_freeze.sh /usr/local/bin/auto_freeze.sh

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/auto_freeze.sh

RUN mkdir -p /var/log /var/lib/postfix

ENV TZ=UTC

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["postfix", "start-fg"]
