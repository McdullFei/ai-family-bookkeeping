#!/bin/bash
# 青岛城阳天气早报脚本 v2 - 使用 Open-Meteo API
# 支持未来三天预报、穿衣建议、运动建议

set -e

# 配置
CITY_NAME="青岛城阳"
LATITUDE="36.2667"
LONGITUDE="120.3667"
API_URL="https://api.open-meteo.com/v1/forecast"
CACHE_FILE="${HOME}/.openclaw/workspace/cache/weather-qdcy-v2.json"
CACHE_TTL=1800  # 30分钟缓存

# WMO Weather code 映射
get_weather_icon() {
    local code=$1
    case $code in
        0) echo "☀️ 晴" ;;
        1|2|3) echo "🌤️ 多云" ;;
        45|48) echo "🌫️ 雾" ;;
        51|53|55) echo "🌦️ 毛毛雨" ;;
        56|57) echo "🌧️ 冻雨" ;;
        61|63|65) echo "🌧️ 雨" ;;
        66|67) echo "🌧️ 冻雨" ;;
        71|73|75) echo "❄️ 雪" ;;
        77) echo "❄️ 雪粒" ;;
        80|81|82) echo "🌦️ 阵雨" ;;
        85|86) echo "❄️ 阵雪" ;;
        95|96|99) echo "⛈️ 雷雨" ;;
        *) echo "☁️ 多云" ;;
    esac
}

# 获取穿衣建议
get_clothing_advice() {
    local temp=$1
    local weather_code=$2
    
    # 提取温度整数
    local temp_int=$(echo "$temp" | cut -d. -f1)
    if [ -z "$temp_int" ] || [ "$temp_int" = "-" ]; then
        temp_int=20
    fi
    
    local advice=""
    
    # 根据天气状况
    if [ "$weather_code" -ge 95 ] 2>/dev/null; then
        advice="⛈️ 雷雨天气，建议穿防水外套，减少外出"
    elif [ "$weather_code" -ge 80 ] 2>/dev/null; then
        advice="🌦️ 有阵雨，建议带雨具，穿防水鞋"
    elif [ "$weather_code" -ge 61 ] 2>/dev/null; then
        advice="🌧️ 雨天路滑，建议穿防滑鞋，带雨伞"
    elif [ "$weather_code" -ge 45 ] 2>/dev/null; then
        advice="🌫️ 有雾能见度低，建议穿亮色衣物"
    elif [ "$temp_int" -lt 5 ] 2>/dev/null; then
        advice="🧥 严寒天气，建议穿羽绒服+毛衣+保暖内衣"
    elif [ "$temp_int" -lt 10 ] 2>/dev/null; then
        advice="🧥 天气较冷，建议穿外套+长袖+长裤"
    elif [ "$temp_int" -lt 15 ] 2>/dev/null; then
        advice="👔 天气微凉，建议穿薄外套+长袖"
    elif [ "$temp_int" -lt 25 ] 2>/dev/null; then
        advice="👕 天气舒适，建议穿长袖或短袖+薄外套"
    elif [ "$temp_int" -lt 30 ] 2>/dev/null; then
        advice="👕 天气较热，建议穿短袖+防晒措施"
    else
        advice="☀️ 高温天气，建议穿轻薄透气衣物，注意防暑"
    fi
    
    echo "$advice"
}

# 获取运动建议
get_sports_advice() {
    local temp=$1
    local weather_code=$2
    local wind=$3
    
    # 提取温度整数
    local temp_int=$(echo "$temp" | cut -d. -f1)
    if [ -z "$temp_int" ] || [ "$temp_int" = "-" ]; then
        temp_int=20
    fi
    
    local advice=""
    
    # 根据天气状况判断
    if [ "$weather_code" -ge 95 ] 2>/dev/null; then
        advice="⛈️ 雷雨天气，建议室内运动（健身房、瑜伽、跑步机）"
    elif [ "$weather_code" -ge 80 ] 2>/dev/null; then
        advice="🌦️ 阵雨天气，建议室内运动或等雨停后外出"
    elif [ "$weather_code" -ge 61 ] 2>/dev/null; then
        advice="🌧️ 雨天路滑，建议选择室内运动，避免户外运动"
    elif [ "$weather_code" -ge 45 ] 2>/dev/null; then
        advice="🌫️ 雾霾天气，建议减少户外运动，选择室内健身"
    elif [ "$temp_int" -lt 0 ] 2>/dev/null; then
        advice="❄️ 严寒天气，建议室内热身运动，外出注意保暖防滑"
    elif [ "$temp_int" -lt 10 ] 2>/dev/null; then
        advice="🧥 天气较冷，户外运动前充分热身，注意保暖"
    elif [ "$temp_int" -gt 30 ] 2>/dev/null; then
        advice="☀️ 高温天气，建议避开正午运动，多补水，防中暑"
    else
        # 检查风力
        local wind_int=$(echo "$wind" | cut -d. -f1)
        if [ -n "$wind_int" ] && [ "$wind_int" != "-" ] && [ "$wind_int" -gt 20 ] 2>/dev/null; then
            advice="💨 风力较大，建议避免骑行等受风影响大的运动"
        else
            advice="✅ 天气适宜运动，可进行户外跑步、骑行、健身等活动"
        fi
    fi
    
    echo "$advice"
}

# 获取天气数据
fetch_weather() {
    local params="latitude=${LATITUDE}&longitude=${LONGITUDE}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=Asia%2FShanghai&forecast_days=4"
    
    curl -s --max-time 15 "${API_URL}?${params}" 2>/dev/null
}

