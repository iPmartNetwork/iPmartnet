#!/usr/bin/env bash
set -Eeuo pipefail

########################################
# iPmartnet Ultimate Installer
# install | update | uninstall
# Release Binary -> Fallback to Source
########################################

PROJECT="ipmartnet"

INSTALL_DIR="/opt/ipmartnet"
BIN_DIR="$INSTALL_DIR/bin"
SRC_DIR="$INSTALL_DIR/src"
CONFIG_DIR="$INSTALL_DIR/config"

LOG_DIR="/var/log/ipmartnet"
LOG_FILE="$LOG_DIR/installer.log"

SERVICE_FILE="/etc/systemd/system/ipmartnet.service"

GITHUB_REPO="iPmartNetwork/iPmartnet"
REPO_URL="https://github.com/iPmartNetwork/iPmartnet.git"

GO_VERSION="1.21.6"

########################################
# Prepare logging early
########################################

mkdir -p "$LOG_DIR"

log() { echo "[iPmartnet] $1" | tee -a "$LOG_FILE"; }
die() { log "❌ ERROR: $1"; exit 1; }

########################################
# Root & utils
########################################

require_root() {
  [[ $EUID -eq 0 ]] || die "Run as root"
}

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

########################################
# Detect OS / Arch
########################################

detect_os() {
  [[ -f /etc/os-release ]] || die "Cannot detect OS"
  . /etc/os-release
  OS=$ID
}

detect_arch() {
  case "$(uname -m)" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *) die "Unsupported architecture" ;;
  esac
}

########################################
# Dependencies
########################################

install_deps() {
  log "Installing system dependencies..."
  case "$OS" in
    ubuntu|debian)
      apt update
      apt install -y curl wget tar git ca-certificates iproute2 lsof
      ;;
    centos|rhel|rocky|almalinux)
      yum install -y curl wget tar git ca-certificates iproute lsof
      ;;
    *)
      die "Unsupported OS: $OS"
      ;;
  esac
}

########################################
# Go install (only if needed)
########################################

install_go() {
  if cmd_exists go; then
    log "Go already installed"
    return
  fi

  log "Installing Go $GO_VERSION..."
  local ARCH_GO
  case "$ARCH" in
    amd64) ARCH_GO="amd64" ;;
    arm64) ARCH_GO="arm64" ;;
  esac

  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH_GO}.tar.gz" -o /tmp/go.tgz
  rm -rf /usr/local/go
  tar -C /usr/local -xzf /tmp/go.tgz
  export PATH=$PATH:/usr/local/go/bin
}

########################################
# Network checks
########################################

check_port_free() {
  local port="$1"
  lsof -i ":$port" >/dev/null 2>&1 && die "Port $port already in use"
}

apply_sysctl() {
  log "Applying network optimizations..."
  sysctl -w net.core.rmem_max=2500000 >/dev/null
  sysctl -w net.core.wmem_max=2500000 >/dev/null
  sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null
}

########################################
# Prepare dirs
########################################

prepare_dirs() {
  mkdir -p "$BIN_DIR" "$SRC_DIR" "$CONFIG_DIR"
}

########################################
# Install methods
########################################

download_binary() {
  local URL="https://github.com/${GITHUB_REPO}/releases/latest/download/ipmartnet-linux-${ARCH}"
  log "Trying release binary: $URL"

  if curl -fL --ipv4 "$URL" -o "$BIN_DIR/ipmartnet"; then
    chmod +x "$BIN_DIR/ipmartnet"
    log "Installed from GitHub Release"
    return 0
  fi
  return 1
}

clone_and_build() {
  log "Fallback: building from source"

  install_go

  rm -rf "$SRC_DIR"
  git clone --depth=1 "$REPO_URL" "$SRC_DIR" || die "Git clone failed"

  cd "$SRC_DIR"
  export CGO_ENABLED=0 GOOS=linux GOARCH="$ARCH"
  go build -o "$BIN_DIR/ipmartnet" ./cmd/ipmartnet || die "Build failed"
  chmod +x "$BIN_DIR/ipmartnet"

  log "Built iPmartnet from source"
}

install_ipmartnet() {
  download_binary || clone_and_build
}

########################################
# User input (interactive)
########################################

select_role() {
  echo "Select role:"
  select ROLE in "iran (client)" "outside (server)"; do
    case $REPLY in
      1) ROLE="iran"; break ;;
      2) ROLE="outside"; break ;;
    esac
  done
}

select_protocol() {
  echo "Select protocol:"
  select PROTO in tcp udp quic kcp icmp faketcp; do
    [[ -n "$PROTO" ]] && break
  done
}

read_addresses() {
  if [[ "$ROLE" == "outside" ]]; then
    read -rp "Listen port [8443]: " PORT
    PORT=${PORT:-8443}
    check_port_free "$PORT"
    LISTEN="0.0.0.0:$PORT"
    CONNECT=""
  else
    read -rp "Connect address (IP:PORT): " CONNECT
    [[ -z "$CONNECT" ]] && die "Connect address required"
    LISTEN=""
  fi
}

########################################
# Config & systemd
########################################

write_config() {
  cat > "$CONFIG_DIR/config.env" <<EOF
ROLE=$ROLE
PROTO=$PROTO
LISTEN=$LISTEN
CONNECT=$CONNECT
EOF
}

write_service() {
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=iPmartnet Secure Reverse Tunnel
After=network.target

[Service]
Type=simple
EnvironmentFile=$CONFIG_DIR/config.env
ExecStart=$BIN_DIR/ipmartnet \\
  --role=\$ROLE \\
  --proto=\$PROTO \\
  ${LISTEN:+--listen=\$LISTEN} \\
  ${CONNECT:+--connect=\$CONNECT}
Restart=always
RestartSec=3
LimitNOFILE=1048576
StandardOutput=append:$LOG_DIR/runtime.log
StandardError=append:$LOG_DIR/runtime.log

[Install]
WantedBy=multi-user.target
EOF
}

enable_service() {
  systemctl daemon-reload
  systemctl enable ipmartnet
  systemctl restart ipmartnet
}

########################################
# Actions
########################################

action_install() {
  require_root
  detect_os
  detect_arch
  install_deps
  prepare_dirs

  select_role
  select_protocol
  read_addresses

  apply_sysctl
  install_ipmartnet
  write_config
  write_service
  enable_service

  log "✅ iPmartnet installed successfully"
}

action_update() {
  require_root
  detect_arch
  log "Updating iPmartnet..."
  systemctl stop ipmartnet || true
  install_ipmartnet
  systemctl start ipmartnet
  log "✅ Update completed"
}

action_uninstall() {
  require_root
  log "Uninstalling iPmartnet..."
  systemctl stop ipmartnet || true
  systemctl disable ipmartnet || true
  rm -f "$SERVICE_FILE"
  rm -rf "$INSTALL_DIR" "$LOG_DIR"
  systemctl daemon-reload
  log "✅ Removed"
}

########################################
# Entry
########################################

ACTION="${1:-install}"

case "$ACTION" in
  install) action_install ;;
  update) action_update ;;
  uninstall) action_uninstall ;;
  *)
    echo "Usage: $0 {install|update|uninstall}"
    exit 1
    ;;
esac
