#!/bin/bash
# 家庭账本启动脚本
# 用法: ./start.sh [--build] [--dev] [--systemd]
#   --build   启动前先编译后端和构建前端
#   --dev     开发模式（前端用 vite dev server，不依赖 nginx）
#   --systemd 安装 systemd 服务（开机自启 + 崩溃自动重启）

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ============ 配置区 ============
APP_NAME="family-ledger"
BINARY="./family-ledger"
PID_FILE="./data/${APP_NAME}.pid"
LOG_FILE="./data/${APP_NAME}.log"
DB_DIR="./data"
UPLOAD_DIR="./uploads"

# 后端配置
API_PORT=8090

# 前端配置
FRONTEND_PORT=8091
VITE_PORT=5173
WEB_DIR="./web"
DIST_DIR="./web/dist"
NGINX_CONF="/etc/nginx/conf.d/family-ledger.conf"

# ============ 颜色 ============
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}✅ $1${NC}"; }
log_err()  { echo -e "${RED}❌ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_info() { echo -e "🚀 $1"; }

# ============ 函数 ============

check_running() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    rm -f "$PID_FILE"
  fi
  # 也检查 systemd
  if systemctl is-active --quiet "$APP_NAME" 2>/dev/null; then
    return 0
  fi
  return 1
}

check_deps() {
  local missing=()
  command -v go >/dev/null 2>&1 || missing+=("go")
  command -v node >/dev/null 2>&1 || missing+=("node")
  command -v npm >/dev/null 2>&1 || missing+=("npm")

  if [ ${#missing[@]} -gt 0 ]; then
    log_err "缺少依赖: ${missing[*]}"
    echo "  安装方式:"
    echo "  Go:   https://go.dev/dl/ 或 sudo apt install golang-go"
    echo "  Node: https://nodejs.org/ 或 sudo apt install nodejs npm"
    exit 1
  fi
}

build_backend() {
  log_info "编译后端..."
  CGO_ENABLED=1 go build -o "$BINARY" .
  chmod +x "$BINARY"
  log_ok "后端编译完成: $BINARY"
}

build_frontend() {
  log_info "构建前端..."
  cd "$WEB_DIR"
  if [ ! -d "node_modules" ]; then
    log_info "安装前端依赖..."
    npm install --registry=https://registry.npmmirror.com
  fi
  npm run build
  cd "$SCRIPT_DIR"
  log_ok "前端构建完成: $DIST_DIR"
}

setup_nginx() {
  if [ ! -d "$DIST_DIR" ]; then
    log_err "前端 dist 目录不存在，请先运行: $0 --build"
    exit 1
  fi

  if ! command -v nginx &>/dev/null; then
    log_warn "nginx 未安装，跳过前端部署"
    log_warn "  安装: sudo apt install nginx  或  sudo yum install nginx"
    log_warn "  或者使用 --dev 模式: $0 --dev"
    return
  fi

  # 写入 nginx 配置
  sudo tee "$NGINX_CONF" > /dev/null << EOF
server {
    listen ${FRONTEND_PORT};
    server_name _;

    root ${SCRIPT_DIR}/${DIST_DIR};
    index index.html;

    # API 反向代理
    location /api/ {
        proxy_pass http://127.0.0.1:${API_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_connect_timeout 10s;
        proxy_read_timeout 30s;
    }

    # SPA 路由
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # 静态资源缓存
    location /assets/ {
        expires 7d;
        add_header Cache-Control "public, immutable";
    }
}
EOF

  if sudo nginx -t 2>/dev/null; then
    sudo systemctl reload nginx 2>/dev/null || sudo nginx -s reload 2>/dev/null
    log_ok "nginx 配置已更新，前端端口: ${FRONTEND_PORT}"
  else
    log_err "nginx 配置测试失败，请检查: sudo nginx -t"
  fi
}

start_backend() {
  mkdir -p "$DB_DIR" "$UPLOAD_DIR"

  if [ ! -f "$BINARY" ]; then
    log_err "后端二进制不存在，请先运行: $0 --build"
    exit 1
  fi

  if check_running; then
    log_warn "后端已在运行"
    return
  fi

  log_info "启动后端 (端口: ${API_PORT})..."
  nohup "$BINARY" >> "$LOG_FILE" 2>&1 &
  local pid=$!
  echo "$pid" > "$PID_FILE"

  # 等待启动
  local retry=0
  while [ $retry -lt 15 ]; do
    if curl -s -m 1 "http://127.0.0.1:${API_PORT}/api/members" >/dev/null 2>&1; then
      log_ok "后端启动成功 (PID: $pid)"
      return
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      log_err "后端启动失败，请查看日志: $LOG_FILE"
      rm -f "$PID_FILE"
      exit 1
    fi
    sleep 1
    retry=$((retry + 1))
  done

  log_warn "后端启动超时，请检查日志: $LOG_FILE"
}

start_dev_frontend() {
  log_info "启动前端开发服务器 (端口: ${VITE_PORT})..."
  cd "$WEB_DIR"
  if [ ! -d "node_modules" ]; then
    log_info "安装前端依赖..."
    npm install --registry=https://registry.npmmirror.com
  fi
  npx vite --host 0.0.0.0 --port "$VITE_PORT" &
  cd "$SCRIPT_DIR"
  log_ok "前端开发服务器已启动"
}

install_systemd() {
  local svc_file="/etc/systemd/system/${APP_NAME}.service"
  log_info "安装 systemd 服务..."
  sudo tee "$svc_file" > /dev/null << EOF
[Unit]
Description=Family Ledger API Server
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${SCRIPT_DIR}/${BINARY}
Restart=always
RestartSec=3
Environment=GIN_MODE=release

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable "$APP_NAME"
  log_ok "systemd 服务已安装 (开机自启)"

  # 如果后端正在运行，切换到 systemd 管理
  if [ -f "$PID_FILE" ]; then
    local old_pid
    old_pid=$(cat "$PID_FILE")
    if kill -0 "$old_pid" 2>/dev/null; then
      log_info "将运行中的后端切换到 systemd 管理..."
      kill "$old_pid" 2>/dev/null
      sleep 2
    fi
  fi
  sudo systemctl start "$APP_NAME"
  rm -f "$PID_FILE"
  log_ok "后端已由 systemd 接管"
}

get_server_ip() {
  # 尝试获取公网 IP
  curl -s -m 3 ifconfig.me 2>/dev/null || \
  curl -s -m 3 icanhazip.com 2>/dev/null || \
  hostname -I 2>/dev/null | awk '{print $1}' || \
  echo "<服务器IP>"
}

# ============ 主逻辑 ============

DEV_MODE=false
DO_BUILD=false
DO_SYSTEMD=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --build)   DO_BUILD=true; shift ;;
    --dev)     DEV_MODE=true; shift ;;
    --systemd) DO_SYSTEMD=true; shift ;;
    --help|-h)
      echo "用法: $0 [--build] [--dev] [--systemd]"
      echo ""
      echo "  --build    先编译后端+构建前端，再启动"
      echo "  --dev      开发模式（vite dev server，不依赖 nginx）"
      echo "  --systemd  安装 systemd 服务（开机自启+崩溃重启）"
      echo ""
      echo "首次部署推荐: $0 --build --systemd"
      exit 0
      ;;
    *)         echo "未知参数: $1 (使用 --help 查看帮助)"; exit 1 ;;
  esac
done

echo "========================================="
echo "  🏠 家庭账本 - 启动"
echo "========================================="

if [ "$DO_BUILD" = true ]; then
  check_deps
  build_backend
  build_frontend
fi

start_backend

if [ "$DO_SYSTEMD" = true ]; then
  install_systemd
fi

SERVER_IP=$(get_server_ip)

if [ "$DEV_MODE" = true ]; then
  start_dev_frontend
  echo ""
  echo "🌐 开发模式访问地址:"
  echo "   前端: http://${SERVER_IP}:${VITE_PORT}"
  echo "   后端: http://${SERVER_IP}:${API_PORT}"
else
  setup_nginx
  echo ""
  echo "🌐 生产模式访问地址:"
  echo "   前端: http://${SERVER_IP}:${FRONTEND_PORT}"
  echo "   后端: http://${SERVER_IP}:${API_PORT}"
  echo "   API:  http://${SERVER_IP}:${API_PORT}/api/records"
fi

echo ""
echo "📋 管理后台: admin / family2026"
echo "📋 日志: tail -f ${LOG_FILE}"
echo "📋 停止: ./stop.sh"
echo "📋 重启: ./stop.sh && ./start.sh"
