#!/bin/bash

echo "[*] Updating honeypot project..."

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || { echo "[!] Failed to access script directory."; exit 1; }

# If repo not cloned (not a git repo), clone it
if [ ! -d ".git" ]; then
  echo "[*] Cloning GitHub repository..."
  git clone https://github.com/gl1tch0x1/contey.git "$SCRIPT_DIR"
  cd "$SCRIPT_DIR" || { echo "[!] Failed to access cloned repo."; exit 1; }
fi

# Pull latest changes
echo "[*] Pulling latest changes from Git..."
git pull || { echo "[!] Git pull failed. Exiting."; exit 1; }

# Reinstall dependencies (adjust honeypot.sh if needed)
echo "[*] Reinstalling dependencies..."
bash honeypot.sh --silent-setup || { echo "[!] Dependency setup failed."; exit 1; }

# Restart honeypot services
echo "[*] Restarting honeypot..."
pkill -f app.py 2>/dev/null
pkill -f socat 2>/dev/null
nohup bash honeypot.sh > /dev/null 2>&1 &

echo "[*] Honeypot restarted successfully."
echo "[*] Update complete."
echo "[*] Please check the logs for any errors."
