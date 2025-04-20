#!/bin/bash

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || { echo "[!] Cannot access script directory. Exiting."; exit 1; }

# Set log file and timestamped backup directory
LOG_FILE="$SCRIPT_DIR/update.log"
BACKUP_DIR="$SCRIPT_DIR/backup_$(date +%Y%m%d_%H%M%S)"

# Logging start
echo -e "\n[*] Starting update process - $(date)" | tee -a "$LOG_FILE"
echo "-------------------------------------------" | tee -a "$LOG_FILE"

# Ask user for backup
read -p "[?] Do you want to back up modified files before update? (y/n): " backup_choice
if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
    echo "[*] Creating backup at $BACKUP_DIR..." | tee -a "$LOG_FILE"
    mkdir -p "$BACKUP_DIR"
    
    # List modified/tracked files and back them up
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$file")"
            cp "$file" "$BACKUP_DIR/$file"
        fi
    done < <(git ls-files -m)

    echo "[+] Backup completed." | tee -a "$LOG_FILE"
else
    echo "[*] Skipping backup." | tee -a "$LOG_FILE"
fi

# Check Python3
echo "[*] Checking Python3..." | tee -a "$LOG_FILE"
if ! command -v python3 &>/dev/null; then
    echo "[!] Python3 is not installed. Please install it before continuing." | tee -a "$LOG_FILE"
    exit 1
fi

# Check Flask
echo "[*] Checking Flask..." | tee -a "$LOG_FILE"
if ! python3 -c "import flask" &>/dev/null; then
    echo "[!] Flask is not installed. Attempting to install via pip..." | tee -a "$LOG_FILE"
    pip3 install flask >> "$LOG_FILE" 2>&1 || { echo "[!] Failed to install Flask. Exiting." | tee -a "$LOG_FILE"; exit 1; }
else
    echo "[+] Flask is already installed." | tee -a "$LOG_FILE"
fi

# Git update (force overwrite)
echo "[*] Pulling latest code from GitHub (discarding local changes)..." | tee -a "$LOG_FILE"
git fetch origin >> "$LOG_FILE" 2>&1
git reset --hard origin/main >> "$LOG_FILE" 2>&1 || { echo "[!] Git reset failed. Exiting." | tee -a "$LOG_FILE"; exit 1; }

# Reinstall dependencies
echo "[*] Reinstalling dependencies via honeypot.sh..." | tee -a "$LOG_FILE"
if [ -f "honeypot.sh" ]; then
    bash honeypot.sh --silent-setup >> "$LOG_FILE" 2>&1 || { echo "[!] Setup failed. Check honeypot.sh. Exiting." | tee -a "$LOG_FILE"; exit 1; }
else
    echo "[!] honeypot.sh not found. Skipping dependency setup." | tee -a "$LOG_FILE"
fi

# Restart honeypot
echo "[*] Restarting honeypot services..." | tee -a "$LOG_FILE"
pkill -f app.py 2>/dev/null
pkill -f socat 2>/dev/null
nohup bash honeypot.sh > /dev/null 2>&1 &

echo "[+] Honeypot successfully updated and restarted." | tee -a "$LOG_FILE"
echo "[✓] Done. Full log available at: $LOG_FILE"
