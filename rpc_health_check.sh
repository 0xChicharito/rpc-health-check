#!/bin/bash

# RPC Health Check Script for ETH and BEACON
# Auto-replace with backup RPC when error detected
# Auto-restore original RPC when recovered

# ===== CONFIGURATION =====
ENV_FILE=".env"  # Path to configuration file (in current directory)
TIMEOUT=10       # Timeout for each request (seconds)
MAX_RETRIES=3    # Number of retries before replacing
ORIGINAL_RPC_FILE=".original_rpc"  # File to store original RPC
LOG_FILE="rpc_health_check.log"  # Log file in current directory

# ===== TELEGRAM CONFIGURATION =====
# Set these in .env file or export as environment variables:
# TELEGRAM_BOT_TOKEN=your_bot_token_here
# TELEGRAM_CHAT_ID=your_chat_id_here
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# ===== TELEGRAM CONFIGURATION =====
# Set these in .env file or export as environment variables:
# TELEGRAM_BOT_TOKEN=your_bot_token_here
# TELEGRAM_CHAT_ID=your_chat_id_here
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Default backup RPC list for Ethereum (will be overridden by .env)
BACKUP_ETH_RPCS=(
    "https://eth.llamarpc.com"
    "https://rpc.ankr.com/eth"
    "https://eth.drpc.org"
    "https://ethereum.publicnode.com"
)

# Default backup BEACON list (will be overridden by .env)
BACKUP_BEACON_URLS=(
    "https://ethereum-beacon-api.publicnode.com"
    "https://beaconstate.ethstaker.cc"
)

# ===== LOGGING =====
LOG_FILE="rpc_health_check.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ===== TELEGRAM NOTIFICATION =====
send_telegram_message() {
    local message=$1
    
    # Check if Telegram is configured
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        return 0  # Skip if not configured
    fi
    
    # Send message via Telegram Bot API
    local response=$(curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="HTML" 2>/dev/null)
    
    if echo "$response" | grep -q '"ok":true'; then
        log "✓ Telegram notification sent successfully"
    else
        log "✗ Failed to send Telegram notification"
    fi
}

# ===== DOCKER COMPOSE RESTART =====
restart_docker_compose() {
    local docker_restart_enabled=$(read_env_value "DOCKER_COMPOSE_RESTART")
    
    if [ "$docker_restart_enabled" != "true" ]; then
        return 0  # Skip if not enabled
    fi
    
    # Check if docker-compose file exists
    if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ]; then
        log "⚠ Docker Compose file not found, skipping restart"
        return 1
    fi
    
    log "🔄 Restarting Docker Compose stack..."
    
    # Try docker compose (v2) first, then docker-compose (v1)
    if command -v docker &> /dev/null; then
        if docker compose version &> /dev/null 2>&1; then
            docker compose restart
            local exit_code=$?
        else
            docker-compose restart
            local exit_code=$?
        fi
        
        if [ $exit_code -eq 0 ]; then
            log "✓ Docker Compose stack restarted successfully"
            send_telegram_message "🔄 <b>Docker Restart</b>%0A%0ADocker Compose stack restarted due to RPC failure%0A%0ATime: $(date '+%Y-%m-%d %H:%M:%S')"
            return 0
        else
            log "✗ Failed to restart Docker Compose stack"
            return 1
        fi
    else
        log "⚠ Docker not found, skipping restart"
        return 1
    fi
}

# ===== SAVE ORIGINAL RPC =====
save_original_rpc() {
    local eth_rpc=$1
    local beacon_url=$2
    
    # Only save if file doesn't exist (first time detecting error)
    if [ ! -f "$ORIGINAL_RPC_FILE" ]; then
        echo "ORIGINAL_ETH_RPC=$eth_rpc" > "$ORIGINAL_RPC_FILE"
        echo "ORIGINAL_BEACON_URL=$beacon_url" >> "$ORIGINAL_RPC_FILE"
        log "💾 Original RPC saved to $ORIGINAL_RPC_FILE"
    fi
}

# ===== READ ORIGINAL RPC =====
read_original_rpc() {
    local key=$1
    if [ -f "$ORIGINAL_RPC_FILE" ]; then
        grep "^${key}=" "$ORIGINAL_RPC_FILE" | cut -d '=' -f2
    fi
}

