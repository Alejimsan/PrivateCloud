#!/bin/bash
TOKEN="TU_TOKEN_AQUI"
CHAT_ID="TU_ID_AQUI"

# Localizar la bateria
BAT_PATH=$(upower -e | grep BAT | head -n 1)
if [ -z "$BAT_PATH" ]; then exit 0; fi

# Extraer metricas
BAT_INFO=$(upower -i "$BAT_PATH")
STATE=$(echo "$BAT_INFO" | grep "state:" | awk '{print $2}')
PERCENT_STR=$(echo "$BAT_INFO" | grep "percentage:" | awk '{print $2}')
PERCENT=${PERCENT_STR%\%}

STATE_FILE="/tmp/last_bat_state"
PCT_FILE="/tmp/last_bat_pct"

LAST_STATE=$(cat "$STATE_FILE" 2>/dev/null)
LAST_PCT=$(cat "$PCT_FILE" 2>/dev/null)

# Funcion de envio a Telegram
send_msg() {
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$1" \
        -d parse_mode="Markdown" > /dev/null
}

# 1. Alerta de cambio de estado (Corte o Restauracion)
if [ "$STATE" != "$LAST_STATE" ]; then
    if [ "$STATE" == "discharging" ]; then
        send_msg "⚠️ *ALERTA UPOWER: Corte Eléctrico* ⚠️%0A🔌 Suministro perdido. El servidor funciona ahora como SAI.%0A🔋 Nivel actual: $PERCENT_STR"
    elif [[ "$STATE" == "charging" || "$STATE" == "fully-charged" ]]; then
        if [ "$LAST_STATE" == "discharging" ]; then
            send_msg "✅ *INFO UPOWER: Suministro Restaurado*%0A🔌 Corriente alterna conectada de nuevo.%0A🔋 Nivel actual: $PERCENT_STR"
        fi
    fi
    echo "$STATE" > "$STATE_FILE"
fi

# 2. Alertas por umbrales de porcentaje (solo en descarga)
if [ "$STATE" == "discharging" ]; then
    if [[ "$PERCENT" == "75" || "$PERCENT" == "50" || "$PERCENT" == "20" || "$PERCENT" == "15" ]]; then
        if [ "$LAST_PCT" != "$PERCENT" ]; then
            send_msg "📉 *AVISO UPOWER: Batería bajando*%0AEl servidor continúa sin corriente eléctrica.%0A🔋 Capacidad restante: $PERCENT_STR"
            echo "$PERCENT" > "$PCT_FILE"
        fi
    fi
else
    echo "" > "$PCT_FILE"
fi
