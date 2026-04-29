# 🏠 AI Family Bookkeeping — 家庭账本

AI 驱动的家庭财务记账系统。通过飞书对话即可完成记账，无需手动填写表单。

## 架构概览

```
用户 → 飞书(萌客AI) → Go 后端 API → SQLite
                                    ↑
                              管理后台(Vue3) → 查看统计
```

**核心思路**：C 端能力由萌客AI 对接，系统只提供管理后台。用户发消息/截图给萌客AI，AI 完成识别 + 结构化 + 调 API 录入，一条龙。

## 技术栈

| 层 | 技术 | 说明 |
|---|------|------|
| 后端 | Go 1.22 + Gin + GORM | 单二进制，内存占用低 |
| 数据库 | SQLite | 2G 服务器友好，家庭场景零并发 |
| 前端 | Vue 3 + Vite + Naive UI | 轻量管理后台 |
| 认证 | JWT | 管理后台需登录，API 录入接口公开 |
| 识图 | 大模型多模态能力 | 萌客AI 内置，无需额外部署 |

## 功能

### 记账（萌客AI 入口）

- 💬 文字记账：`午饭 35`、`工资到账 25000`
- 📸 截图记账：发送支付截图，AI 识别金额/商户/分类自动填入
- 🔍 自动分类：根据备注关键词匹配分类（如"午餐"→餐饮，"打车"→交通）
- 👥 多成员：区分飞哥/丽丽的收支

### 管理后台

- 📊 仪表盘：月度收支概览 + 分类占比 + 成员对比
- 📋 收支明细：筛选/搜索/编辑/删除
- 📈 统计报表：日/周/月维度 + 环比同比
- 🏷️ 分类管理：自定义收支分类

## 快速部署

### 前置条件

- Linux 服务器（1C2G 即可）
- Go 1.22+、Node.js 18+（仅构建时需要）
- nginx（可选，生产模式推荐）
- Git

### 一键部署

```bash
# 1. 克隆项目
git clone git@github.com:McdullFei/ai-family-bookkeeping.git
cd ai-family-bookkeeping

# 2. 编译 + 启动 + 注册 systemd 服务
./start.sh --build --systemd
```

就这么简单。脚本会自动：
- 编译 Go 后端
- 安装前端依赖 + 构建
- 配置 nginx 反代
- 注册 systemd 服务（开机自启 + 崩溃自动重启）

### 常用命令

```bash
./start.sh              # 启动（已有编译产物）
./start.sh --build      # 编译 + 启动
./start.sh --dev        # 开发模式（vite dev server）
./start.sh --help       # 查看帮助

./stop.sh               # 停止后端
./stop.sh --all         # 停止全部（后端 + nginx）
./stop.sh --uninstall   # 卸载 systemd 服务

sudo systemctl restart family-ledger   # systemd 方式重启
sudo systemctl status family-ledger    # 查看状态
journalctl -u family-ledger -f        # 查看日志
```

### 端口说明

| 端口 | 服务 | 说明 |
|------|------|------|
| 8090 | Go API | 后端接口（录入、查询、统计） |
| 8091 | nginx | 管理后台前端 + API 反代 |

⚠️ 如果使用云服务器，需在安全组放行 8091 端口（或改用 80 端口）。

### 配置

编辑 `config/config.go`：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| Port | 8090 | 服务端口 |
| DBPath | ./data/family-ledger.db | SQLite 数据库路径 |
| AdminUser | admin | 管理员用户名 |
| AdminPass | family2026 | 管理员密码 |
| JWTSecret | f4m1ly-... | JWT 签名密钥 |
| JWTExpire | 72h | Token 有效期 |
| UploadDir | ./uploads | 截图存储目录 |

修改配置后需重新编译：`./start.sh --build`

## API 接口

### 公开接口（萌客AI 调用，无需认证）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/records | 创建记账记录 |
| GET | /api/categories | 分类列表 |
| GET | /api/members | 成员列表 |
| POST | /api/auth/login | 登录获取 Token |

### 认证接口（管理后台，需 Bearer Token）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/records | 记录列表（支持筛选分页） |
| PUT | /api/records/:id | 修改记录 |
| DELETE | /api/records/:id | 删除记录 |
| GET | /api/stats/daily | 日统计 + 环比同比 |
| GET | /api/stats/weekly | 周统计 + 环比同比 |
| GET | /api/stats/monthly | 月统计 + 环比同比 |
| GET | /api/stats/by-member | 按成员汇总 |
| GET | /api/stats/by-category | 按分类汇总 |
| POST | /api/categories | 新增分类 |
| PUT | /api/categories/:id | 修改分类 |
| DELETE | /api/categories/:id | 删除分类 |

### 录入示例

```bash
# 文字记账（自动匹配分类：午餐→餐饮🍜）
curl -X POST http://localhost:8090/api/records \
  -H "Content-Type: application/json" \
  -d '{"amount":35,"type":"expense","member":"飞哥","note":"午餐"}'

# 收入记账（自动匹配分类：工资→工资💰）
curl -X POST http://localhost:8090/api/records \
  -H "Content-Type: application/json" \
  -d '{"amount":25000,"type":"income","member":"丽丽","note":"工资到账"}'

# 指定分类
curl -X POST http://localhost:8090/api/records \
  -H "Content-Type: application/json" \
  -d '{"amount":28,"type":"expense","member":"飞哥","note":"打车","category_id":2}'

# 截图记账
curl -X POST http://localhost:8090/api/records \
  -H "Content-Type: application/json" \
  -d '{"amount":42.5,"type":"expense","member":"飞哥","note":"美团外卖","source":"ocr"}'
```

## 项目结构

```
.
├── main.go              # 入口，路由注册
├── start.sh             # 启动脚本（编译/构建/部署）
├── stop.sh              # 停止脚本
├── config/
│   └── config.go        # 配置（端口、DB路径、管理员账号）
├── models/
│   ├── record.go        # 记账记录模型 + 请求结构体
│   ├── category.go      # 分类模型
│   └── member.go        # 成员模型
├── handlers/
│   ├── record.go        # 记账 CRUD + 自动分类
│   ├── stats.go         # 统计接口
│   ├── category.go      # 分类管理
│   ├── member.go        # 成员列表
│   ├── auth.go          # 登录认证
│   └── helpers.go       # 公共辅助函数
├── middleware/
│   └── auth.go          # JWT 中间件
├── database/
│   └── init.go          # 数据库初始化 + 种子数据
├── web/                 # Vue 3 管理后台
│   ├── src/
│   │   ├── App.vue
│   │   ├── api/         # API 调用封装
│   │   ├── router/      # 路由配置
│   │   └── views/       # 页面组件
│   └── vite.config.js
├── data/                # SQLite 数据文件（gitignore）
└── uploads/             # 截图存储（gitignore）
```

## 默认数据

**支出分类（10个）**：餐饮🍜、交通🚗、居住🏠、购物🛍️、娱乐🎮、医疗🏥、教育📚、通讯📱、日用🧴、其他📦

**收入分类（4个）**：工资💰、兼职💼、理财📈、其他收入📦

**成员**：飞哥、丽丽

## License

MIT
