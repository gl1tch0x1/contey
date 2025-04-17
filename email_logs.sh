#!/bin/bash
LOG_DIR="$HOME/honeypot_logs"
EMAIL_CONFIG="$HOME/.honeypot_email"
PDF_FILE="$LOG_DIR/honeypot_report.pdf"

if [[ ! -f "$EMAIL_CONFIG" ]]; then
  echo "Email config missing!"
  exit 1
fi

EMAIL=$(cat "$EMAIL_CONFIG")

LATEST_LOG=$(ls -t "$LOG_DIR"/*.log | head -n 1)

if [[ -z "$LATEST_LOG" ]]; then
  echo "No logs to send."
  exit 0
fi

enscript "$LATEST_LOG" -o - | ps2pdf - "$PDF_FILE"

echo "See attached honeypot session log." | mailx -s "Honeypot Report" -a "$PDF_FILE" "$EMAIL"
if [[ $? -eq 0 ]]; then
  echo "Email sent successfully to $EMAIL"
else
  echo "Failed to send email."
fi
rm "$PDF_FILE"
echo "Temporary files cleaned up."
echo "Email logs script completed."
#   local session_id=$(basename "$log" .log)
#   local session_dir="$LOG_DIR/$session_id"
#   mkdir -p "$session_dir"
#   local ip=$(grep -oP '(?<=IP: )\d+\.\d+\.\d+\.\d+' "$log")
#   local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
#   local log_file="$session_dir/$session_id.log"
#   local csv_file="$session_dir/$session_id.csv"
#   local html_file="$session_dir/$session_id.html"
#   local pdf_file="$session_dir/$session_id.pdf"
