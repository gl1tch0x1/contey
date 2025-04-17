#!/bin/bash

LISTEN_PORT=2222
LOG_DIR="$HOME/honeypot_logs"
EMAIL_CONFIG="$HOME/.honeypot_email"
PDF_FILE="$LOG_DIR/honeypot_report.pdf"
CSV_FILE="$LOG_DIR/honeypot_logs.csv"
HTML_FILE="$LOG_DIR/honeypot_logs.html"
PROJECT_DIR="$HOME/honeypot"
FLASK_LOG="$LOG_DIR/flask.log"
RED="\033[1;31m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"
REQUIRED_CMDS=(socat msmtp mailx asciinema multitail goaccess figlet lolcat enscript ps2pdf cron python3)

ascii_banner() {
  command -v figlet >/dev/null && figlet Honeypot | lolcat
}

install_dependencies() {
  echo -e "${YELLOW}Installing dependencies...${RESET}"
  sudo apt-get update -qq
  for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      sudo apt-get install -y "$cmd" &>/dev/null
    fi
  done
}

setup_email() {
  if [[ ! -f "$EMAIL_CONFIG" ]]; then
    echo -e "${CYAN}Enter the Gmail address to receive reports:${RESET}"
    read -rp "Email: " email
    echo -e "${YELLOW}You entered: $email. Is this correct? (y/n)${RESET}"
    read -rn1 confirm
    echo
    if [[ $confirm =~ [Yy] ]]; then
      echo "$email" > "$EMAIL_CONFIG"
      echo -e "${GREEN}Email saved!${RESET}"
    else
      echo -e "${RED}Incorrect email. Exiting.${RESET}"
      exit 1
    fi
  fi
}

configure_cronjob() {
  cron_marker="# HONEYPOT_EMAIL_JOB"
  cronjob="0 * * * * bash $PROJECT_DIR/email_logs.sh > /dev/null 2>&1 $cron_marker"
  (crontab -l 2>/dev/null | grep -v "$cron_marker" ; echo "$cronjob") | crontab -
}

log_to_csv_html() {
  local log="$1"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local ip="$2"
  mkdir -p "$LOG_DIR/html" "$LOG_DIR/csv"
  while read -r line; do
    echo "$timestamp,$ip,\"$line\"" >> "$LOG_DIR/csv/honeypot_logs.csv"
    echo "<tr><td>$timestamp</td><td>$ip</td><td>$line</td></tr>" >> "$LOG_DIR/html/honeypot_logs.html"
  done < "$log"
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
    if [[ "\$username" == "admin" && "\$password" == "honeypot" ]]; then
      echo -e '${GREEN}Access Granted${RESET}'
    else
      echo -e '${RED}Access Denied${RESET}'
      exit
    fi
    echo -e '\n${CYAN}Welcome to Ubuntu 20.04.6 LTS${RESET}'
    while true; do
      echo -ne '${GREEN}\$username@honeypot:~\$ ${RESET}'
      read -r cmd
      timestamp=\$(date +"%F %T")
      echo "\$timestamp [\$IP] \$cmd" >> '$LOGFILE'
      [[ "\$cmd" == "exit" || "\$cmd" == "logout" ]] && break
      case "\$cmd" in
        ls) echo -e '${CYAN}Documents  secrets.txt  db.sqlite3${RESET}' ;;
        cat\\ secrets.txt) echo -e '${YELLOW}FAKE_SECRET=123456${RESET}' ;;
        pwd) echo -e '${CYAN}/home/admin${RESET}' ;;
        whoami) echo -e '${CYAN}admin${RESET}' ;;
        uname*) echo -e '${CYAN}Linux honeypot 5.15.0 x86_64${RESET}' ;;
        ifconfig) echo -e '${CYAN}eth0: inet 192.168.1.100${RESET}' ;;
        help) echo -e '${YELLOW}Available: ls, cat, pwd, whoami, uname, ifconfig, help, exit${RESET}' ;;
        *) echo -e '${RED}bash: \$cmd: command not found${RESET}' ;;
      esac
    done
    echo -e '${YELLOW}Session ended. Log saved: ${LOGFILE}${RESET}'
  "
  log_to_csv_html "$LOGFILE" "$IP"
}

check_port_available() {
  if lsof -i TCP:"$LISTEN_PORT" >/dev/null 2>&1; then
    echo -e "${RED}Port $LISTEN_PORT is already in use.${RESET}"
    exit 1
  fi
}

start_flask() {
  echo -e "${GREEN}Starting Flask log viewer...${RESET}"
  nohup python3 "$PROJECT_DIR/app.py" > "$FLASK_LOG" 2>&1 &
}

start_honeypot() {
  echo -e "${GREEN}Listening on port ${LISTEN_PORT}...${RESET}"
  while true; do
    socat TCP-LISTEN:$LISTEN_PORT,reuseaddr,fork EXEC:"bash -c 'handle_session \$SOCAT_PEERADDR'"
  done
}

# Silent setup flag for automation
if [[ "$1" == "--silent-setup" ]]; then
  install_dependencies
  setup_email
  configure_cronjob
  mkdir -p "$LOG_DIR"
  exit 0
fi

# Run setup
install_dependencies
setup_email
configure_cronjob
mkdir -p "$LOG_DIR"
ascii_banner
check_port_available
start_flask
start_honeypot
