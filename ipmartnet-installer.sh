#!/usr/bin/env bash
set -Eeuo pipefail

#####################################
# iPmartnet Ultimate Installer
# install | update | uninstall
#####################################

PROJECT="ipmartnet"
INSTALL_DIR="/opt/ipmartnet"
BIN_DIR="$INSTALL_DIR/bin"
CONFIG_DIR="$INSTALL_DIR/config"
LOG_DIR="/var/log/ipmartnet"
SERVICE_FILE="/etc/systemd/system/ipmartnet.service"

GITHUB_REPO="YOUR_GITHUB_USERNAME/iPmartnet"
VERSION="latest"

LOG_FILE="$LOG_DIR/installer.log"

#####################################
# Utils
#####################################

log() { echo -e "[iPmartnet] $1" | tee -a "$LOG_FILE"; }
die() { log "❌ $1"; exit 1; }

require_root() {
  [[ $EUID -eq 0 ]] || die "Run as root"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

#####################################
# Detect OS / Arch
#####################################

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

#####################################
# Dependencies
#####################################

install_deps() {
  log "Installing dependencies..."
  case "$OS" in
    ubuntu|debian)
      apt update
      apt install -y curl wget tar ca-certificates iproute2 lsof
      ;;
    centos|rhel|rocky|almalinux)
      yum install -y curl wget tar ca-certificates iproute lsof
      ;;
    *)
      die "Unsupported OS: $OS"
      ;;
  esac
}

check_systemd() {
  command_exists systemctl || die "systemd not found"
}

#####################################
# Network Checks
#####################################

check_port_free() {
  local port="$1"
  if lsof -i ":$port" >/dev/null 2>&1; then
    die "Port $port is already in use"
  fi
}

apply_sysctl() {
  log "Applying network optimizations..."
  sysctl -w net.core.rmem_max=2500000
  sysctl -w net.core.wmem_max=2500000
  sysctl -w net.ipv4.tcp_fastopen=3
}

#####################################
# Directories
#####################################

prepare_dirs() {
  mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$LOG_DIR"
}

#####################################
# Download & Verify
#####################################

download_binary() {
  log "Downloading binary..."
  URL="https://github.com/$GITHUB_REPO/releases/$VERSION/download/ipmartnet-linux-$ARCH"
  curl -fL "$URL" -o "$BIN_DIR/ipmartnet" || die "Download failed"
  chmod +x "$BIN_DIR/ipmartnet"
}

#####################################
# User Input
#####################################

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
    read -rp "Listen port [443]: " PORT
    PORT=${PORT:-443}
    check_port_free "$PORT"
    LISTEN="0.0.0.0:$PORT"
  else
    read -rp "Connect address (IP:PORT): " CONNECT
    [[ -z "$CONNECT" ]] && die "Connect address required"
  fi
}

warn_special_protocols() {
  if [[ "$PROTO" == "icmp" || "$PROTO" == "faketcp" ]]; then
    log "⚠️ $PROTO requires external system tunnel (not bundled)"
  fi
}

#####################################
# Config & Service
#####################################

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

#####################################
# Actions
#####################################

install_ipmartnet() {
  require_root
  detect_os
  detect_arch
  install_deps
  check_systemd
  prepare_dirs

  select_role
  select_protocol
  read_addresses
  warn_special_protocols

  apply_sysctl
  download_binary
  write_config
  write_service
  enable_service

  log "✅ iPmartnet installed successfully"
}

update_ipmartnet() {
  require_root
  log "Updating iPmartnet..."
  systemctl stop ipmartnet || true
  download_binary
  systemctl start ipmartnet
  log "✅ Update completed"
}

uninstall_ipmartnet() {
  require_root
  log "Uninstalling iPmartnet..."
  systemctl stop ipmartnet || true
  systemctl disable ipmartnet || true
  rm -f "$SERVICE_FILE"
  rm -rf "$INSTALL_DIR" "$LOG_DIR"
  systemctl daemon-reload
  log "✅ iPmartnet removed"
}

#####################################
# Entry
#####################################

ACTION="${1:-install}"

case "$ACTION" in
  install) install_ipmartnet ;;
  update) update_ipmartnet ;;
  uninstall) uninstall_ipmartnet ;;
  *)
    echo "Usage: $0 {install|update|uninstall}"
    exit 1
    ;;
esac
