#!/bin/bash

# RPC Health Check - Fully Automated Installer
# Auto-configures everything with user input

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Config
REPO_URL="https://raw.githubusercontent.com/0xChicharito/rpc-health-check/main"
INSTALL_DIR=$(pwd)

# Display banner
clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}║${BOLD}        RPC Health Check Monitor - Auto Installer${NC}${CYAN}        ║${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Installation directory:${NC} $INSTALL_DIR"
echo ""

# Function to print status
print_status() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_step() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Step 1: Pre-flight checks
print_step "STEP 1: Pre-flight Checks"

print_status "Checking system requirements..."
REQUIRED_COMMANDS=("curl" "grep" "sed" "crontab")
MISSING_COMMANDS=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_COMMANDS+=("$cmd")
    fi
done

if [ ${#MISSING_COMMANDS[@]} -gt 0 ]; then
    print_error "Missing required commands: ${MISSING_COMMANDS[*]}"
    exit 1
fi

print_success "All required commands found"

# Check if Docker Compose exists
if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
    DOCKER_COMPOSE_EXISTS=true
    print_success "Docker Compose file detected"
else
    DOCKER_COMPOSE_EXISTS=false
    print_warning "No Docker Compose file found (container restart disabled)"
fi

# Check/create .env
if [ ! -f ".env" ]; then
    print_status "Creating .env file..."
    touch .env
    chmod 600 .env
    print_success ".env file created"
else
    print_success ".env file exists"
fi

# Step 2: Download scripts
print_step "STEP 2: Downloading Monitoring Scripts"

FILES=(
    "rpc_health_check.sh"
    "setup_cron.sh"
)

for file in "${FILES[@]}"; do
    print_status "Downloading $file..."
    if curl -fsSL "$REPO_URL/$file" -o "$file" 2>/dev/null; then
        chmod +x "$file"
        print_success "$file downloaded and made executable"
    else
        print_error "Failed to download $file"
        echo ""
        echo "Manual download:"
        echo "  curl -O $REPO_URL/$file"
        echo "  chmod +x $file"
        exit 1
    fi
done

# Step 3: Interactive Configuration
print_step "STEP 3: RPC Configuration"

echo -e "${BOLD}Please provide your RPC endpoints:${NC}"
echo ""

# Ethereum RPC
CURRENT_ETH_RPC=$(grep "^ETHEREUM_RPC_URL=" .env 2>/dev/null | cut -d '=' -f2)
if [ -n "$CURRENT_ETH_RPC" ]; then
    echo -e "${YELLOW}Current Ethereum RPC:${NC} $CURRENT_ETH_RPC"
    read -p "Keep current value? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        CURRENT_ETH_RPC=""
    fi
fi

if [ -z "$CURRENT_ETH_RPC" ]; then
    echo -e "${CYAN}Enter your Ethereum RPC URL:${NC}"
    read -p "> " ETH_RPC
    if [ -n "$ETH_RPC" ]; then
        sed -i '/^ETHEREUM_RPC_URL=/d' .env 2>/dev/null || true
        echo "ETHEREUM_RPC_URL=$ETH_RPC" >> .env
        print_success "Ethereum RPC saved"
    fi
fi

echo ""

# Consensus Beacon
CURRENT_BEACON=$(grep "^CONSENSUS_BEACON_URL=" .env 2>/dev/null | cut -d '=' -f2)
if [ -n "$CURRENT_BEACON" ]; then
    echo -e "${YELLOW}Current Consensus Beacon:${NC} $CURRENT_BEACON"
    read -p "Keep current value? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        CURRENT_BEACON=""
    fi
fi

if [ -z "$CURRENT_BEACON" ]; then
    echo -e "${CYAN}Enter your Consensus Beacon URL:${NC}"
    read -p "> " BEACON_URL
    if [ -n "$BEACON_URL" ]; then
        sed -i '/^CONSENSUS_BEACON_URL=/d' .env 2>/dev/null || true
        echo "CONSENSUS_BEACON_URL=$BEACON_URL" >> .env
        print_success "Consensus Beacon saved"
    fi
fi

# Step 4: Backup RPC Configuration
print_step "STEP 4: Backup RPC Configuration"

echo -e "${BOLD}Configure backup RPC endpoints:${NC}"
echo ""

# Backup Ethereum RPCs
CURRENT_BACKUP_ETH=$(grep "^BACKUP_ETHEREUM_RPCS=" .env 2>/dev/null | cut -d '=' -f2)
if [ -n "$CURRENT_BACKUP_ETH" ]; then
    echo -e "${YELLOW}Current backup Ethereum RPCs:${NC}"
    echo "$CURRENT_BACKUP_ETH" | tr ',' '\n' | sed 's/^/  - /'
    echo ""
    read -p "Keep current values? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        CURRENT_BACKUP_ETH=""
    fi
fi

if [ -z "$CURRENT_BACKUP_ETH" ]; then
    echo -e "${CYAN}Enter backup Ethereum RPC URLs (comma-separated):${NC}"
    echo -e "${YELLOW}Example: https://eth.llamarpc.com,https://rpc.ankr.com/eth${NC}"
    echo -e "${YELLOW}Press Enter to use defaults${NC}"
    read -p "> " BACKUP_ETH
    if [ -z "$BACKUP_ETH" ]; then
        BACKUP_ETH="https://eth.llamarpc.com,https://rpc.ankr.com/eth,https://eth.drpc.org,https://ethereum.publicnode.com"
        print_warning "Using default backup RPCs"
    fi
    sed -i '/^BACKUP_ETHEREUM_RPCS=/d' .env 2>/dev/null || true
    echo "BACKUP_ETHEREUM_RPCS=$BACKUP_ETH" >> .env
    print_success "Backup Ethereum RPCs saved"
fi

echo ""

# Backup Beacon URLs
CURRENT_BACKUP_BEACON=$(grep "^BACKUP_BEACON_URLS=" .env 2>/dev/null | cut -d '=' -f2)
if [ -n "$CURRENT_BACKUP_BEACON" ]; then
    echo -e "${YELLOW}Current backup Beacon URLs:${NC}"
    echo "$CURRENT_BACKUP_BEACON" | tr ',' '\n' | sed 's/^/  - /'
    echo ""
    read -p "Keep current values? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        CURRENT_BACKUP_BEACON=""
    fi
fi

if [ -z "$CURRENT_BACKUP_BEACON" ]; then
    echo -e "${CYAN}Enter backup Beacon URLs (comma-separated):${NC}"
    echo -e "${YELLOW}Example: https://ethereum-beacon-api.publicnode.com${NC}"
    echo -e "${YELLOW}Press Enter to use defaults${NC}"
    read -p "> " BACKUP_BEACON
    if [ -z "$BACKUP_BEACON" ]; then
        BACKUP_BEACON="https://ethereum-beacon-api.publicnode.com,https://beaconstate.ethstaker.cc"
        print_warning "Using default backup Beacon URLs"
    fi
    sed -i '/^BACKUP_BEACON_URLS=/d' .env 2>/dev/null || true
    echo "BACKUP_BEACON_URLS=$BACKUP_BEACON" >> .env
    print_success "Backup Beacon URLs saved"
fi

# Step 5: Telegram Configuration
print_step "STEP 5: Telegram Notification (Optional)"

echo -e "${BOLD}Setup Telegram notifications for RPC alerts:${NC}"
echo ""

read -p "Do you want to enable Telegram notifications? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${CYAN}To setup Telegram:${NC}"
    echo "  1. Open Telegram and search for @BotFather"
    echo "  2. Send: /newbot and follow instructions"
    echo "  3. Copy your bot token"
    echo "  4. Search for @userinfobot to get your Chat ID"
    echo ""
    
    echo -e "${CYAN}Enter your Telegram Bot Token:${NC}"
    read -p "> " BOT_TOKEN
    
    echo -e "${CYAN}Enter your Telegram Chat ID:${NC}"
    read -p "> " CHAT_ID
    
    if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
        sed -i '/^TELEGRAM_BOT_TOKEN=/d' .env 2>/dev/null || true
        sed -i '/^TELEGRAM_CHAT_ID=/d' .env 2>/dev/null || true
        echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN" >> .env
        echo "TELEGRAM_CHAT_ID=$CHAT_ID" >> .env
        print_success "Telegram configuration saved"
        
        # Test Telegram
        echo ""
        read -p "Test Telegram notification now? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            TEST_MSG="✅ RPC Health Check Monitor configured successfully!"
            RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                -d chat_id="${CHAT_ID}" \
                -d text="${TEST_MSG}")
            
            if echo "$RESPONSE" | grep -q '"ok":true'; then
                print_success "Telegram test message sent successfully!"
            else
                print_error "Failed to send test message. Please check your credentials."
            fi
        fi
    fi
else
    print_warning "Telegram notifications disabled"
fi

# Step 6: Docker Compose Restart Configuration
if [ "$DOCKER_COMPOSE_EXISTS" = true ]; then
    print_step "STEP 6: Docker Compose Restart Configuration"
    
    echo -e "${BOLD}Enable automatic Docker Compose restart on RPC failure?${NC}"
    echo ""
    echo "When RPC fails and switches to backup, the script can restart"
    echo "your Docker Compose stack to ensure clean state."
    echo ""
    
    read -p "Enable Docker Compose restart? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sed -i '/^DOCKER_COMPOSE_RESTART=/d' .env 2>/dev/null || true
        echo "DOCKER_COMPOSE_RESTART=true" >> .env
        print_success "Docker Compose restart enabled"
    else
        sed -i '/^DOCKER_COMPOSE_RESTART=/d' .env 2>/dev/null || true
        echo "DOCKER_COMPOSE_RESTART=false" >> .env
        print_warning "Docker Compose restart disabled"
    fi
fi

# Step 7: Cron Job Setup
print_step "STEP 7: Automatic Monitoring Setup"

echo -e "${BOLD}Setup automatic RPC monitoring with cron:${NC}"
echo ""

read -p "Enable automatic monitoring? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Select check frequency:"
    echo "  1) Every 5 minutes  (recommended)"
    echo "  2) Every 10 minutes"
    echo "  3) Every 15 minutes"
    echo "  4) Every 30 minutes"
    echo "  5) Every hour"
    echo "  6) Custom"
    echo ""
    read -p "Enter choice (1-6): " -n 1 -r
    echo ""
    
    case $REPLY in
        1) CRON_SCHEDULE="*/5 * * * *" ;;
        2) CRON_SCHEDULE="*/10 * * * *" ;;
        3) CRON_SCHEDULE="*/15 * * * *" ;;
        4) CRON_SCHEDULE="*/30 * * * *" ;;
        5) CRON_SCHEDULE="0 * * * *" ;;
        6)
            echo ""
            echo "Enter custom cron schedule (e.g., */5 * * * *):"
            read -p "> " CRON_SCHEDULE
            ;;
        *) CRON_SCHEDULE="*/5 * * * *" ;;
    esac
    
    # Setup cron job
    CRON_CMD="$CRON_SCHEDULE cd $INSTALL_DIR && ./rpc_health_check.sh >> rpc_health_check.log 2>&1"
    
    # Remove existing cron job if any
    (crontab -l 2>/dev/null | grep -v "rpc_health_check.sh") | crontab - 2>/dev/null || true
    
    # Add new cron job
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    
    print_success "Cron job configured: $CRON_SCHEDULE"
