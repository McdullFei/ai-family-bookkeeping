#!/bin/bash
# weather-qdcy 简化版 - 供 cron 使用（无颜色代码）

set -e

# 配置
CITY_NAME="青岛城阳"
CACHE_FILE="${HOME}/.openclaw/workspace/cache/weather-qdcy.json"

# 读取缓存数据
if [ -f "$CACHE_FILE" ]; then
    cache_data=$(cat "$CACHE_FILE" 2>/dev/null || echo "{}")
    source=$(echo "$cache_data" | grep -o '"source":"[^"]*"' | cut -d'"' -f4)
    temp=$(echo "$cache_data" | grep -o '"temp":"[^"]*"' | cut -d'"' -f4)
    text=$(echo "$cache_data" | grep -o '"text":"[^"]*"' | cut -d'"' -f4)
fi

# 如果没有缓存数据，尝试获取
if [ -z "$temp" ]; then
    # 尝试 wttr.in
    wttr_result=$(curl -s --max-time 10 "wttr.in/chengyang?format=%c+%t" 2>/dev/null || echo "")
    if [ -n "$wttr_result" ] && echo "$wttr_result" | grep -q "°C"; then
        temp=$(echo "$wttr_result" | grep -oE '[0-9]+°C' | grep -oE '[0-9]+' | head -1)
        text=$(echo "$wttr_result" | grep -oE '[⛅☀️🌧️❄️🌩️🌤️☁️]' | head -1)
        [ -z "$text" ] && text="晴"
        source="wttr.in"
    fi
fi

# 如果还是没获取到，使用默认值
if [ -z "$temp" ]; then
    temp="--"
    text="未知"
    source="获取失败"
fi

# 获取当前时间
current_time=$(date "+%H:%M")
current_date=$(date "+%m月%d日")

# 输出天气信息（纯文本，无颜色代码）
echo "🌤️ ${CITY_NAME} ${current_date} 天气"
echo ""
echo "🌡️ 当前温度: ${temp}°C"
echo "☁️ 天气状况: ${text}"
echo ""
echo "📍 数据来源: ${source}"
echo "🕐 更新时间: ${current_time}"
echo ""
echo "💡 出行提示: 天气多变，注意增减衣物"