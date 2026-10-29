#!/usr/bin/env bash
set -euo pipefail

# Если монтируется sasl_passwd — создаём hash-базу
if [ -f /etc/postfix/sasl_passwd ]; then
    postmap hash:/etc/postfix/sasl_passwd
fi

SPOOL_DIR="/var/spool/postfix"

# Инициализация таблиц и прав Postfix
postmap /etc/postfix/sender_relay 2>/dev/null || true
postmap /etc/postfix/generic 2>/dev/null || true
postfix set-permissions 2>/dev/null || true
postfix queue 2>/dev/null || true

# Установка cron, если его нет (в образе может не быть)
if ! command -v cron > /dev/null 2>&1; then
    apt-get update && apt-get install -y --no-install-recommends cron && rm -rf /var/lib/apt/lists/*
fi

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
cron &

# Передаём управление основной команде (CMD)
exec "$@"