else
    print_warning "Automatic monitoring not enabled"
fi

# Final Summary
print_step "Installation Complete! 🎉"

echo -e "${GREEN}${BOLD}✓ RPC Health Check Monitor successfully installed!${NC}"
echo ""

# Display configuration summary
ETH_RPC=$(grep "^ETHEREUM_RPC_URL=" .env 2>/dev/null | cut -d '=' -f2)
BEACON=$(grep "^CONSENSUS_BEACON_URL=" .env 2>/dev/null | cut -d '=' -f2)
TELEGRAM_ENABLED=$(grep "^TELEGRAM_BOT_TOKEN=" .env 2>/dev/null | cut -d '=' -f2)
DOCKER_RESTART=$(grep "^DOCKER_COMPOSE_RESTART=" .env 2>/dev/null | cut -d '=' -f2)

echo -e "${CYAN}Configuration Summary:${NC}"
echo "  ✓ Installation: $INSTALL_DIR"
echo "  ✓ Ethereum RPC: ${ETH_RPC:-Not set}"
echo "  ✓ Beacon: ${BEACON:-Not set}"
echo "  ✓ Telegram: $([ -n "$TELEGRAM_ENABLED" ] && echo "Enabled" || echo "Disabled")"
echo "  ✓ Docker restart: $([ "$DOCKER_RESTART" = "true" ] && echo "Enabled" || echo "Disabled")"
echo "  ✓ Auto-monitoring: $(crontab -l 2>/dev/null | grep -q "rpc_health_check.sh" && echo "Enabled" || echo "Disabled")"
echo ""

echo -e "${CYAN}Quick Commands:${NC}"
echo "  • Monitor logs:    tail -f rpc_health_check.log"
echo "  • Manual check:    ./rpc_health_check.sh"
echo "  • View cron:       crontab -l"
echo "  • Edit config:     nano .env"
echo ""

echo -e "${GREEN}${BOLD}Happy monitoring! 🚀${NC}"
echo ""
