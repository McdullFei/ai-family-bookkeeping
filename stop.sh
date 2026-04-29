#!/bin/bash
# 家庭账本停止脚本
# 用法: ./stop.sh [--all] [--nginx] [--uninstall]
#   无参数      仅停止后端进程
#   --all       停止后端 + nginx 前端
#   --nginx     仅停止 nginx 前端
#   --uninstall 卸载 systemd 服务

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="family-ledger"
PID_FILE="./data/${APP_NAME}.pid"
NGINX_CONF="/etc/nginx/conf.d/family-ledger.conf"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}✅ $1${NC}"; }
log_err()  { echo -e "${RED}❌ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_info() { echo -e "🛑 $1"; }

# ============ 函数 ============

stop_backend() {
  # 优先尝试 systemd
  if systemctl is-active --quiet "$APP_NAME" 2>/dev/null; then
    log_info "停止 systemd 服务..."
    sudo systemctl stop "$APP_NAME"
    log_ok "后端已停止 (systemd)"
    rm -f "$PID_FILE"
    return
  fi

  # PID 文件方式
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      log_info "停止后端 (PID: $pid)..."
      kill "$pid"
      local retry=0
      while [ $retry -lt 10 ]; do
        if ! kill -0 "$pid" 2>/dev/null; then
          log_ok "后端已停止"
          rm -f "$PID_FILE"
          return
        fi
        sleep 1
        retry=$((retry + 1))
      done
      echo "⚠️  进程未响应 SIGTERM，发送 SIGKILL..."
      kill -9 "$pid" 2>/dev/null
      log_ok "后端已强制停止"
      rm -f "$PID_FILE"
      return
    fi
    rm -f "$PID_FILE"
  fi

  # 按名称查找
  local pids
  pids=$(pgrep -f "./${APP_NAME}" 2>/dev/null || true)
  if [ -n "$pids" ]; then
    log_info "发现残留进程: $pids"
    kill $pids 2>/dev/null
    sleep 2
    kill -9 $pids 2>/dev/null || true
    log_ok "残留进程已清理"
    return
  fi

  log_warn "后端未在运行"
}

stop_nginx() {
  if [ -f "$NGINX_CONF" ]; then
    log_info "移除 nginx 配置..."
    sudo rm -f "$NGINX_CONF"
    if sudo nginx -t 2>/dev/null; then
      sudo systemctl reload nginx 2>/dev/null || sudo nginx -s reload 2>/dev/null
      log_ok "nginx 已重载（前端已下线）"
    else
      log_warn "nginx 配置测试失败，请手动检查"
    fi
  else
    log_warn "nginx 配置文件不存在，跳过"
  fi
}

stop_dev_frontend() {
  local pids
  pids=$(pgrep -f "vite" 2>/dev/null || true)
  if [ -n "$pids" ]; then
    log_info "停止 vite 开发服务器 (PID: $pids)..."
    kill $pids 2>/dev/null
    log_ok "vite 已停止"
  fi
}

uninstall_systemd() {
  if [ -f "/etc/systemd/system/${APP_NAME}.service" ]; then
    log_info "卸载 systemd 服务..."
    sudo systemctl stop "$APP_NAME" 2>/dev/null || true
    sudo systemctl disable "$APP_NAME" 2>/dev/null || true
    sudo rm -f "/etc/systemd/system/${APP_NAME}.service"
    sudo systemctl daemon-reload
    log_ok "systemd 服务已卸载"
  else
    log_warn "systemd 服务未安装"
  fi
}

show_status() {
  echo ""
  echo "📋 当前状态:"

  # 后端
  if systemctl is-active --quiet "$APP_NAME" 2>/dev/null; then
    echo "   后端: ✅ 运行中 (systemd)"
  elif [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "   后端: ✅ 运行中 (PID: $(cat "$PID_FILE"))"
  else
    echo "   后端: ⬜ 已停止"
  fi

  # nginx
  if [ -f "$NGINX_CONF" ]; then
    echo "   前端 (nginx): ✅ 已配置 (端口 8091)"
  else
    echo "   前端 (nginx): ⬜ 未配置"
  fi

  # systemd
  if [ -f "/etc/systemd/system/${APP_NAME}.service" ]; then
    echo "   systemd: ✅ 已安装"
  else
    echo "   systemd: ⬜ 未安装"
  fi
}

# ============ 主逻辑 ============

STOP_ALL=false
STOP_NGINX_ONLY=false
DO_UNINSTALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --all)       STOP_ALL=true; shift ;;
    --nginx)     STOP_NGINX_ONLY=true; shift ;;
    --uninstall) DO_UNINSTALL=true; shift ;;
    --help|-h)
      echo "用法: $0 [--all] [--nginx] [--uninstall]"
      echo ""
      echo "  无参数      仅停止后端"
      echo "  --all       停止后端 + nginx + vite"
      echo "  --nginx     仅下线前端"
      echo "  --uninstall 卸载 systemd 服务"
      exit 0
      ;;
    *)         echo "未知参数: $1"; exit 1 ;;
  esac
done

echo "========================================="
echo "  🏠 家庭账本 - 停止"
echo "========================================="

if [ "$DO_UNINSTALL" = true ]; then
  stop_backend
  stop_nginx
  uninstall_systemd
elif [ "$STOP_NGINX_ONLY" = true ]; then
  stop_nginx
elif [ "$STOP_ALL" = true ]; then
  stop_backend
  stop_nginx
  stop_dev_frontend
else
  stop_backend
fi

show_status
