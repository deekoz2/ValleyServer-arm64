#!/usr/bin/env bash
# ============================================================
#  ValleyServer-arm64 一键安装脚本（Termux / ZeroTermux）
#  星露谷物语无头专用服务器 · 基于 tmoe proot 容器
#
#  用法:
#    bash install.sh             # 全流程（依赖 + tmoe 容器 + 服务器）
#    bash install.sh --server    # 跳过容器创建，仅部署服务器
#    bash install.sh --fix       # 只修复/重建 valley 与 run.sh（秒级）
#    bash install.sh --start     # 部署完直接后台启动
#
#  服务器: ValleyServer v3.0.3 linux-arm64（DSH 修复版）
#  上游:   https://github.com/Lixeer/ValleyServer  (Apache-2.0)
#  仓库:   https://github.com/deekoz2/ValleyServer-arm64
# ============================================================
set -u

G='\033[1;32m'; Y='\033[1;33m'; R='\033[1;31m'; B='\033[1;34m'; N='\033[0m'
say(){  printf "%b[✓]%b %s\n" "$G" "$N" "$*"; }
warn(){ printf "%b[!]%b %s\n" "$Y" "$N" "$*"; }
step(){ printf "\n%b===== %s =====%b\n" "$B" "$*" "$N"; }
die(){  printf "%b[✗]%b %s\n" "$R" "$N" "$*"; exit 1; }

REPO="https://github.com/deekoz2/ValleyServer-arm64"
TMOE_BOOT="https://l.tmoe.me"
TM_DIR="$HOME/.local/share/tmoe-linux"   # tmoe 容器根目录（Termux 侧）
APP_DIR="/opt/valleyserver"              # 服务器在容器内路径
PORT=24642                               # 服务器默认 UDP 端口

command -v pkg >/dev/null 2>&1 || die "请在 Termux / ZeroTermux 里运行本脚本"
[ "$(uname -m)" = "aarch64" ] || warn "本脚本面向 arm64 设备（当前 $(uname -m)），继续但可能失败"

DO_CONTAINER=1; DO_START=0; DO_EXTRACT=1
for a in "$@"; do
  case $a in
    --server) DO_CONTAINER=0 ;;
    --start)  DO_START=1 ;;
    --fix)    DO_CONTAINER=0; DO_EXTRACT=0 ;;
  esac
done

