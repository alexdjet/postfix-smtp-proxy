FROM alpine:3.9

# Установка зависимостей
RUN apk add --no-cache \
    postfix \
    ca-certificates \
    bash \
    tzdata \
    busybox-extras 

# Копируем конфиги
COPY config/main.cf /etc/postfix/main.cf
#COPY config/master.cf /etc/postfix/master.cf

# Копируем секреты (лучше не делать так для чувствительных данных — см. ниже)
COPY config/sasl_passwd /etc/postfix/sasl_passwd
COPY config/sender_relay /etc/postfix/sender_relay
COPY config/generic /etc/postfix/generic

# Копируем entrypoint и скрипты
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ./scripts/auto_freeze.sh /usr/local/bin/auto_freeze.sh

# Делаем скрипты исполняемыми
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/auto_freeze.sh

# Создаём структуру папок, которую ожидает Postfix
#RUN mkdir -p /var/log /var/spool/postfix /var/lib/postfix /etc/postfix

# Экспортируем часовой пояс
ENV TZ=UTC

# Точка входа
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["postfix", "start-fg"]