# ===== CLEAR ORIGINAL RPC FILE =====
clear_original_rpc() {
    if [ -f "$ORIGINAL_RPC_FILE" ]; then
        rm "$ORIGINAL_RPC_FILE"
        log "🗑️  Original RPC file removed"
    fi
}

# ===== CHECK AND RESTORE ORIGINAL RPC =====
check_and_restore_original() {
    if [ ! -f "$ORIGINAL_RPC_FILE" ]; then
        return 0  # No original RPC to restore
    fi
    
    local original_eth=$(read_original_rpc "ORIGINAL_ETH_RPC")
    local original_beacon=$(read_original_rpc "ORIGINAL_BEACON_URL")
    local current_eth=$(read_env_value "ETHEREUM_RPC_URL")
    local current_beacon=$(read_env_value "CONSENSUS_BEACON_URL")
    
    local eth_restored=false
    local beacon_restored=false
    
    # Check if using backup RPC and original RPC has recovered
    if [ "$current_eth" != "$original_eth" ] && [ -n "$original_eth" ]; then
        log "🔍 Using backup RPC. Checking original RPC..."
        if check_eth_rpc "$original_eth"; then
            log "🎉 Original RPC has recovered: $original_eth"
            update_env_file "ETHEREUM_RPC_URL" "$original_eth"
            log "✅ Original RPC restored"
            
            # Send Telegram notification
            send_telegram_message "🎉 <b>RPC Restored</b>%0A%0A✅ Original Ethereum RPC has recovered and been restored:%0A<code>$original_eth</code>%0A%0ATime: $(date '+%Y-%m-%d %H:%M:%S')"
            
            eth_restored=true
        else
            log "⏳ Original RPC not yet recovered"
        fi
    fi
    
    # Check if using backup Beacon and original Beacon has recovered
    if [ "$current_beacon" != "$original_beacon" ] && [ -n "$original_beacon" ]; then
        log "🔍 Using backup Beacon. Checking original Beacon..."
        if check_beacon "$original_beacon"; then
            log "🎉 Original Beacon has recovered: $original_beacon"
            update_env_file "CONSENSUS_BEACON_URL" "$original_beacon"
            log "✅ Original Beacon restored"
            
            # Send Telegram notification
            send_telegram_message "🎉 <b>Beacon Restored</b>%0A%0A✅ Original Consensus Beacon has recovered and been restored:%0A<code>$original_beacon</code>%0A%0ATime: $(date '+%Y-%m-%d %H:%M:%S')"
            
            beacon_restored=true
        else
            log "⏳ Original Beacon not yet recovered"
        fi
    fi
    
    # Remove original RPC file if both are restored
    if [ "$eth_restored" = true ] && ([ "$current_beacon" == "$original_beacon" ] || [ "$beacon_restored" = true ]); then
        clear_original_rpc
    elif [ "$beacon_restored" = true ] && ([ "$current_eth" == "$original_eth" ] || [ "$eth_restored" = true ]); then
        clear_original_rpc
    fi
}

# ===== CHECK ETHEREUM RPC =====
check_eth_rpc() {
    local rpc_url=$1
    local response
    
    log "Checking Ethereum RPC: $rpc_url"
    
    # Send eth_blockNumber request to check
    response=$(curl -s -m $TIMEOUT -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "$rpc_url" 2>/dev/null)
    
    # Check if response contains result
    if echo "$response" | grep -q '"result"'; then
        log "✓ Ethereum RPC is working normally"
        return 0
    else
        log "✗ Ethereum RPC not responding or error"
        return 1
    fi
}

# ===== CHECK BEACON =====
check_beacon() {
    local beacon_url=$1
    local response
    local http_code
    
    log "Checking Beacon: $beacon_url"
    
    # Send request to /eth/v1/node/health
    http_code=$(curl -s -m $TIMEOUT -o /dev/null -w "%{http_code}" \
        "$beacon_url/eth/v1/node/health" 2>/dev/null)
    
    # Beacon health endpoint returns 200 if healthy
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 206 ]; then
        log "✓ Beacon is working normally (HTTP $http_code)"
        return 0
    else
        log "✗ Beacon not responding or error (HTTP $http_code)"
        return 1
    fi
}

