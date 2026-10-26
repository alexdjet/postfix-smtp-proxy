#!/usr/bin/env bash
set -euo pipefail

# Если монтируется sasl_passwd — создаём hash-базу
if [ -f /etc/postfix/sasl_passwd ]; then
    postmap hash:/etc/postfix/sasl_passwd
fi

SPOOL_DIR="/var/spool/postfix"

# Исправляем владельца всей директории на root
#chown -R  postfix:postdrop "$SPOOL_DIR"

#chown -R postdrop:postdrop "$SPOOL_DIR"
#chmod 750 "$SPOOL_DIR"

# Устанавливаем группу postdrop для нужных папок
#find "$SPOOL_DIR" -type d -exec chmod 750 {} \;
#find "$SPOOL_DIR" -type f -exec chmod 640 {} \;

# Инициализация
postmap /etc/postfix/sender_relay || 2>/dev/null || true
postfix set-permissions 2>/dev/null || true
postfix queue 2>/dev/null || true

# Устанавливаем cron (если ещё нет). --no-cache экономит место.
if ! command -v crond > /dev/null 2>&1; then
    apk add --no-cache crond
fi

# Создаём директорию для crontabs, если её нет (в Alpine она есть по умолчанию, но на всякий случай)
mkdir -p /etc/crontabs

# Проверяем наличие файла crontab для root.
CRONTAB_FILE="/etc/crontabs/root"
if [ ! -f "$CRONTAB_FILE" ]; then
    touch "$CRONTAB_FILE"
fi

# Add task
echo "*/5 * * * * /usr/local/bin/auto_freeze.sh" >> "$CRONTAB_FILE"

# Исправляем права. Cron в Alpine игнорирует файлы с неправильными правами!
chown root:root "$CRONTAB_FILE"
chmod 600 "$CRONTAB_FILE"

# Проверка: убедимся, что в конце файла есть перевод строки (иначе задача не сработает)
if [ "$(tail -c 1 "$CRONTAB_FILE")" != $'\n' ]; then
    echo "" >> "$CRONTAB_FILE"
fi

# Передаем управление основной команде (CMD)
exec "$@"
