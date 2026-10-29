#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/mail.log"
LOG_FREEZE="/var/log/mail_freeze.log"

# Создаём файл лога, если его нет, и убеждаемся, что у postfix/root есть права на запись
mkdir -p "$(dirname "$LOG_FREEZE")"
touch "$LOG_FREEZE" 2>/dev/null || true

# Ищем ID сообщений со статусом bounced и ошибкой 5.7.0 (policy reject)
# Ограничиваем поиск последними N строками, чтобы не сканировать весь лог каждый раз
REJECTED_IDS=$(
    tail -n 500 "$LOG_FILE" 2>/dev/null | \
    grep "status=bounced" | \
    grep -i "5\.7\.0" | \
    grep -i "policy" | \
    awk '{print $6}' | \
    sort -u
)

if [ -n "$REJECTED_IDS" ]; then
    # postsuper -h требует root. В контейнере это нормально, если entrypoint запускается от root
    echo "$REJECTED_IDS" | xargs -r -n1 postsuper -h

    # Логируем факт заморозки
    {
        echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC'): Заморожены письма с ошибкой 5.7.0: $REJECTED_IDS"
    } >> "$LOG_FREEZE"
else
    # Опционально: тихий лог «ничего не найдено» (можно убрать, если не нужно)
    # echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC'): Нет новых отказов 5.7.0" >> "$LOG_FREEZE"
    :
fi
