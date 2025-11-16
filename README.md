# RPC Health Check Monitor

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-4.0+-green.svg)](https://www.gnu.org/software/bash/)

Automatically monitor Ethereum RPC and Consensus Beacon health, replace with backup RPC when errors detected, and restore original RPC when recovered. Includes Telegram notifications for all RPC changes.

## ✨ Features

- ✅ Health monitoring for Ethereum RPC endpoint
- ✅ Health monitoring for Consensus Beacon endpoint  
- ✅ Automatic retry on error detection
- ✅ Auto-replace with available backup RPC
- ✅ **Auto-restore original RPC when recovered**
- ✅ **Telegram notifications for RPC changes**
- ✅ **Configurable backup RPCs via .env file**
- ✅ Backup .env file before changes
- ✅ Detailed logging
- ✅ Support for automatic execution via cron job
- ✅ One-command installation

# Quick Installation Guide for Existing Directory

## For users with existing .env file (like /root/aztec)

### Step 1: Navigate to your directory

```bash
cd /root/aztec
# Or wherever your .env file is located
```

### Step 2: Install monitoring scripts

```bash
curl -sSL https://raw.githubusercontent.com/0xChicharito/rpc-health-check/main/install.sh | bash
```

### What it does:
- ✅ Downloads `rpc_health_check.sh` and `setup_cron.sh` to current directory
- ✅ Keeps your existing `.env` file
- ✅ Adds backup RPC configuration to `.env` if not present
- ✅ Sets proper permissions
- ✅ All logs saved in current directory

### Step 3: Configure (if needed)

The script will automatically add backup RPC configuration to your `.env`:

```bash
# Edit if you want to add your own backup RPCs
nano .env

# Add or modify:
BACKUP_ETHEREUM_RPCS=https://your-backup-rpc.com,https://another-backup.com
BACKUP_BEACON_URLS=https://your-backup-beacon.com
```

### Step 4: First run

```bash
./rpc_health_check.sh
```

**What happens on first run:**
- If `ETHEREUM_RPC_URL` not in .env → Script will ask you to enter it
- If `CONSENSUS_BEACON_URL` not in .env → Script will ask you to enter it
- If backup RPCs not in .env → Script will ask or use defaults

**Example:**
```
════════════════════════════════════════════════
  RPC Configuration Required
════════════════════════════════════════════════

Enter your Ethereum RPC URL:
> https://rpc-eth.node9x.com

Enter your Consensus Beacon URL:
> https://beacon-eth.node9x.com

Enter backup Ethereum RPC URLs (comma-separated):
> https://eth.llamarpc.com,https://rpc.ankr.com/eth

✓ Configuration saved to .env
```

### Step 5: Setup automatic monitoring

```bash
./setup_cron.sh
```

Select frequency:
- Every 5 minutes (recommended)
- Every 10 minutes
- Custom

## File Structure

After installation in `/root/aztec`:

```
/root/aztec/
├── .env                      # Your existing file (modified with backup RPCs)
├── rpc_health_check.sh       # Main monitoring script
├── setup_cron.sh             # Cron setup script
├── .original_rpc             # Auto-created when using backup
├── rpc_health_check.log      # All logs here
└── (your other files...)
```

## Features

### Auto-prompt for missing configuration
- Script checks .env for required fields
- Asks user to input if missing
- Saves to .env automatically

### Works with existing .env
- Doesn't create new .env
- Appends backup RPC config if needed
- Preserves all existing variables

### Logs in current directory
- All logs saved to `./rpc_health_check.log`
- Easy to monitor: `tail -f rpc_health_check.log`

## Quick Commands

```bash
# View logs in real-time
tail -f rpc_health_check.log

# Manual check
./rpc_health_check.sh

# Check if using backup
cat .original_rpc

# View cron jobs
crontab -l

# Edit configuration
nano .env
```

## Example .env additions

The installer adds these to your existing .env:

```bash
# Backup RPC URLs (comma-separated, required for RPC health check)
BACKUP_ETHEREUM_RPCS=https://eth.llamarpc.com,https://rpc.ankr.com/eth,https://eth.drpc.org,https://ethereum.publicnode.com

# Backup Beacon URLs (comma-separated, required for RPC health check)
BACKUP_BEACON_URLS=https://ethereum-beacon-api.publicnode.com,https://beaconstate.ethstaker.cc

# Telegram Notification (Optional)
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
```

## Telegram Notifications (Optional)

To enable Telegram alerts:

1. Create bot with @BotFather
2. Get Chat ID from @userinfobot
3. Add to .env:
```bash
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_ID=123456789
```

## Troubleshooting

### Files not downloading
```bash
# Manual download
cd /root/aztec
curl -O https://raw.githubusercontent.com/0xChicharito/rpc-health-check/main/rpc_health_check.sh
curl -O https://raw.githubusercontent.com/0xChicharito/rpc-health-check/main/setup_cron.sh
chmod +x rpc_health_check.sh setup_cron.sh
```

### Script asks for RPC every time
- Make sure .env has: `ETHEREUM_RPC_URL=...`
- Make sure .env has: `CONSENSUS_BEACON_URL=...`
- Check file permissions: `chmod 644 .env`

### Logs not appearing
- Check current directory: `ls -la rpc_health_check.log`
- Check write permissions: `touch test.log && rm test.log`

## What the script does

1. **Checks original RPC first** (if using backup)
2. **Tests current RPC** (retries 3 times)
3. **Switches to backup** if current fails
4. **Logs everything** to `rpc_health_check.log`
5. **Sends Telegram alert** (if configured)
6. **Auto-restores original** when recovered

## Complete Example

```bash
# 1. Install
cd /root/aztec
curl -sSL https://raw.githubusercontent.com/0xChicharito/rpc-health-check/main/install.sh | bash

# 2. First run (will prompt for RPCs if needed)
./rpc_health_check.sh

# 3. Setup auto-monitoring
./setup_cron.sh

# 4. Done! Monitor logs
tail -f rpc_health_check.log
```

That's it! 🚀

---

**Made with ❤️ for the Ethereum community**
