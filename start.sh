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

# 后端配置（与 config/config.go 保持一致）
API_PORT=8090

# 前端配置
FRONTEND_PORT=8091        # nginx 生产模式端口
VITE_PORT=5173            # vite 开发模式端口
WEB_DIR="./web"
DIST_DIR="./web/dist"
NGINX_CONF="/etc/nginx/conf.d/family-ledger.conf"

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
  return 1
}

build_backend() {
  echo "🔧 编译后端..."
  go build -o "$BINARY" .
  chmod +x "$BINARY"
  echo "✅ 后端编译完成: $BINARY"
}

build_frontend() {
  echo "🔧 构建前端..."
  cd "$WEB_DIR"
  if [ ! -d "node_modules" ]; then
    echo "📦 安装前端依赖..."
    npm install
  fi
  npm run build
  cd "$SCRIPT_DIR"
  echo "✅ 前端构建完成: $DIST_DIR"
}

setup_nginx() {
  if [ ! -d "$DIST_DIR" ]; then
    echo "❌ 前端 dist 目录不存在，请先运行: $0 --build"
    exit 1
  fi

  if ! command -v nginx &>/dev/null; then
    echo "⚠️  nginx 未安装，跳过 nginx 配置"
    echo "   前端需手动部署或使用 --dev 模式"
    return
  fi

  sudo tee "$NGINX_CONF" > /dev/null << NGINXEOF
server {
    listen ${FRONTEND_PORT};
    server_name _;

    root ${SCRIPT_DIR}/${DIST_DIR};
    index index.html;

    location /api/ {
        proxy_pass http://127.0.0.1:${API_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
NGINXEOF

  if sudo nginx -t 2>/dev/null; then
    sudo systemctl reload nginx 2>/dev/null || sudo nginx -s reload 2>/dev/null
    echo "✅ nginx 配置已更新，前端端口: ${FRONTEND_PORT}"
  else
    echo "⚠️  nginx 配置测试失败，请检查: sudo nginx -t"
  fi
}

start_backend() {
  mkdir -p "$DB_DIR" "$UPLOAD_DIR"

  if [ ! -f "$BINARY" ]; then
    echo "❌ 后端二进制不存在，请先运行: $0 --build"
    exit 1
  fi

  if check_running; then
    local pid
    pid=$(cat "$PID_FILE")
    echo "⚠️  后端已在运行 (PID: $pid)"
    return
  fi

  echo "🚀 启动后端 (端口: ${API_PORT})..."
  nohup "$BINARY" >> "$LOG_FILE" 2>&1 &
  local pid=$!
  echo "$pid" > "$PID_FILE"

  local retry=0
  while [ $retry -lt 10 ]; do
    if curl -s -m 1 "http://127.0.0.1:${API_PORT}/api/members" >/dev/null 2>&1; then
      echo "✅ 后端启动成功 (PID: $pid)"
      return
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "❌ 后端启动失败，请查看日志: $LOG_FILE"
      rm -f "$PID_FILE"
      exit 1
    fi
    sleep 1
    retry=$((retry + 1))
  done

  echo "⚠️  后端启动超时，请检查日志: $LOG_FILE"
}

start_dev_frontend() {
  echo "🚀 启动前端开发服务器 (端口: ${VITE_PORT})..."
  cd "$WEB_DIR"
  if [ ! -d "node_modules" ]; then
    echo "📦 安装前端依赖..."
    npm install
  fi
  npx vite --host 0.0.0.0 --port "$VITE_PORT" &
  cd "$SCRIPT_DIR"
  echo "✅ 前端开发服务器已启动"
}

install_systemd() {
  local svc_file="/etc/systemd/system/${APP_NAME}.service"
  sudo tee "$svc_file" > /dev/null << SYSEOF
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

[Install]
WantedBy=multi-user.target
SYSEOF
  sudo systemctl daemon-reload
  sudo systemctl enable "$APP_NAME"
  echo "✅ systemd 服务已安装 (开机自启)"
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
    *)         echo "未知参数: $1"; exit 1 ;;
  esac
done

echo "========================================="
echo "  家庭账本 - 启动"
echo "========================================="

if [ "$DO_BUILD" = true ]; then
  build_backend
  build_frontend
fi

start_backend

if [ "$DO_SYSTEMD" = true ]; then
  install_systemd
fi

if [ "$DEV_MODE" = true ]; then
  start_dev_frontend
  echo ""
  echo "🌐 开发模式访问地址:"
  echo "   前端: http://<服务器IP>:${VITE_PORT}"
  echo "   后端: http://<服务器IP>:${API_PORT}"
else
  setup_nginx
  echo ""
  echo "🌐 生产模式访问地址:"
  echo "   前端: http://<服务器IP>:${FRONTEND_PORT}"
  echo "   后端: http://<服务器IP>:${API_PORT}"
fi

echo ""
echo "📋 日志: tail -f ${LOG_FILE}"
echo "📋 停止: ./stop.sh"
