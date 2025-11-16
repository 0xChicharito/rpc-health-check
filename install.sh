#!/bin/bash

# Auto Install Script for RPC Health Check
# This script will automatically install and configure the RPC health monitoring system

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="${INSTALL_DIR:-$HOME/rpc-health-check}"
REPO_URL="https://raw.githubusercontent.com/0xChicharito/rpc-health-check/main"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   RPC Health Check - Auto Installer                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_warning "Please do not run this script as root"
    exit 1
fi

# Check required commands
echo "Checking system requirements..."
REQUIRED_COMMANDS=("curl" "grep" "sed")
MISSING_COMMANDS=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_COMMANDS+=("$cmd")
    fi
done

if [ ${#MISSING_COMMANDS[@]} -gt 0 ]; then
    print_error "Missing required commands: ${MISSING_COMMANDS[*]}"
    print_info "Please install missing commands and try again"
    exit 1
fi

print_success "All required commands found"
echo ""

# Create installation directory
echo "Setting up installation directory..."
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Directory $INSTALL_DIR already exists"
    read -p "Do you want to overwrite? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    # Backup existing directory
    if [ -f "$INSTALL_DIR/.env" ]; then
        print_info "Backing up existing .env file..."
        cp "$INSTALL_DIR/.env" "$INSTALL_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)"
        print_success ".env file backed up"
    fi
else
    mkdir -p "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
print_success "Installation directory: $INSTALL_DIR"
echo ""

# Download files (if using GitHub)
# Uncomment these lines when you upload to GitHub
# echo "Downloading files from GitHub..."
# curl -sSL "$REPO_URL/rpc_health_check.sh" -o rpc_health_check.sh
# curl -sSL "$REPO_URL/setup_cron.sh" -o setup_cron.sh
# curl -sSL "$REPO_URL/.env.example" -o .env.example
# print_success "Files downloaded"
# echo ""

# For local installation (copy from current directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/rpc_health_check.sh" ]; then
    print_info "Copying files from local directory..."
    cp "$SCRIPT_DIR/rpc_health_check.sh" .
    cp "$SCRIPT_DIR/setup_cron.sh" .
    if [ -f "$SCRIPT_DIR/.env" ]; then
        if [ ! -f ".env" ]; then
            cp "$SCRIPT_DIR/.env" .env.example
        fi
    fi
    print_success "Files copied"
else
    print_error "Source files not found in $SCRIPT_DIR"
    print_info "Please ensure you're running this script from the correct directory"
    exit 1
fi

echo ""

# Set permissions
echo "Setting file permissions..."
chmod +x rpc_health_check.sh
chmod +x setup_cron.sh
print_success "Permissions set"
echo ""

# Configure .env file
echo "Configuring environment..."
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_success "Created .env file from example"
    else
        print_warning ".env file not found, creating template..."
        cat > .env << 'EOF'
ETHEREUM_RPC_URL=https://rpc-eth.node9x.com
CONSENSUS_BEACON_URL=https://beacon-eth.node9x.com
VALIDATOR_PRIVATE_KEYS=0x54b9da85b2b61d67b347e9c26fbd4b99a07ee02cf575fd746572d6a89d633f95
COINBASE=0x7d5CB4553167F3cca419832d0C69e04DC80C8479
P2P_IP=148.251.66.35

# Backup RPC URLs (comma-separated, required)
BACKUP_ETHEREUM_RPCS=https://eth.llamarpc.com,https://rpc.ankr.com/eth,https://eth.drpc.org,https://ethereum.publicnode.com

# Backup Beacon URLs (comma-separated, required)
BACKUP_BEACON_URLS=https://ethereum-beacon-api.publicnode.com,https://beaconstate.ethstaker.cc

# Telegram Notification (Optional)
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
EOF
        print_success "Created .env template"
    fi
else
    print_info ".env file already exists, skipping..."
fi

chmod 600 .env
print_success ".env file permissions set to 600"
echo ""

# Interactive configuration
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   Interactive Configuration${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo ""

read -p "Do you want to configure settings now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # RPC URLs
    echo ""
    print_info "Current Ethereum RPC: $(grep "^ETHEREUM_RPC_URL=" .env | cut -d '=' -f2)"
    read -p "Enter new Ethereum RPC URL (or press Enter to keep current): " eth_rpc
    if [ -n "$eth_rpc" ]; then
        sed -i "s|^ETHEREUM_RPC_URL=.*|ETHEREUM_RPC_URL=$eth_rpc|" .env
        print_success "Ethereum RPC updated"
    fi
    
    echo ""
    print_info "Current Beacon URL: $(grep "^CONSENSUS_BEACON_URL=" .env | cut -d '=' -f2)"
    read -p "Enter new Beacon URL (or press Enter to keep current): " beacon_url
    if [ -n "$beacon_url" ]; then
        sed -i "s|^CONSENSUS_BEACON_URL=.*|CONSENSUS_BEACON_URL=$beacon_url|" .env
        print_success "Beacon URL updated"
    fi
    
    # Backup RPCs
    echo ""
    print_info "Current backup Ethereum RPCs: $(grep "^BACKUP_ETHEREUM_RPCS=" .env | cut -d '=' -f2)"
    read -p "Enter backup Ethereum RPCs (comma-separated) or press Enter to keep current: " backup_eth
    if [ -n "$backup_eth" ]; then
        sed -i "s|^BACKUP_ETHEREUM_RPCS=.*|BACKUP_ETHEREUM_RPCS=$backup_eth|" .env
        print_success "Backup Ethereum RPCs updated"
    fi
    
    echo ""
    print_info "Current backup Beacon URLs: $(grep "^BACKUP_BEACON_URLS=" .env | cut -d '=' -f2)"
    read -p "Enter backup Beacon URLs (comma-separated) or press Enter to keep current: " backup_beacon
    if [ -n "$backup_beacon" ]; then
        sed -i "s|^BACKUP_BEACON_URLS=.*|BACKUP_BEACON_URLS=$backup_beacon|" .env
        print_success "Backup Beacon URLs updated"
    fi
    
    # Telegram configuration
    echo ""
    read -p "Do you want to set up Telegram notifications? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter Telegram Bot Token: " bot_token
        read -p "Enter Telegram Chat ID: " chat_id
        
        if [ -n "$bot_token" ] && [ -n "$chat_id" ]; then
            sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$bot_token|" .env
            sed -i "s|^TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=$chat_id|" .env
            print_success "Telegram configuration updated"
            
            # Test Telegram
            echo ""
            read -p "Do you want to test Telegram notification now? (y/n): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                test_msg="✅ RPC Health Check Monitor installed successfully!"
                response=$(curl -s -X POST \
                    "https://api.telegram.org/bot${bot_token}/sendMessage" \
                    -d chat_id="${chat_id}" \
                    -d text="${test_msg}")
                
                if echo "$response" | grep -q '"ok":true'; then
                    print_success "Telegram test message sent successfully!"
                else
                    print_error "Failed to send Telegram test message"
                    print_info "Please check your bot token and chat ID"
                fi
            fi
        fi
    fi
fi

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   Cron Job Setup${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo ""

read -p "Do you want to set up automatic monitoring (cron job)? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Select check frequency:"
    echo "  1) Every 5 minutes (recommended)"
    echo "  2) Every 10 minutes"
    echo "  3) Every 15 minutes"
    echo "  4) Every 30 minutes"
    echo "  5) Every hour"
    read -p "Enter choice (1-5): " -n 1 -r
    echo ""
    
    case $REPLY in
        1) CRON_SCHEDULE="*/5 * * * *" ;;
        2) CRON_SCHEDULE="*/10 * * * *" ;;
        3) CRON_SCHEDULE="*/15 * * * *" ;;
        4) CRON_SCHEDULE="*/30 * * * *" ;;
        5) CRON_SCHEDULE="0 * * * *" ;;
        *) CRON_SCHEDULE="*/5 * * * *" ;;
    esac
    
    # Update setup_cron.sh with selected schedule
    sed -i "s|^CRON_SCHEDULE=.*|CRON_SCHEDULE=\"$CRON_SCHEDULE\"|" setup_cron.sh
    
    # Run cron setup
    ./setup_cron.sh
    
    print_success "Cron job configured"
