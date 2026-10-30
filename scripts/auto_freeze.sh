#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/mail.log"
LOG_FREEZE="/var/log/mail_freeze.log"
SCAN_LINES=500

# 1. Диагностика: проверяем, можем ли мы создать/обновить файл
if ! touch "$LOG_FREEZE" 2>/dev/null; then
    echo "ERROR: Не удалось создать/коснуться файла $LOG_FREEZE. Проверьте права." >&2
    exit 1
fi

# Проверяем права на запись
if [ ! -w "$LOG_FREEZE" ]; then
    echo "ERROR: Нет прав на запись в $LOG_FREEZE." >&2
    exit 1
fi

echo "DEBUG: Права на запись подтверждены. Начинаем обработку." >&2

# Сканируем последние N строк лога
tail_output=$(tail -n "$SCAN_LINES" "$LOG_FILE" 2>/dev/null || echo "")

if [ -z "$tail_output" ]; then
    {
        echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC'): Лог $LOG_FILE пуст или не найден. Просканировано строк: 0"
    } >> "$LOG_FREEZE"
    echo "DEBUG: Лог пуст, но запись в freeze-лог выполнена." >&2
    exit 0
fi

total_lines_in_sample=$(echo "$tail_output" | wc -l)

# Ищем ID сообщений Postfix (вырезаем двоеточие на конце через tr)
REJECTED_IDS=$(
    echo "$tail_output" | \
    grep "status=bounced" | \
    grep -i "5\.7\.0" | \
    grep -i "policy" | \
    grep -oE '\b[A-Z0-9]{10,12}\b|:[A-Z0-9]{10,12}:' | tr -d ':' | \
    sort -u
)

matched_count=0
if [ -n "$REJECTED_IDS" ]; then
    matched_count=$(echo "$REJECTED_IDS" | grep -c '^' || echo 0)
fi

processed_count=0

if [ "$matched_count" -gt 0 ]; then
    while IFS= read -r msg_id; do
        # Проверяем, что строка не пустая
        [ -z "$msg_id" ] && continue
        
        if postsuper -h "$msg_id" 2>/dev/null; then
            ((processed_count++))
        else
            echo "WARN: Не удалось заморозить $msg_id (возможно, уже удалён)" >&2
        fi
    done <<< "$REJECTED_IDS"

    {
        echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC'): Заморожены письма с ошибкой 5.7.0"
        echo "  Просканировано строк лога: $total_lines_in_sample (запрошено: $SCAN_LINES)"
        echo "  Найдено писем по критериям: $matched_count"
        echo "  Успешно заморожено: $processed_count"
    } >> "$LOG_FREEZE"

    echo "DEBUG: Статистика успешно записана в $LOG_FREEZE" >&2
else
    {
        echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC'): Нет новых отказов 5.7.0 по критериям"
        echo "  Просканировано строк лога: $total_lines_in_sample (запрошено: $SCAN_LINES)"
    } >> "$LOG_FREEZE"
    
    echo "DEBUG: Запись 'ничего не найдено' выполнена в $LOG_FREEZE" >&2
fi

echo "DEBUG: Обработка логов успешно завершена." >&2
