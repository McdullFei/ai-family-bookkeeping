#!/bin/bash
# 备用源：wttr.in - 极简API
# 当一级二级源都失败时使用

set -e

CITY="chengyang"
CACHE_FILE="${HOME}/.openclaw/workspace/cache/weather-qdcy-backup.json"
CACHE_TTL=1800

# 检查缓存
if [ -f "$CACHE_FILE" ]; then
    cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    now=$(date +%s)
    if [ $((now - cache_time)) -lt $CACHE_TTL ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# 调用 wttr.in API
RESPONSE=$(curl -s --max-time 8 "wttr.in/${CITY}?format=%l:+%c+%t+%w+%h+%m" 2>/dev/null || echo "")

if [ -n "$RESPONSE" ] && echo "$RESPONSE" | grep -q "°C"; then
    # 解析极简格式: "城阳: ⛅ +14°C 🌬️ 西北风 3级 💧 45% 🌫️ 10km"
    TEMP=$(echo "$RESPONSE" | grep -oE '[+-][0-9]+°C' | head -1 | tr -d '+°C')
    [ -z "$TEMP" ] && TEMP=$(echo "$RESPONSE" | grep -oE '[0-9]+°C' | head -1 | tr -d '°C')
    
    # 提取天气图标
    WEATHER_ICON=$(echo "$RESPONSE" | grep -oE '[⛅☀️🌧️❄️🌩️🌤️☁️]' | head -1)
    case "$WEATHER_ICON" in
        ☀️|🌤️) TEXT="晴" ;;
        ⛅|☁️) TEXT="多云" ;;
        🌧️) TEXT="雨" ;;
        ❄️) TEXT="雪" ;;
        🌩️) TEXT="雷阵雨" ;;
        *) TEXT="多云" ;;
    esac
    
    # 构建JSON输出
    cat > "$CACHE_FILE" << EOF
{
  "source": "wttr.in",
  "timestamp": $(date +%s),
  "location": "青岛城阳",
  "data": {
    "temp": "${TEMP:-null}",
    "text": "${TEXT:-未知}",
    "raw": "${RESPONSE}"
  }
}
EOF
    cat "$CACHE_FILE"
    exit 0
fi

# 失败
exit 1