# ===== FIND WORKING BACKUP ETH RPC =====
find_working_eth_rpc() {
    log "Finding available Ethereum backup RPC..."
    
    for backup_rpc in "${BACKUP_ETH_RPCS[@]}"; do
        if check_eth_rpc "$backup_rpc"; then
            echo "$backup_rpc"
            return 0
        fi
    done
    
    log "⚠ No available Ethereum backup RPC found!"
    return 1
}

find_working_beacon() {
    log "Finding available Beacon backup..."
    
    for backup_beacon in "${BACKUP_BEACON_URLS[@]}"; do
        if check_beacon "$backup_beacon"; then
            echo "$backup_beacon"
            return 0
        fi
    done
    
    log "⚠ No available Beacon backup found!"
    return 1
}

# ===== UPDATE .ENV FILE =====
update_env_file() {
    local key=$1
    local new_value=$2
    
    if [ ! -f "$ENV_FILE" ]; then
        log "✗ File $ENV_FILE not found"
        return 1
    fi
    
    # Backup original file
    cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update new value
    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${new_value}|" "$ENV_FILE"
        log "✓ Updated $key=$new_value in file $ENV_FILE"
        return 0
    else
        log "✗ Key $key not found in file $ENV_FILE"
        return 1
    fi
}

# ===== READ VALUE FROM .ENV =====
read_env_value() {
    local key=$1
    grep "^${key}=" "$ENV_FILE" | cut -d '=' -f2
}

# ===== LOAD TELEGRAM CONFIG FROM .ENV =====
load_telegram_config() {
    if [ -f "$ENV_FILE" ]; then
        # Load Telegram config from .env if available
        local bot_token=$(grep "^TELEGRAM_BOT_TOKEN=" "$ENV_FILE" | cut -d '=' -f2)
        local chat_id=$(grep "^TELEGRAM_CHAT_ID=" "$ENV_FILE" | cut -d '=' -f2)
        
        if [ -n "$bot_token" ]; then
            TELEGRAM_BOT_TOKEN="$bot_token"
        fi
        
        if [ -n "$chat_id" ]; then
            TELEGRAM_CHAT_ID="$chat_id"
        fi
    fi
}

# ===== LOAD BACKUP RPCs FROM .ENV =====
load_backup_rpcs() {
    if [ -f "$ENV_FILE" ]; then
        # Load backup Ethereum RPCs from .env if available
        local backup_eth=$(grep "^BACKUP_ETHEREUM_RPCS=" "$ENV_FILE" | cut -d '=' -f2)
        if [ -n "$backup_eth" ]; then
            # Convert comma-separated string to array
            IFS=',' read -ra BACKUP_ETH_RPCS <<< "$backup_eth"
            log "Loaded ${#BACKUP_ETH_RPCS[@]} backup Ethereum RPC(s) from .env"
        fi
        
        # Load backup Beacon URLs from .env if available
        local backup_beacon=$(grep "^BACKUP_BEACON_URLS=" "$ENV_FILE" | cut -d '=' -f2)
        if [ -n "$backup_beacon" ]; then
            # Convert comma-separated string to array
            IFS=',' read -ra BACKUP_BEACON_URLS <<< "$backup_beacon"
            log "Loaded ${#BACKUP_BEACON_URLS[@]} backup Beacon URL(s) from .env"
        fi
    fi
}

