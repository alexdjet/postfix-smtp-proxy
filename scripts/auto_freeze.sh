#!/bin/bash

LOG_FILE="/var/log/mail.log"
# Ищем в логах за последние 2 минуты новые отказы 5.7.0
# Ищем ID сообщения, которое получило этот отказ
REJECTED_IDS=$(grep "status=bounced" $LOG_FILE | grep "5.7.0" | grep "policy" | tail -n 20 | awk '{print $6}' | sort | uniq)

if [ ! -z "$REJECTED_IDS" ]; then
    echo "$REJECTED_IDS" | xargs -r -n1 postsuper -h
    # Опционально: отправляем уведомление админу
    echo "$(date): Заморожены письма с ошибкой 5.7.0: $REJECTED_IDS" >> /var/log/mail_freeze.log
fi