else
    print_info "Skipping cron job setup"
    print_info "You can set it up later by running: ./setup_cron.sh"
fi

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   Testing Installation${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo ""

read -p "Do you want to run a test check now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    print_info "Running health check..."
    echo "─────────────────────────────────────────────────────"
    ./rpc_health_check.sh
    echo "─────────────────────────────────────────────────────"
    echo ""
fi

# Installation complete
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Installation Completed Successfully! 🎉             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}Installation Directory:${NC} $INSTALL_DIR"
echo ""
echo -e "${BLUE}Quick Commands:${NC}"
echo "  • Run manual check:     cd $INSTALL_DIR && ./rpc_health_check.sh"
echo "  • View logs:            tail -f $INSTALL_DIR/rpc_health_check.log"
echo "  • Edit configuration:   nano $INSTALL_DIR/.env"
echo "  • View cron jobs:       crontab -l"
echo "  • Setup cron:           cd $INSTALL_DIR && ./setup_cron.sh"
echo ""
echo -e "${BLUE}Files Created:${NC}"
echo "  • rpc_health_check.sh   - Main monitoring script"
echo "  • setup_cron.sh         - Cron job setup script"
echo "  • .env                  - Configuration file"
echo "  • .original_rpc         - Original RPC backup (auto-created)"
echo "  • rpc_health_check.log  - Log file (auto-created)"
echo ""

if [ -n "$(grep "^TELEGRAM_BOT_TOKEN=" .env | cut -d '=' -f2)" ]; then
    echo -e "${GREEN}✓ Telegram notifications: Enabled${NC}"
else
    echo -e "${YELLOW}⚠ Telegram notifications: Not configured${NC}"
    echo "  To enable: Edit .env and add TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID"
fi

echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Verify your .env configuration: nano $INSTALL_DIR/.env"
echo "  2. Check logs: tail -f $INSTALL_DIR/rpc_health_check.log"
echo "  3. Monitor Telegram for notifications (if enabled)"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  • Keep your .env file secure (contains private keys)"
echo "  • Add backup RPC URLs in .env for redundancy"
echo "  • Monitor logs regularly for any issues"
echo ""

print_success "Happy monitoring! 🚀"
echo ""