# ===== MAIN FUNCTION =====
main() {
    log "========== STARTING HEALTH CHECK =========="
    
    if [ ! -f "$ENV_FILE" ]; then
        log "✗ File $ENV_FILE does not exist!"
        echo "Please run install.sh first to configure the monitoring system"
        exit 1
    fi
    
    # Load Telegram configuration
    load_telegram_config
    
    # Load backup RPCs from .env
    load_backup_rpcs
    
    # Read current configuration
    CURRENT_ETH_RPC=$(read_env_value "ETHEREUM_RPC_URL")
    CURRENT_BEACON=$(read_env_value "CONSENSUS_BEACON_URL")
    
    if [ -z "$CURRENT_ETH_RPC" ] || [ -z "$CURRENT_BEACON" ]; then
        log "✗ RPC URLs not configured in .env file"
        echo "Please run install.sh to configure RPC endpoints"
        exit 1
    fi
    
    log "Current configuration:"
    log "  - ETH RPC: $CURRENT_ETH_RPC"
    log "  - BEACON: $CURRENT_BEACON"
    
    # ===== CHECK AND RESTORE ORIGINAL RPC (PRIORITY) =====
    check_and_restore_original
    
    # Re-read configuration after possible restoration
    CURRENT_ETH_RPC=$(read_env_value "ETHEREUM_RPC_URL")
    CURRENT_BEACON=$(read_env_value "CONSENSUS_BEACON_URL")
    
    # ===== CHECK ETHEREUM RPC =====
    eth_failed=false
    for ((i=1; i<=MAX_RETRIES; i++)); do
        if check_eth_rpc "$CURRENT_ETH_RPC"; then
            eth_failed=false
            break
        else
            log "Retry $i/$MAX_RETRIES..."
            eth_failed=true
            sleep 2
        fi
    done
    
    if [ "$eth_failed" = true ]; then
        log "⚠ Ethereum RPC failed after $MAX_RETRIES attempts!"
        
        # Save original RPC before replacement (if not saved yet)
        original_eth=$(read_original_rpc "ORIGINAL_ETH_RPC")
        if [ -z "$original_eth" ]; then
            save_original_rpc "$CURRENT_ETH_RPC" "$CURRENT_BEACON"
        fi
        
        new_rpc=$(find_working_eth_rpc)
        if [ $? -eq 0 ]; then
            update_env_file "ETHEREUM_RPC_URL" "$new_rpc"
            log "✓ Switched to backup RPC: $new_rpc"
            
            # Restart Docker Compose if enabled
            restart_docker_compose
            
            # Send Telegram notification
            send_telegram_message "🚨 <b>RPC Failure Alert</b>%0A%0A❌ Ethereum RPC failed after $MAX_RETRIES attempts:%0A<code>$CURRENT_ETH_RPC</code>%0A%0A✅ Switched to backup RPC:%0A<code>$new_rpc</code>%0A%0ATime: $(date '+%Y-%m-%d %H:%M:%S')"
        else
            # Send alert if no backup available
            send_telegram_message "🚨 <b>CRITICAL: RPC Failure</b>%0A%0A❌ Ethereum RPC failed:%0A<code>$CURRENT_ETH_RPC</code>%0A%0A⚠️ No backup RPC available!%0A%0ATime: $(date '+%Y-%m-%d %H:%M:%S')"
        fi
    fi
    
    # ===== CHECK BEACON =====
    beacon_failed=false
    for ((i=1; i<=MAX_RETRIES; i++)); do
        if check_beacon "$CURRENT_BEACON"; then
            beacon_failed=false
            break
        else
            log "Retry $i/$MAX_RETRIES..."
            beacon_failed=true
            sleep 2
        fi
    done
    
    if [ "$beacon_failed" = true ]; then
        log "⚠ Beacon failed after $MAX_RETRIES attempts!"
        
        # Save original RPC before replacement (if not saved yet)
        original_beacon=$(read_original_rpc "ORIGINAL_BEACON_URL")
        if [ -z "$original_beacon" ]; then
            save_original_rpc "$CURRENT_ETH_RPC" "$CURRENT_BEACON"
        fi
        
        new_beacon=$(find_working_beacon)
        if [ $? -eq 0 ]; then
            update_env_file "CONSENSUS_BEACON_URL" "$new_beacon"
            log "✓ Switched to backup Beacon: $new_beacon"
            
            # Restart Docker Compose if enabled
            restart_docker_compose
            
            # Send Telegram notification
            send_telegram_message "🚨 <b>Beacon Failure Alert</b>%0A%0A❌ Consensus Beacon failed after $MAX_RETRIES attempts:%0A<code>$CURRENT_BEACON</code>%0A%0A✅ Switched to backup Beacon:%0A<code>$new_beacon</code>%0A%0ATime: $(date '+%Y-%m-%d %H:%M:%S')"
        else
            # Send alert if no backup available
            send_telegram_message "🚨 <b>CRITICAL: Beacon Failure</b>%0A%0A❌ Consensus Beacon failed:%0A<code>$CURRENT_BEACON</code>%0A%0A⚠️ No backup Beacon available!%0A%0ATime: $(date '+%Y-%m-%d %H:%M:%S')"
        fi
    fi
    
    log "========== HEALTH CHECK COMPLETED =========="
    echo ""
}

# Run script
main
