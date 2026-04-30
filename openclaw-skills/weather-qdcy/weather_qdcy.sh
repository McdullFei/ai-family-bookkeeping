#!/bin/bash
# weather-qdcy 主执行脚本
# 青岛城阳区天气预报聚合技能
# 适用于 cron 环境

set -e

# 设置 PATH 以确保在 cron 环境中能找到命令
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"

# 配置
CITY_NAME="青岛城阳"
CITY_CODE="101120211"
CACHE_DIR="${HOME}/.openclaw/workspace/cache"
CACHE_FILE="${CACHE_DIR}/weather-qdcy.json"
CACHE_TTL=1800  # 30分钟

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 确保缓存目录存在
mkdir -p "$CACHE_DIR"

# 获取当前时间戳
get_timestamp() {
    date +%s 2>/dev/null || echo "0"
}

# 格式化时间
format_time() {
    date "+%H:%M" 2>/dev/null || echo "--:--"
}

# 安全获取文件修改时间（兼容不同系统）
get_file_mtime() {
    local file="$1"
    if [ -f "$file" ]; then
        # 尝试 Linux stat
        stat -c %Y "$file" 2>/dev/null || \
        # 尝试 macOS stat
        stat -f %m "$file" 2>/dev/null || \
        # 使用 ls 作为后备
        date -r "$file" +%s 2>/dev/null || \
        echo "0"
    else
        echo "0"
    fi
}

# 检查缓存
 check_cache() {
    if [ -f "$CACHE_FILE" ]; then
        local cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
        local now=$(get_timestamp)
        if [ $((now - cache_time)) -lt $CACHE_TTL ]; then
            return 0  # 缓存有效
        fi
    fi
    return 1  # 缓存无效或不存在
}

# 读取缓存
read_cache() {
    cat "$CACHE_FILE" 2>/dev/null || echo "{}"
}

# 保存缓存
save_cache() {
    local data="$1"
    echo "$data" > "$CACHE_FILE"
}

# 输出天气信息
output_weather() {
    local source="$1"
    local temp="$2"
    local text="$3"
    local humidity="${4:---}"
    local wind="${5:---}"
    local update_time=$(format_time)
    
    echo ""
    echo -e "${BLUE}🌤️  ${CITY_NAME}  今日天气${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "🌡️  ${GREEN}当前温度:${NC} ${temp}°C"
    echo -e "☁️  ${GREEN}天气状况:${NC} ${text}"
    echo -e "💧 ${GREEN}湿度:${NC} ${humidity}%"
    echo -e "💨 ${GREEN}风力:${NC} ${wind}"
    echo ""
    echo -e "${YELLOW}⚠️ 出行提示:${NC} 天气多变，注意增减衣物"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "📍 ${CITY_NAME} | 🕐 更新: ${update_time}"
    echo -e "🔗 ${YELLOW}数据源: ${source}${NC}"
    echo ""
}

