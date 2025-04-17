#!/bin/bash
echo "[*] Updating honeypot project..."
cd "$HOME/honeypot" || exit

# If repo not cloned, clone it
if [ ! -d ".git" ]; then
  echo "[*] Cloning GitHub repository..."
  git clone https://github.com/gl1tch0x1/contey.git "$HOME/honeypot"
  cd "$HOME/honeypot"
fi

# Pull latest changes from the repository
echo "[*] Pulling latest changes from Git..."
git pull || { echo "[*] Git pull failed. Exiting."; exit 1; }

# Reinstall dependencies (this assumes you have a script or package manager to handle them)
echo "[*] Reinstalling dependencies..."
bash honeypot.sh --silent-setup

# Restart honeypot services
echo "[*] Restarting honeypot..."
pkill -f app.py  # Kill any existing Flask processes
pkill -f socat   # Kill any existing socat processes
bash honeypot.sh &  # Restart the honeypot in background
echo "[*] Honeypot restarted successfully."
echo "[*] Update complete."
echo "[*] Please check the logs for any errors."