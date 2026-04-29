#!/bin/bash
# 家庭账本停止脚本
# 用法: ./stop.sh [--all] [--nginx]
#   无参数    仅停止后端进程
#   --all     停止后端 + nginx 前端
#   --nginx   仅停止 nginx 前端

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="family-ledger"
PID_FILE="./data/${APP_NAME}.pid"
NGINX_CONF="/etc/nginx/conf.d/family-ledger.conf"

# ============ 函数 ============

stop_backend() {
  # 优先尝试 systemd
  if systemctl is-active --quiet "$APP_NAME" 2>/dev/null; then
    echo "🛑 停止 systemd 服务..."
    sudo systemctl stop "$APP_NAME"
    echo "✅ 后端已停止 (systemd)"
    rm -f "$PID_FILE"
    return
  fi

  # 回退到 PID 文件
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      echo "🛑 停止后端 (PID: $pid)..."
      kill "$pid"
      local retry=0
      while [ $retry -lt 10 ]; do
        if ! kill -0 "$pid" 2>/dev/null; then
          echo "✅ 后端已停止"
          rm -f "$PID_FILE"
          return
        fi
        sleep 1
        retry=$((retry + 1))
      done
      # 强制杀死
      echo "⚠️  进程未响应 SIGTERM，发送 SIGKILL..."
      kill -9 "$pid" 2>/dev/null
      echo "✅ 后端已强制停止"
      rm -f "$PID_FILE"
      return
    fi
    rm -f "$PID_FILE"
  fi

  # 最后手段：按名称查找
  local pids
  pids=$(pgrep -f "./${APP_NAME}" 2>/dev/null || true)
  if [ -n "$pids" ]; then
    echo "🛑 发现残留进程: $pids"
    kill $pids 2>/dev/null
    sleep 2
    kill -9 $pids 2>/dev/null || true
    echo "✅ 残留进程已清理"
    return
  fi

  echo "ℹ️  后端未在运行"
}

stop_nginx() {
  if [ -f "$NGINX_CONF" ]; then
    echo "🛑 移除 nginx 配置..."
    sudo rm -f "$NGINX_CONF"
    if sudo nginx -t 2>/dev/null; then
      sudo systemctl reload nginx 2>/dev/null || sudo nginx -s reload 2>/dev/null
      echo "✅ nginx 已重载（前端已下线）"
    else
      echo "⚠️  nginx 配置测试失败，请手动检查"
    fi
  else
    echo "ℹ️  nginx 配置文件不存在，跳过"
  fi
}

stop_dev_frontend() {
  local pids
  pids=$(pgrep -f "vite" 2>/dev/null || true)
  if [ -n "$pids" ]; then
    echo "🛑 停止 vite 开发服务器 (PID: $pids)..."
    kill $pids 2>/dev/null
    echo "✅ vite 已停止"
  fi
}

show_status() {
  echo ""
  echo "📋 当前状态:"

  # 后端
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "   后端: ✅ 运行中 (PID: $(cat "$PID_FILE"))"
  elif systemctl is-active --quiet "$APP_NAME" 2>/dev/null; then
    echo "   后端: ✅ 运行中 (systemd)"
  else
    echo "   后端: ⬜ 已停止"
  fi

  # nginx
  if [ -f "$NGINX_CONF" ]; then
    echo "   前端 (nginx): ✅ 已配置 (端口 8091)"
  else
    echo "   前端 (nginx): ⬜ 未配置"
  fi
}

# ============ 主逻辑 ============

STOP_ALL=false
STOP_NGINX_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --all)   STOP_ALL=true; shift ;;
    --nginx) STOP_NGINX_ONLY=true; shift ;;
    *)       echo "未知参数: $1"; exit 1 ;;
  esac
done

echo "========================================="
echo "  家庭账本 - 停止"
echo "========================================="

if [ "$STOP_NGINX_ONLY" = true ]; then
  stop_nginx
elif [ "$STOP_ALL" = true ]; then
  stop_backend
  stop_nginx
  stop_dev_frontend
else
  stop_backend
fi

show_status
