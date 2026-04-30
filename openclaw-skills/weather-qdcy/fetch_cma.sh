#!/bin/bash
# 中国天气网数据抓取 - 青岛城阳区
# 区划码：101120211

set -e

CITY_CODE="101120211"
CACHE_FILE="${HOME}/.openclaw/workspace/cache/weather-qdcy-cma.json"
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

# 获取中国天气网数据
URL="https://www.weather.com.cn/weather/${CITY_CODE}.shtml"

RESPONSE=$(curl -s --max-time 10 "$URL" 2>/dev/null)

if [ -n "$RESPONSE" ]; then
    # 提取温度
    TEMP=$(echo "$RESPONSE" | grep -oE '<span class="tem">[0-9]+</span>' | grep -oE '[0-9]+' | head -1)
    
    # 提取天气状况
    TEXT=$(echo "$RESPONSE" | grep -oE '<p class="wea"[^>]*>[^<]+</p>' | sed 's/<[^>]*>//g' | head -1)
    
    # 提取风力
    WIND=$(echo "$RESPONSE" | grep -oE '<p class="win"[^>]*>[^<]+</p>' | sed 's/<[^>]*>//g' | head -1)
    
    # 提取湿度
    HUMIDITY=$(echo "$RESPONSE" | grep -oE '湿度[^0-9]*[0-9]+' | grep -oE '[0-9]+' | head -1)
    
    # 构建JSON输出
    cat > "$CACHE_FILE" << EOF
{
  "source": "cma",
  "timestamp": $(date +%s),
  "location": "青岛城阳",
  "data": {
    "temp": "${TEMP:-null}",
    "text": "${TEXT:-未知}",
    "humidity": "${HUMIDITY:---}",
    "wind": "${WIND:---}"
  }
}
EOF
    cat "$CACHE_FILE"
    exit 0
fi

# 失败
exit 1