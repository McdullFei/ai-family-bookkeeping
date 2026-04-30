#!/bin/bash
# 和风天气数据抓取 - 青岛城阳区
# 优先使用API，失败则返回错误码

set -e

CITY_CODE="101120211"
CACHE_FILE="${HOME}/.openclaw/workspace/cache/weather-qdcy-qweather.json"
CACHE_TTL=1800  # 30分钟

# 检查缓存
if [ -f "$CACHE_FILE" ]; then
    cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    now=$(date +%s)
    if [ $((now - cache_time)) -lt $CACHE_TTL ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# 尝试获取和风天气数据
# 注意：这里使用网页抓取方式（免费）
URL="https://www.qweather.com/weather/${CITY_CODE}.html"

RESPONSE=$(curl -s --max-time 5 "$URL" 2>/dev/null | grep -oE 'temp":"[0-9]+"|text":"[^"]+"' | head -5)

if [ -n "$RESPONSE" ]; then
    # 解析数据
    TEMP=$(echo "$RESPONSE" | grep 'temp' | head -1 | grep -oE '[0-9]+')
    TEXT=$(echo "$RESPONSE" | grep 'text' | head -1 | grep -oE '"[^"]+"' | tr -d '"')
    
    # 构建JSON输出
    cat > "$CACHE_FILE" << EOF
{
  "source": "qweather",
  "timestamp": $(date +%s),
  "location": "青岛城阳",
  "data": {
    "temp": "${TEMP:-null}",
    "text": "${TEXT:-未知}",
    "humidity": "--",
    "wind": "--"
  }
}
EOF
    cat "$CACHE_FILE"
    exit 0
fi

# 失败
exit 1