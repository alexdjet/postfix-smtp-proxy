#!/usr/bin/env bash
set -euo pipefail

SPOOL_DIR="/var/spool/postfix"

if [ -f /etc/postfix/sasl_passwd ]; then
    chmod 640 /etc/postfix/sasl_passwd
    chown root:postfix /etc/postfix/sasl_passwd
    postmap hash:/etc/postfix/sasl_passwd
fi


# Инициализация таблиц и прав Postfix
if [ -f /etc/postfix/sender_relay ]; then
    chmod 640 /etc/postfix/sender_relay
    chown root:postfix /etc/postfix/sender_relay
    postmap /etc/postfix/sender_relay
fi

if [ -f /etc/postfix/sender_canonical ]; then
    chmod 640 /etc/postfix/sender_canonical
    chown root:postfix /etc/postfix/sender_canonical
    postmap /etc/postfix/sender_canonical
fi

if [ -f /etc/postfix/generic ]; then
    chmod 640 /etc/postfix/generic
    chown root:postfix /etc/postfix/generic
    postmap /etc/postfix/generic
fi




postfix set-permissions
postfix check

# В Debian crontabs лежат в /var/spool/cron/crontabs, но для удобства часто используют /etc/cron.d или /etc/crontabs (если есть пакет cronie/etc.)
# Стандартный путь в Debian: /var/spool/cron/crontabs/root
CRONTAB_DIR="/var/spool/cron/crontabs"
mkdir -p "$CRONTAB_DIR"

CRONTAB_FILE="$CRONTAB_DIR/root"

if [ ! -f "$CRONTAB_FILE" ]; then
    touch "$CRONTAB_FILE"
fi

# Добавляем задачу в crontab root
# Примечание: если файл уже содержит эту строку — будет дублирование. Для продакшена лучше проверять наличие строки.
echo "*/5 * * * * /usr/local/bin/auto_freeze.sh" >> "$CRONTAB_FILE"

# Права на crontab в Debian должны быть 600 и владелец root:root
chown root:root "$CRONTAB_FILE"
chmod 600 "$CRONTAB_FILE"

# Гарантируем, что в конце файла есть перевод строки (иначе cron может игнорировать последнюю строку)
if [ "$(tail -c 1 "$CRONTAB_FILE")" != $'\n' ]; then
    echo "" >> "$CRONTAB_FILE"
fi

# Запускаем cron в фоне (отдельно от основного процесса)
# Важно: cron должен работать, чтобы auto_freeze.sh выполнялся по расписанию
# cron &

# Передаём управление основной команде (CMD)
exec "$@"