# 主函数
main() {
    # 获取天气数据
    local response=$(fetch_weather)
    
    if [ -z "$response" ]; then
        echo "❌ 获取天气数据失败，请检查网络连接"
        exit 1
    fi
    
    # 使用 Python 解析 JSON
    local parsed_data=$(echo "$response" | python3 -c '
import json
import sys
from datetime import datetime, timedelta

try:
    data = json.load(sys.stdin)
    
    # 当前数据
    current = data.get("current", {})
    daily = data.get("daily", {})
    
    temp = current.get("temperature_2m", "--")
    weather_code = current.get("weather_code", "0")
    humidity = current.get("relative_humidity_2m", "--")
    wind = current.get("wind_speed_10m", "--")
    
    # 今日温度范围
    max_temp = daily.get("temperature_2m_max", ["--"])[0]
    min_temp = daily.get("temperature_2m_min", ["--"])[0]
    
    # 未来三天预报
    dates = daily.get("time", [])
    max_temps = daily.get("temperature_2m_max", [])
    min_temps = daily.get("temperature_2m_min", [])
    codes = daily.get("weather_code", [])
    
    forecast = []
    for i in range(1, min(4, len(dates))):
        forecast.append({
            "date": dates[i],
            "max": max_temps[i] if i < len(max_temps) else "--",
            "min": min_temps[i] if i < len(min_temps) else "--",
            "code": codes[i] if i < len(codes) else "0"
        })
    
    # 输出
    print(f"temp={temp}")
    print(f"weather_code={weather_code}")
    print(f"humidity={humidity}")
    print(f"wind={wind}")
    print(f"max_temp={max_temp}")
    print(f"min_temp={min_temp}")
    print(f"forecast={json.dumps(forecast)}")
    
except Exception as e:
    print(f"error={e}", file=sys.stderr)
    sys.exit(1)
')
    
    if echo "$parsed_data" | grep -q "error="; then
        echo "❌ 解析天气数据失败"
        exit 1
    fi
    
    # 解析数据
    local temp=$(echo "$parsed_data" | grep "^temp=" | cut -d= -f2)
    local weather_code=$(echo "$parsed_data" | grep "^weather_code=" | cut -d= -f2)
    local humidity=$(echo "$parsed_data" | grep "^humidity=" | cut -d= -f2)
    local wind=$(echo "$parsed_data" | grep "^wind=" | cut -d= -f2)
    local max_temp=$(echo "$parsed_data" | grep "^max_temp=" | cut -d= -f2)
    local min_temp=$(echo "$parsed_data" | grep "^min_temp=" | cut -d= -f2)
    local forecast=$(echo "$parsed_data" | grep "^forecast=" | cut -d= -f2-)
    
    # 设置默认值
    temp="${temp:---}"
    weather_code="${weather_code:-0}"
    humidity="${humidity:---}"
    wind="${wind:---}"
    max_temp="${max_temp:---}"
    min_temp="${min_temp:---}"
    
    # 转换天气代码为文本
    local weather_text=$(get_weather_icon "$weather_code")
    
    # 获取穿衣和运动建议
    local clothing_advice=$(get_clothing_advice "$temp" "$weather_code")
    local sports_advice=$(get_sports_advice "$temp" "$weather_code" "$wind")
    
    # 获取当前时间
    local current_time=$(date "+%H:%M")
    local current_date=$(date "+%m月%d日")
    
    # 输出天气信息
    echo "🌤️ ${CITY_NAME} ${current_date} 天气早报"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 当前天气"
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo "🌡️ 当前温度: ${temp}°C"
    echo "📊 温度范围: ${min_temp}°C ~ ${max_temp}°C"
    echo "☁️ 天气状况: ${weather_text}"
    echo "💧 相对湿度: ${humidity}%"
    echo "🌬️ 风速: ${wind}km/h"
    echo ""
    
    # 未来三天预报
    if [ -n "$forecast" ] && [ "$forecast" != "[]" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━"
        echo "📅 未来三天预报"
        echo "━━━━━━━━━━━━━━━━━━━━━"
        
        # 使用 Python 解析预报数据
        echo "$forecast" | python3 -c '
import json
import sys
from datetime import datetime

try:
    forecast = json.load(sys.stdin)
    for day in forecast:
        date_str = day["date"]
        # 转换为 MM-DD 格式
        date_obj = datetime.strptime(date_str, "%Y-%m-%d")
        formatted_date = date_obj.strftime("%m月%d日")
        weekday = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][date_obj.weekday()]
        
        max_temp = day["max"]
        min_temp = day["min"]
        code = day["code"]
        
        # 天气图标映射
        icons = {
            0: "☀️", 1: "🌤️", 2: "⛅", 3: "🌥️",
            45: "🌫️", 48: "🌫️",
            51: "🌦️", 53: "🌦️", 55: "🌧️",
            61: "🌧️", 63: "🌧️", 65: "🌧️",
            71: "❄️", 73: "❄️", 75: "❄️",
            80: "🌦️", 81: "🌧️", 82: "🌧️",
            95: "⛈️", 96: "⛈️", 99: "⛈️"
        }
        icon = icons.get(int(code), "☁️")
        
        print(f"{icon} {formatted_date} ({weekday}): {min_temp}°C ~ {max_temp}°C")
        
except Exception as e:
    print(f"  预报数据解析失败: {e}", file=sys.stderr)
'
        echo ""
    fi
    
    # 穿衣和运动建议
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo "👕 穿衣建议"
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo "${clothing_advice}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo "🏃 运动建议"
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo "${sports_advice}"
    echo ""
    
    # 数据来源和更新时间
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 数据来源: Open-Meteo API"
    echo "🕐 更新时间: ${current_time}"
    echo "━━━━━━━━━━━━━━━━━━━━━"
}

# 执行主函数
main
