#!/usr/bin/env bash
#
# setup-evilginx.sh
#---------------------------------------------------------------------------
# Author: Jesus Menjivar
# GitHub: https://github.com/JesusEMenjivar
# Created: 2025-12-12
# Last Updated: 2025-12-12
# Version: 1.0
# ---------------------------------------------------------------------------
# Description:
#   Automates initial Evilginx deployment on a fresh Ubuntu/Debian VPS:
#
#     • Installs system dependencies (wget, unzip, expect)
#     • Creates a working directory
#     • Downloads the Evilginx release from GitHub
#     • Extracts and verifies the binary
#     • Performs a DNS A-record check
#     • Prints post-install configuration instructions
#
# Usage:
#     ./setup-evilginx.sh <domain> <public_ipv4>
#
# Example:
#     ./setup-evilginx.sh quantalyx-industries.cam 203.0.113.10
#
# Notes:
#   • Supports Debian/Ubuntu (apt-based) systems only.
#   • No interactive prompts; arguments must be provided.
# ---------------------------------------------------------------------------

set -euo pipefail


# ╔══════════════════════════════════════════════════════════════════════╗
# ║ CONFIGURABLE DEFAULTS                                                ║
# ╚══════════════════════════════════════════════════════════════════════╝

EVILGINX_DIR="$HOME/evilginx"

EVILGINX_VERSION="v3.3.0"
EVILGINX_ZIP="evilginx-${EVILGINX_VERSION}-linux-64bit.zip"
EVILGINX_URL="https://github.com/kgretzky/evilginx2/releases/download/${EVILGINX_VERSION}/${EVILGINX_ZIP}"


# ╔══════════════════════════════════════════════════════════════════════╗
# ║ FUNCTIONS                                                            ║
# ╚══════════════════════════════════════════════════════════════════════╝

error() {
  echo "[!] $*" >&2
  exit 1
}

info() {
  echo "[+] $*"
}

check_dns() {
  echo
  echo "─── DNS CHECK ───────────────────────────────────────────────"
  info "Checking DNS A record for: $DOMAIN"
  echo

  if ! command -v dig >/dev/null 2>&1; then
    info "'dig' not found — installing dnsutils ..."
    echo
    $SUDO apt-get install -y dnsutils
  fi

  DNS_IP="$(dig +short "$DOMAIN" A | tail -n1)"

  if [[ -z "$DNS_IP" ]]; then
    echo "[!] No DNS A record found for $DOMAIN"
    echo
    return 1
  fi

  echo "[+] DNS A record resolves to: $DNS_IP"

  if [[ "$DNS_IP" == "$PUBLIC_IP" ]]; then
    echo "[✓] DNS is correctly pointing to your VPS IP."
  else
    echo "[!] DNS mismatch detected!"
    echo "    Expected: $PUBLIC_IP"
    echo "    Got:      $DNS_IP"
  fi

  echo "────────────────────────────────────────────────────────────"
  echo
}


# ╔══════════════════════════════════════════════════════════════════════╗
# ║ ARGUMENT VALIDATION                                                  ║
# ╚══════════════════════════════════════════════════════════════════════╝

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <domain> <public_ipv4>"
  exit 1
fi

DOMAIN="$1"
PUBLIC_IP="$2"


# ╔══════════════════════════════════════════════════════════════════════╗
# ║ SYSTEM SANITY CHECKS                                                 ║
# ╚══════════════════════════════════════════════════════════════════════╝

# Ensure apt exists
if ! command -v apt-get >/dev/null 2>&1; then
  error "This script supports apt-based systems only."
fi

# Determine sudo usage
if [[ $EUID -ne 0 ]]; then
  info "Non-root user detected — sudo will be used."
  SUDO="sudo"
else
  SUDO=""
fi

# ╔══════════════════════════════════════════════════════════════════════╗
# ║ SYSTEM PREPARATION                                                   ║
# ╚══════════════════════════════════════════════════════════════════════╝

echo
echo "─── SYSTEM PREPARATION ──────────────────────────────────────"
info "Updating package lists ..."
echo
$SUDO apt-get update -y

info "Installing required packages (wget, unzip) ..."
echo
$SUDO apt-get install -y wget unzip
echo "────────────────────────────────────────────────────────────"
echo


# ╔══════════════════════════════════════════════════════════════════════╗
# ║ DIRECTORY SETUP                                                      ║
# ╚══════════════════════════════════════════════════════════════════════╝

echo "─── DIRECTORY SETUP ─────────────────────────────────────────"
info "Creating working directory at: $EVILGINX_DIR"
mkdir -p "$EVILGINX_DIR"
cd "$EVILGINX_DIR"
echo "────────────────────────────────────────────────────────────"
echo


# ╔══════════════════════════════════════════════════════════════════════╗
# ║ DOWNLOAD & EXTRACTION                                                ║
# ╚══════════════════════════════════════════════════════════════════════╝

echo "─── DOWNLOAD & INSTALL ───────────────────────────────────────"

if [[ -f "$EVILGINX_ZIP" ]]; then
  info "Existing archive found — using $EVILGINX_ZIP"
else
  info "Downloading Evilginx release:"
  echo "    $EVILGINX_URL"
  echo

  if ! wget -q "$EVILGINX_URL" -O "$EVILGINX_ZIP"; then
    error "Failed to download Evilginx."
  fi

  info "Download complete."
fi

echo
info "Extracting archive ..."
unzip -o "$EVILGINX_ZIP" >/dev/null

if [[ ! -f "./evilginx" ]]; then
  error "Evilginx binary missing after extraction."
fi

info "Applying execute permissions ..."
chmod +x ./evilginx

info "Verifying binary functionality ..."
./evilginx -h >/dev/null 2>&1 || error "Binary failed to run."
echo "────────────────────────────────────────────────────────────"
echo


# ╔══════════════════════════════════════════════════════════════════════╗
# ║ DNS VALIDATION                                                       ║
# ╚══════════════════════════════════════════════════════════════════════╝

check_dns


# ╔══════════════════════════════════════════════════════════════════════╗
# ║ POST-INSTALL SUMMARY                                                 ║
# ╚══════════════════════════════════════════════════════════════════════╝

cat <<EOF

─── INSTALLATION COMPLETE ──────────────────────────────────────────────

Before continuing, ensure the following:

  • Firewall:
        Open ports 80 and 443 on your VPS + cloud firewall.

──────────────────────────────────────────────────────────────────────────

EOF


# ╔══════════════════════════════════════════════════════════════════════╗
# ║ AUTOMATED INTERACTION                                                ║
# ╚══════════════════════════════════════════════════════════════════════╝

./evilginx <<EOF
config domain $DOMAIN
config ipv4 external $PUBLIC_IP
EOF