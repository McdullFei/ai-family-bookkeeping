# weather-qdcy

## Description
青岛城阳区精准天气预报技能。采用三级数据源聚合策略，确保天气数据准确且节省Token。

## Architecture
```
┌─────────────────────────────────────────────────────┐
│              weather-qdcy SKILL                    │
└─────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ↓                 ↓                 ↓
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   一级源     │ │   二级源     │ │   三级源     │
│  和风天气    │ │  中国天气网  │ │  备用API     │
│   API调用    │ │   页面抓取   │ │   极简模式   │
└──────────────┘ └──────────────┘ └──────────────┘
```

## Data Sources (Priority Order)

### 1. 一级源：和风天气 API (Primary)
- **Type**: API调用
- **Location**: 青岛市城阳区
- **Advantages**: 结构化JSON、响应快、官方数据源
- **Token Cost**: 极低（纯API调用）
- **Timeout**: 5秒

### 2. 二级源：中国天气网 (Secondary)
- **Type**: 页面抓取
- **URL**: https://www.weather.com.cn/weather/101120211.shtml
- **Location**: 青岛城阳区（区划码 101120211）
- **Advantages**: 官方权威、数据全面
- **Token Cost**: 中等（需要解析HTML）
- **Timeout**: 10秒

### 3. 三级源：备用API (Fallback)
- **Type**: 极简API
- **URL**: wttr.in/chengyang?format=j1
- **Advantages**: 无需认证、高可用
- **Token Cost**: 低
- **Timeout**: 8秒

## Usage

```bash
# 获取当前天气 + 今日预报
weather-qdcy

# 获取24小时逐小时预报
weather-qdcy --hourly

# 获取未来7天趋势
weather-qdcy --7days

# 获取空气质量
weather-qdcy --aqi

# 调试模式（显示数据源切换信息）
weather-qdcy --verbose
```

## Features
- ✅ 多源聚合，自动故障转移
- ✅ 30分钟缓存，避免重复请求
- ✅ 格式化输出，易读性强
- ✅ 支持多种预报维度

## Cache
- Location: `~/.openclaw/workspace/cache/weather-qdcy.json`
- TTL: 30 minutes
- Keys: `current`, `hourly`, `daily`, `aqi`

## Dependencies
- `qweather` skill (和风天气API)
- `weather-qd-cy` skill (中国天气网)
- `curl` / `wget` for HTTP requests
- `jq` for JSON parsing

## Error Handling
1. 主源超时 → 自动降级到备用源
2. 全部源失败 → 返回缓存数据（如有）
3. 缓存过期且无数据 → 返回友好错误信息

## Example Output
```
🌤️ 青岛城阳 今日天气
━━━━━━━━━━━━━━━━━━━━━━
🌡️ 当前温度: 12°C（体感 10°C）
☁️ 天气状况: 多云
💨 风力: 东南风 3级
💧 湿度: 65%

📅 今日预报
├─ 早晨  8°C  ☁️ 多云
├─ 中午 15°C  ⛅ 晴间多云
├─ 傍晚 12°C  ☁️ 多云
└─ 夜间  9°C  🌙 晴

⚠️ 出行提示: 天气多变，注意增减衣物
━━━━━━━━━━━━━━━━━━━━━━
📍 城阳区 | 更新时间: 08:00
🔗 数据源: 和风天气 (一级源)
```

## Files
- `SKILL.md` - 本文件
- `weather_qdcy.sh` - 主执行脚本
- `fetch_qweather.sh` - 和风天气数据抓取
- `fetch_cma.sh` - 中国天气网数据抓取
- `fetch_backup.sh` - 备用源数据抓取
- `parse_json.sh` - JSON解析工具
- `parse_html.sh` - HTML解析工具
- `cache.sh` - 缓存管理
- `format_output.sh` - 格式化输出

## Dependencies
- `curl` or `wget` - HTTP请求
- `jq` - JSON解析
- `grep`, `sed`, `awk` - 文本处理
- `date` - 时间处理

## Installation
```bash
# 克隆到 skills 目录
cd ~/.openclaw/workspace/skills
git clone <repo-url> weather-qdcy

# 或者手动创建目录并复制文件
mkdir -p weather-qdcy
cp *.sh weather-qdcy/
chmod +x weather-qdcy/*.sh
```

## Testing
```bash
# 测试主功能
./weather_qdcy.sh

# 测试特定数据源
./fetch_qweather.sh
./fetch_cma.sh
./fetch_backup.sh

# 调试模式
./weather_qdcy.sh --verbose
```

## Known Issues
- 中国天气网页面结构变更可能导致解析失败（已内置多种解析规则）
- 和风天气免费版API有每日限额（个人使用足够）
- 缓存文件需要定期清理（可配置cron任务）

## TODO
- [ ] 添加空气质量指数(AQI)支持
- [ ] 添加生活指数(穿衣、运动、洗车等)
- [ ] 添加雷达图和卫星云图
- [ ] 添加天气预警推送
- [ ] 支持更多城市（可配置）

## Maintainer
- 萌客AI 🐾
- 为飞哥家庭场景定制开发

## Changelog
- v1.0.0 (2026-03-29): 初始版本，三源聚合策略实现
  - 支持和风天气API（一级源）
  - 支持中国天气网抓取（二级源）
  - 支持wttr.in备用（三级源）
  - 30分钟缓存机制
  - 故障自动降级

## License
MIT License - 自由使用、修改、分发

---
*本SKILL为萌客AI家庭场景定制，优化Token消耗，确保数据准确性*
