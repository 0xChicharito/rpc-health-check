#!/bin/bash

# RPC Health Check - Simple Installer
# Version: 2.0

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
INSTALL_DIR="${INSTALL_DIR:-$HOME/rpc-health-check}"
REPO_URL="https://raw.githubusercontent.com/0xChicharito/rpc-health-check/main"

echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  RPC Health Check - Auto Installer${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""

# Create directory
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
echo -e "${GREEN}✓${NC} Directory: $INSTALL_DIR"
echo ""

# Download files
echo "Downloading files from GitHub..."
echo ""

FILES=(
    "rpc_health_check.sh"
    "setup_cron.sh"
    ".env.example"
)

DOWNLOAD_SUCCESS=0
DOWNLOAD_FAILED=0

for file in "${FILES[@]}"; do
    echo -n "  Downloading $file ... "
    if curl -fsSL "$REPO_URL/$file" -o "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        DOWNLOAD_SUCCESS=$((DOWNLOAD_SUCCESS + 1))
    else
        echo -e "${RED}✗${NC}"
        DOWNLOAD_FAILED=$((DOWNLOAD_FAILED + 1))
    fi
done

echo ""

if [ $DOWNLOAD_FAILED -gt 0 ]; then
    echo -e "${RED}✗ Failed to download $DOWNLOAD_FAILED file(s)${NC}"
    echo ""
    echo "Possible reasons:"
    echo "  1. Files not yet uploaded to GitHub repository"
    echo "  2. Repository URL is incorrect"
    echo "  3. Network connection issues"
    echo ""
    echo "Please verify files exist at:"
    echo "  $REPO_URL"
    echo ""
    echo "Manual installation:"
    echo "  cd $INSTALL_DIR"
    echo "  # Download files manually or copy them here"
    exit 1
fi

echo -e "${GREEN}✓${NC} All files downloaded successfully"
echo ""

# Set permissions
echo "Setting permissions..."
chmod +x rpc_health_check.sh 2>/dev/null || true
chmod +x setup_cron.sh 2>/dev/null || true
echo -e "${GREEN}✓${NC} Permissions set"
echo ""

# Setup .env
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓${NC} Created .env from .env.example"
    else
        echo "Creating .env template..."
        cat > .env << 'ENVEOF'
ETHEREUM_RPC_URL=https://xxxxxx.node9x.com
CONSENSUS_BEACON_URL=https://xxxxxxxx.node9x.com
VALIDATOR_PRIVATE_KEYS=0x54b9da85b2b61d67b3xxxxxxxxxxxxxx
COINBASE=0x7d5CB4553167F3cca419832dxxxxx
P2P_IP=148.251.66.35

# Backup RPC URLs (comma-separated, required)
BACKUP_ETHEREUM_RPCS=https://eth.llamarpc.com,https://rpc.ankr.com/eth,https://eth.drpc.org,https://ethereum.publicnode.com

# Backup Beacon URLs (comma-separated, required)
BACKUP_BEACON_URLS=https://ethereum-beacon-api.publicnode.com,https://beaconstate.ethstaker.cc

# Telegram Notification (Optional)
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
ENVEOF
        echo -e "${GREEN}✓${NC} Created .env template"
    fi
    chmod 600 .env
else
    echo -e "${YELLOW}⚠${NC} .env already exists, keeping current version"
fi
echo ""

# Success
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation Complete! 🎉${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo "Installation directory: $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit configuration:"
echo "     nano $INSTALL_DIR/.env"
echo ""
echo "  2. Run test:"
echo "     cd $INSTALL_DIR && ./rpc_health_check.sh"
echo ""
echo "  3. Setup automatic monitoring:"
echo "     cd $INSTALL_DIR && ./setup_cron.sh"
echo ""
echo "Quick start:"
echo "  cd $INSTALL_DIR"
echo "  nano .env          # Configure your RPCs"
echo "  ./setup_cron.sh    # Setup auto-monitoring"
echo ""
