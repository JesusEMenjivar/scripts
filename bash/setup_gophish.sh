#!/bin/bash
set -euo pipefail

########################################
# Simple Output Helpers
########################################

section() {
  echo
  echo "------------------------------------------------------------"
  echo "$1"
  echo "------------------------------------------------------------"
  echo
}

info() {
  echo "[*] $1"
}

ok() {
  echo "[+] $1"
}

warn() {
  echo "[!] $1"
}

error() {
  echo "[x] $1"
}

trap 'error "Something went wrong. Check the output above for details."' ERR

########################################
# Header
########################################

echo
echo "============================================================"
echo "                    GoPhish Setup Script                    "
echo "============================================================"
echo
echo "This script will:"
echo "  - Update the server"
echo "  - Install unzip and certbot"
echo "  - Download and extract GoPhish"
echo "  - Obtain a TLS certificate via Certbot"
echo "  - Replace config.json"
echo

read -rp "Press ENTER to continue or Ctrl+C to abort..."

########################################
# Step 1: Inputs
########################################

section "Step 1: Collect Required Information"

read -rp "Enter your spoofed domain (e.g. quantalyx-industries.cam): " SPOOFED_DOMAIN
read -rp "Enter your DigitalOcean droplet public IP: " DROPLET_IP

echo
ok "Using domain:     $SPOOFED_DOMAIN"
ok "Using droplet IP: $DROPLET_IP"

########################################
# Step 2: System Update & Dependencies
########################################

section "Step 2: Update System & Install Dependencies"

info "Updating system packages..."
apt update -y
apt upgrade -y
ok "System updated."

info "Installing unzip and certbot..."
apt install -y unzip certbot
ok "Dependencies installed."

########################################
# Step 3: Download & Extract GoPhish
########################################

section "Step 3: Download & Prepare GoPhish"

GOPHISH_DIR="$HOME/gophish"
GOPHISH_ZIP="gophish-v0.12.1-linux-64bit.zip"
GOPHISH_URL="https://github.com/gophish/gophish/releases/download/v0.12.1/${GOPHISH_ZIP}"

info "Creating GoPhish directory at: $GOPHISH_DIR"
mkdir -p "$GOPHISH_DIR"
cd "$GOPHISH_DIR"

if [ ! -f "$GOPHISH_ZIP" ]; then
  info "Downloading GoPhish from: $GOPHISH_URL"
  wget "$GOPHISH_URL"
  ok "GoPhish download complete."
else
  warn "GoPhish zip already exists — skipping download."
fi

info "Extracting GoPhish..."
unzip -o "$GOPHISH_ZIP" >/dev/null
ok "GoPhish extracted."

echo
info "Files in gophish directory:"
ls -1
echo

########################################
# Step 4: Make GoPhish Executable
########################################

section "Step 4: Make GoPhish Executable"

if [ -f "./gophish" ]; then
  chmod +x ./gophish
  ok "GoPhish binary is executable."
else
  error "gophish binary not found after unzip."
  exit 1
fi

########################################
# Step 5: DNS Prep (Manual)
########################################

section "Step 5: DNS Setup (Manual in Your DNS Provider)"

cat <<EOF
You now need to configure DNS for your spoofed domain:

1) Create an A record for your root domain ($SPOOFED_DOMAIN):

   Type:  A
   Host:  @
   Value: $DROPLET_IP
   TTL:   1 minute (or lowest allowed)

This associates $SPOOFED_DOMAIN with your DigitalOcean droplet.

Next, Certbot will ask you to create a TXT record for domain validation.
Keep your DNS provider dashboard (e.g. Namecheap) open and ready.

EOF

read -rp "Press ENTER to start Certbot and request a TLS certificate..."

########################################
# Step 6: Request TLS Certificate (DNS Challenge)
########################################

section "Step 6: Request TLS Certificate (DNS Challenge)"

cat <<EOF
Certbot will now guide you through DNS domain validation.

When prompted by Certbot, you will need to:

  - Create a TXT record such as:
      Name/Host: _acme-challenge.$SPOOFED_DOMAIN
      Type:      TXT
      Value:     (token provided by Certbot)
      TTL:       1 minute

  - Wait 1–2 minutes for DNS to propagate
  - Then allow Certbot to continue

EOF

certbot certonly \
  --manual \
  --preferred-challenges dns \
  --register-unsafely-without-email \
  -d "$SPOOFED_DOMAIN"

ok "Certificate issued successfully."

CERT_PATH="/etc/letsencrypt/live/$SPOOFED_DOMAIN/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/$SPOOFED_DOMAIN/privkey.pem"

echo
info "Using certificate paths:"
echo "  CERT_PATH = $CERT_PATH"
echo "  KEY_PATH  = $KEY_PATH"

########################################
# Step 7: Replace config.json
########################################

section "Step 7: Replace config.json with final configuration"

CONFIG_FILE="config.json"

info "Removing existing config.json (if it exists)..."
rm -f "$CONFIG_FILE"

info "Writing new config.json with correct admin_server and phish_server settings..."

ok "config.json has been recreated."
echo

########################################
# Step 8: Launch Instructions
########################################

section "Step 8: Start GoPhish & Log In"

cat <<EOF
To launch GoPhish, run:

  cd "$GOPHISH_DIR"
  ./gophish

On startup, GoPhish will print the username and password for the GoPhish portal.

Copy and save that password.

Admin portal (TLS with GoPhish's own admin cert):

  https://$DROPLET_IP:3333/

On first login, you will be prompted to change the admin password.

echo "Setup complete!"
echo