# ---------- 定位 tmoe 容器根文件系统（兼容 bash / sh / usr-merge 布局） ----------
find_rootfs(){
  local d
  for d in "$TM_DIR/containers/proot"/* "$TM_DIR/containers/chroot"/*; do
    if [ -x "$d/bin/bash" ] || [ -x "$d/usr/bin/bash" ] \
       || [ -x "$d/bin/sh" ] || [ -x "$d/usr/bin/sh" ]; then
      printf '%s\n' "$d"; return 0
    fi
  done
  return 1
}

# ========== 1/5 基础依赖 ==========
step "1/5 安装基础依赖"
apt update -y >/dev/null 2>&1 || warn "apt update 有报错，继续"
say "升级基础库（修复 libcurl/openssl 符号不匹配等部分升级问题，可能需几分钟）…"
DEBIAN_FRONTEND=noninteractive apt upgrade -y -o Dpkg::Options::=--force-confold >/dev/null 2>&1 \
  || warn "apt upgrade 有报错，继续"
pkg install -y curl proot tar xz-utils unzip pv aria2 openssl || warn "部分依赖安装失败，继续尝试"

# ========== 2/5 tmoe 容器 ==========
ROOTFS=""
if [ "$DO_CONTAINER" = 1 ]; then
  step "2/5 准备 tmoe proot 容器"
  if ROOTFS=$(find_rootfs); then
    say "检测到已有 tmoe 容器: $ROOTFS"
  else
    say "启动 tmoe 向导，请在菜单里选择: 新建容器 → Debian → arm64 → proot"
    say "（容器建好后退出 tmoe 菜单，本脚本会自动继续）"
    bash -c "$(curl -L $TMOE_BOOT)" || die "tmoe 安装被中断，请重新运行 install.sh"
    ROOTFS=$(find_rootfs) || die "未检测到 tmoe 容器，请重新运行 install.sh 并先在 tmoe 里创建容器"
    say "容器已就绪: $ROOTFS"
  fi
else
  step "2/5 定位已有容器"
  ROOTFS=$(find_rootfs) || die "未找到 tmoe 容器：请先完整运行一遍 install.sh 创建容器"
  say "使用容器: $ROOTFS"
fi

# ---------- 容器健康检查（shell + glibc） ----------
if ! { [ -x "$ROOTFS/bin/sh" ] || [ -x "$ROOTFS/usr/bin/sh" ] \
    || [ -x "$ROOTFS/bin/bash" ] || [ -x "$ROOTFS/usr/bin/bash" ]; }; then
  echo "✗ 容器里没有可用的 shell（rootfs 不完整）：$ROOTFS"
  echo "  请在 tmoe 里重装容器（推荐 Debian arm64）后重跑 install.sh"
  exit 1
fi
if [ ! -e "$ROOTFS/lib/ld-linux-aarch64.so.1" ] && [ ! -e "$ROOTFS/usr/lib/ld-linux-aarch64.so.1" ] \
   && [ ! -e "$ROOTFS/lib64/ld-linux-aarch64.so.1" ] && [ ! -e "$ROOTFS/usr/lib64/ld-linux-aarch64.so.1" ]; then
  warn "容器疑似 musl 系（如 Alpine）或缺 glibc —— ValleyServer（.NET）无法在其中运行"
  warn "强烈建议在 tmoe 里换 Debian / Ubuntu 容器"
fi

# ========== 3/5 下载服务器（镜像优先，自动切换） ==========
ASSET_FULL="https://github.com/deekoz2/ValleyServer-arm64/releases/download/v3.0.3-arm64-dsh/ValleyServer-linux-arm64.zip"
EXPECT_SIZE=469458959
ZIP="$HOME/valleyserver-dsh.zip"

# GitHub 加速镜像（按序尝试；空串 = 直连兜底；可自行增删/调整顺序）
MIRRORS=(
  "https://ghfast.top/"
  "https://gh-proxy.com/"
  "https://ghproxy.net/"
  ""
)

dl_one(){  # $1=完整URL
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x4 -s4 -k1M -c --allow-overwrite=true --timeout=20 --max-tries=2 --summary-interval=5 \
      -d "$(dirname "$ZIP")" -o "$(basename "$ZIP")" "$1"
  else
    curl -L -C - --retry 2 --connect-timeout 12 -o "$ZIP" "$1"
  fi
}

if [ "$DO_EXTRACT" = 1 ]; then
  step "3/5 下载 ValleyServer v3.0.3 linux-arm64（约 448MB，支持断点续传）"
  if [ -f "$ZIP" ] && [ "$(wc -c < "$ZIP" 2>/dev/null || echo 0)" = "$EXPECT_SIZE" ]; then
    say "已存在完整下载，跳过"
  else
    ok_dl=0
    for m in "${MIRRORS[@]}"; do
      if [ -z "$m" ]; then say "尝试直连 GitHub…"; else say "尝试镜像: $m …"; fi
      dl_one "${m}${ASSET_FULL}" || { warn "该源失败，切换下一个"; continue; }
      size=$(wc -c < "$ZIP" 2>/dev/null || echo 0)
      if [ "$size" = "$EXPECT_SIZE" ]; then
        ok_dl=1; say "下载校验通过（$size 字节）"; break
      fi
      warn "文件大小不符（$size != $EXPECT_SIZE），删除后换源重试"
      rm -f "$ZIP"
    done
    [ "$ok_dl" = 1 ] || die "所有下载源均失败：检查网络后重跑 install.sh（支持断点续传）"
  fi
  say "下载完成: $(du -h "$ZIP" 2>/dev/null | cut -f1)"
else
  step "3/5 跳过下载（--fix）"
fi

# ========== 4/5 部署到容器 + 生成启动脚本 ==========
step "4/5 部署与脚本生成"
mkdir -p "$ROOTFS$APP_DIR"

if [ "$DO_EXTRACT" = 1 ]; then
  command -v unzip >/dev/null 2>&1 || pkg install -y unzip || die "unzip 不可用"
  say "解压中（约 1-2 分钟，请耐心等待）…"
  rm -rf "${ROOTFS:?}$APP_DIR/ValleyServer-linux-arm64"
  unzip -oq "$ZIP" -d "$ROOTFS$APP_DIR" || die "解压失败，请重跑 install.sh"
  if [ -d "$ROOTFS$APP_DIR/ValleyServer-linux-arm64" ]; then
    mv "${ROOTFS:?}$APP_DIR/ValleyServer-linux-arm64/"* "$ROOTFS$APP_DIR/"
    rmdir "$ROOTFS$APP_DIR/ValleyServer-linux-arm64" 2>/dev/null
  fi
  [ -x "$ROOTFS$APP_DIR/ValleyServer" ] || die "解压后未找到 ValleyServer 可执行文件"
  chmod +x "$ROOTFS$APP_DIR/ValleyServer"
  [ -f "$ROOTFS$APP_DIR/patch-arm64.sh" ] && chmod +x "$ROOTFS$APP_DIR/patch-arm64.sh"
else
  [ -x "$ROOTFS$APP_DIR/ValleyServer" ] || die "--fix 需要已部署过的服务器，先完整跑一遍 install.sh"
fi

# 容器内启动脚本（POSIX sh，避免依赖 bash）
cat > "$ROOTFS$APP_DIR/run.sh" <<RUNEOF
#!/bin/sh
cd $APP_DIR || exit 1
[ -f patch-arm64.sh ] && sh patch-arm64.sh >/dev/null 2>&1
exec ./ValleyServer
RUNEOF
chmod +x "$ROOTFS$APP_DIR/run.sh"

# Termux 侧快捷命令 valley（运行时自适应 shell 与 rootfs，可自愈）
mkdir -p "$PREFIX/bin"
cat > "$PREFIX/bin/valley" <<VALEOF
#!$PREFIX/bin/sh
# 由 ValleyServer-arm64 install.sh 自动生成（v2）
ROOTFS="$ROOTFS"
APPDIR="$APP_DIR"
LOG="\$HOME/valley-server.log"
EXTRA=""
[ -d /sdcard ] && EXTRA="-b /sdcard"

# rootfs 自愈：失效时在 tmoe 容器目录重新定位
if [ ! -d "\$ROOTFS" ] || { [ ! -x "\$ROOTFS/bin/sh" ] && [ ! -x "\$ROOTFS/usr/bin/sh" ] \
  && [ ! -x "\$ROOTFS/bin/bash" ] && [ ! -x "\$ROOTFS/usr/bin/bash" ]; }; then
  for d in "\$HOME"/.local/share/tmoe-linux/containers/proot/* "\$HOME"/.local/share/tmoe-linux/containers/chroot/*; do
    if [ -x "\$d/bin/sh" ] || [ -x "\$d/usr/bin/sh" ] || [ -x "\$d/bin/bash" ]; then ROOTFS="\$d"; break; fi
  done
fi

# 选择容器内可用的 shell（兼容无 bash / usr-merge 布局）
if   [ -x "\$ROOTFS/bin/bash" ];     then SH="/bin/bash"
elif [ -x "\$ROOTFS/usr/bin/bash" ]; then SH="/usr/bin/bash"
elif [ -x "\$ROOTFS/bin/sh" ];       then SH="/bin/sh"
elif [ -x "\$ROOTFS/usr/bin/sh" ];   then SH="/usr/bin/sh"
else
  echo "✗ 容器里没有可用的 shell：\$ROOTFS"
  echo "  请在 tmoe 里重装容器（推荐 Debian arm64）后重跑 install.sh"
  exit 1
fi

# glibc 检查（.NET 运行时需要；Alpine/musl 跑不了）
if [ ! -e "\$ROOTFS/lib/ld-linux-aarch64.so.1" ] && [ ! -e "\$ROOTFS/usr/lib/ld-linux-aarch64.so.1" ] \
   && [ ! -e "\$ROOTFS/lib64/ld-linux-aarch64.so.1" ] && [ ! -e "\$ROOTFS/usr/lib64/ld-linux-aarch64.so.1" ]; then
  echo "✗ 容器缺少 glibc（musl 系如 Alpine 跑不了 .NET），请在 tmoe 里换 Debian/Ubuntu 容器"
  exit 1
fi

case "\$1" in
  start)
    nohup proot --link2symlink -0 -R "\$ROOTFS" \$EXTRA -w $APP_DIR \$SH run.sh > "\$LOG" 2>&1 &
    sleep 1
    echo "服务器已在后台启动（端口 $PORT/udp）"
    echo "日志: \$LOG   停止: valley stop   查看日志: valley log" ;;
  stop)
    if pkill -f "proot.*\$APPDIR"; then echo "已停止"; else echo "没有在运行的服务器"; fi ;;
  log)
    tail -n 40 "\$LOG" ;;
  ip)
    ip -4 addr 2>/dev/null | grep inet | grep -v 127.0.0.1 || echo "未获取到局域网 IP" ;;
  *)
    echo "进入前台模式，控制台可输入 help / save / stop 等；Ctrl+C 退出"
    proot --link2symlink -0 -R "\$ROOTFS" \$EXTRA -w $APP_DIR \$SH run.sh ;;
esac
VALEOF
chmod +x "$PREFIX/bin/valley"

# ========== 5/5 完成 ==========
step "5/5 完成！"
cat <<TIPS

  ${G}安装完成${N} —— 星露谷物语无头专用服务器已就绪

    启动      ${B}valley${N}            （前台运行，控制台输入 help 看指令）
    后台      ${B}valley start${N}     （日志 ~/valley-server.log）
    停止      ${B}valley stop${N}
    本机IP    ${B}valley ip${N}

    端口      UDP ${B}$PORT${N}（默认，首次启动会生成 config.json 可改）
    联机      好友在同一 Wi-Fi 下填  ${B}你的IP:$PORT${N}
              外网联机需要内网穿透（frp / Tailscale 等）

    首次启动较慢（生成地图数据），请耐心等待。
    服务器本体: Lixeer/ValleyServer v3.0.3 (Apache-2.0)

TIPS

if [ "$DO_START" = 1 ]; then
  say "按 --start 要求，后台启动服务器…"
  "$PREFIX/bin/valley" start
fi