# 主函数
main() {
    local source=""
    local temp=""
    local text=""
    local humidity=""
    local wind=""
    
    # 检查缓存
    if check_cache; then
        local cache_data=$(read_cache)
        source=$(echo "$cache_data" | grep -o '"source":"[^"]*"' | cut -d'"' -f4)
        temp=$(echo "$cache_data" | grep -o '"temp":"[^"]*"' | cut -d'"' -f4)
        text=$(echo "$cache_data" | grep -o '"text":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$temp" ] && [ -n "$text" ]; then
            output_weather "$source (缓存)" "$temp" "$text" "" ""
            exit 0
        fi
    fi
    
    # 尝试一级源：和风天气
    echo "🔄 尝试一级源：和风天气..." >&2
    local qw_response=$(curl -s --max-time 5 "https://www.qweather.com/weather/${CITY_CODE}.html" 2>/dev/null | grep -oE 'temp":"[0-9]+"|text":"[^"]+"' | head -5)
    
    if [ -n "$qw_response" ]; then
        temp=$(echo "$qw_response" | grep 'temp' | head -1 | grep -oE '[0-9]+')
        text=$(echo "$qw_response" | grep 'text' | head -1 | grep -oE '"[^"]+"' | tr -d '"')
        source="和风天气"
        
        # 保存缓存
        save_cache "{\"source\":\"$source\",\"temp\":\"$temp\",\"text\":\"$text\",\"timestamp\":$(date +%s)}"
        
        output_weather "$source" "$temp" "$text" "" ""
        exit 0
    fi
    
    # 尝试二级源：中国天气网
    echo "🔄 尝试二级源：中国天气网..." >&2
    local cma_response=$(curl -s --max-time 10 "https://www.weather.com.cn/weather/${CITY_CODE}.shtml" 2>/dev/null)
    
    if [ -n "$cma_response" ]; then
        # 多种解析尝试
        temp=$(echo "$cma_response" | grep -oE '<span class="tem">[0-9]+</span>' | grep -oE '[0-9]+' | head -1)
        [ -z "$temp" ] && temp=$(echo "$cma_response" | grep -oE 'class="tem[0-9]*">[0-9]+' | grep -oE '[0-9]+' | head -1)
        
        text=$(echo "$cma_response" | grep -oE '<p class="wea"[^>]*>[^<]+</p>' | sed 's/<[^>]*>//g' | head -1)
        [ -z "$text" ] && text=$(echo "$cma_response" | grep -oE 'class="wea[^"]*">[^<]+' | sed 's/.*>//' | head -1)
        
        if [ -n "$temp" ]; then
            source="中国天气网"
            [ -z "$text" ] && text="多云"
            
            # 保存缓存
            save_cache "{\"source\":\"$source\",\"temp\":\"$temp\",\"text\":\"$text\",\"timestamp\":$(date +%s)}"
            
            output_weather "$source" "$temp" "$text" "" ""
            exit 0
        fi
    fi
    
    # 尝试三级源：wttr.in
    echo "🔄 尝试三级源：wttr.in..." >&2
    local wttr_response=$(curl -s --max-time 8 "wttr.in/chengyang?format=%l:+%c+%t+%w+%h" 2>/dev/null)
    
    if [ -n "$wttr_response" ] && echo "$wttr_response" | grep -q "°C"; then
        # 解析 wttr.in 格式: "城阳: ⛅ +14°C 🌬️ 西北风 3级 💧 45%"
        temp=$(echo "$wttr_response" | grep -oE '[+-][0-9]+°C' | grep -oE '[0-9]+' | head -1)
        [ -z "$temp" ] && temp=$(echo "$wttr_response" | grep -oE '[0-9]+°C' | grep -oE '[0-9]+' | head -1)
        
        # 提取天气图标/文字
        text=$(echo "$wttr_response" | grep -oE '[⛅☀️🌧️❄️🌩️🌤️☁️][^ ]*' | head -1)
        [ -z "$text" ] && text="多云"
        
        source="wttr.in"
        
        # 保存缓存
        save_cache "{\"source\":\"$source\",\"temp\":\"$temp\",\"text\":\"$text\",\"timestamp\":$(date +%s)}"
        
        output_weather "$source" "$temp" "$text" "" ""
        exit 0
    fi
    
    # 全部失败，尝试读取旧缓存
    if [ -f "$CACHE_FILE" ]; then
        local old_cache=$(read_cache)
        local old_time=$(echo "$old_cache" | grep -o '"timestamp":[0-9]*' | grep -oE '[0-9]+')
        local now=$(get_timestamp)
        
        # 缓存6小时内可用
        if [ $((now - old_time)) -lt 21600 ] && [ -n "$old_time" ]; then
            source=$(echo "$old_cache" | grep -o '"source":"[^"]*"' | cut -d'"' -f4)
            temp=$(echo "$old_cache" | grep -o '"temp":"[^"]*"' | cut -d'"' -f4)
            text=$(echo "$old_cache" | grep -o '"text":"[^"]*"' | cut -d'"' -f4)
            
            if [ -n "$temp" ]; then
                output_weather "$source (缓存)" "$temp" "$text" "" ""
                exit 0
            fi
        fi
    fi
    
    # 彻底失败
    echo ""
    echo -e "${RED}❌ 无法获取天气数据${NC}"
    echo ""
    echo "已尝试所有数据源："
    echo "  ❌ 和风天气 API"
    echo "  ❌ 中国天气网"
    echo "  ❌ wttr.in 备用"
    echo ""
    echo "请检查网络连接或稍后重试。"
    echo ""
    exit 1
}

# 执行主函数
main