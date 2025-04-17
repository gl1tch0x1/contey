#!/bin/bash

LISTEN_PORT=2222
LOG_DIR="$HOME/honeypot_logs"
VALID_USER="admin"
VALID_PASS="honeypot"
GMAIL_EMAIL="mailaddress@gmail.com"
MSMTP_CONF="$HOME/.msmtprc"
MSMTP_PASS_FILE="$HOME/.msmtp_pass"

RED="\033[1;31m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

install_dependencies() {
  echo -e "${YELLOW}🔧 Installing required tools...${RESET}"
  sudo apt-get update -qq
  sudo apt-get install -y socat msmtp mailutils asciinema multitail goaccess figlet lolcat >/dev/null 2>&1
}

ascii_banner() {
  figlet Honeypot | lolcat
}

configure_gmail() {
  if [[ ! -f "$MSMTP_CONF" ]]; then
    echo -e "${YELLOW}📧 Configuring Gmail SMTP securely...${RESET}"
    echo -n "Enter your Gmail App Password: "
    read -s app_password
    echo
    echo "$app_password" > "$MSMTP_PASS_FILE"
    chmod 600 "$MSMTP_PASS_FILE"

    cat > "$MSMTP_CONF" <<EOF
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile ~/.msmtp.log

account gmail
host smtp.gmail.com
port 587
from $GMAIL_EMAIL
user $GMAIL_EMAIL
passwordeval "cat $MSMTP_PASS_FILE"

account default : gmail
EOF
    chmod 600 "$MSMTP_CONF"
    echo -e "${GREEN}✅ Gmail SMTP configured securely.${RESET}"
  fi
}

send_email_alert() {
  subject="$1"
  message="$2"
  echo -e "$message" | mailx -s "$subject" "$GMAIL_EMAIL"
}

handle_session() {
  IP="$1"
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  SESSION_ID="session_${TIMESTAMP}_${IP}"
  LOGFILE="$LOG_DIR/${SESSION_ID}.log"
  CASTFILE="$LOG_DIR/${SESSION_ID}.cast"

  mkdir -p "$LOG_DIR"

  asciinema rec -q -o "$CASTFILE" bash -c "
    clear
    ascii_banner
    echo -e '${CYAN}SSH-2.0-OpenSSH_8.0${RESET}'
    echo -ne '${YELLOW}login as: ${RESET}'
    read -r username
    echo -ne '${YELLOW}Password: ${RESET}'
    read -rs password
    echo

    echo \"[\$(date)] IP: $IP | Login: \$username\" >> '$LOGFILE'

    if [[ \"\$username\" == \"$VALID_USER\" && \"\$password\" == \"$VALID_PASS\" ]]; then
      echo -e '${GREEN}Access Granted${RESET}'
      echo \"[\$(date)] SUCCESS login from $IP as \$username\" >> '$LOGFILE'
      send_email_alert '🛡️ Honeypot Login SUCCESS' \"User: \$username\nIP: $IP\nTime: \$(date)\nSession: $SESSION_ID\"
    else
      echo -e '${RED}Access Denied${RESET}'
      echo \"[\$(date)] FAILED login attempt: \$username/\$password from $IP\" >> '$LOGFILE'
      send_email_alert '🚨 Honeypot Login FAILED' \"User: \$username\nPass: \$password\nIP: $IP\nTime: \$(date)\"
      exit
    fi

    echo -e '\n${CYAN}Welcome to Ubuntu 20.04.6 LTS${RESET}'
    echo -e '${YELLOW}Last login: \$(date) from $IP${RESET}\n'

    while true; do
      echo -ne '${GREEN}\$username@honeypot:~\$ ${RESET}'
      read -r cmd
      timestamp=\$(date +\"%F %T\")
      echo \"\$timestamp [$IP] \$cmd\" >> '$LOGFILE'
      [[ \"\$cmd\" == \"exit\" || \"\$cmd\" == \"logout\" ]] && break

      case \"\$cmd\" in
        ls) echo -e '${CYAN}Documents  Downloads  logs  secrets.txt${RESET}' ;;
        pwd) echo -e '${CYAN}/home/admin${RESET}' ;;
        whoami) echo -e '${CYAN}admin${RESET}' ;;
        uname*) echo -e '${CYAN}Linux honeypot 5.15.0 x86_64${RESET}' ;;
        ifconfig) echo -e '${CYAN}eth0: inet 192.168.1.100  netmask 255.255.255.0${RESET}' ;;
        help) echo -e '${YELLOW}Available commands: ls, pwd, whoami, uname, ifconfig, help, exit${RESET}' ;;
        *) echo -e '${RED}bash: \$cmd: command not found${RESET}' ;;
      esac
    done

    echo -e '${YELLOW}Session ended. Log saved: ${LOGFILE}${RESET}'
  "
}

start_honeypot() {
  echo -e "${GREEN}🚀 Starting honeypot listener on port ${LISTEN_PORT}...${RESET}"
  while true; do
    socat TCP-LISTEN:$LISTEN_PORT,reuseaddr,fork EXEC:"bash -c 'handle_session \$SOCAT_PEERADDR'"
  done
}

start_monitoring() {
  echo -e "${GREEN}🔍 Real-time log monitoring...${RESET}"
  multitail "$LOG_DIR"/session_*.log
}

start_visual_report() {
  echo -e "${GREEN}📊 Launching GoAccess HTML report (Ctrl+C to exit)...${RESET}"
  goaccess "$LOG_DIR"/session_*.log -o "$LOG_DIR"/report.html --log-format=COMBINED --real-time-html
}

# Main
install_dependencies
configure_gmail
mkdir -p "$LOG_DIR"
ascii_banner
start_honeypot

