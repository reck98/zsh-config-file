#!/usr/bin/env bash
set -e

############################################
# Mode parsing
############################################
MODE="${1:-install}"

if [[ "$MODE" != "install" && "$MODE" != "uninstall" && "$MODE" != "status" ]]; then
  echo "Invalid mode: $MODE"
  echo "Usage:"
  echo "  bootstrap-config.sh install"
  echo "  bootstrap-config.sh uninstall"
  echo "  bootstrap-config.sh status"
  exit 1
fi

############################################
# Safety checks
############################################
if [[ "$EUID" -eq 0 ]]; then
  echo "Do not run this script as root."
  echo "Run as a normal user with sudo access."
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required but not installed."
  exit 1
fi

############################################
# UX pause (TTY-aware)
############################################
pause() {
  [[ -t 1 ]] && sleep "${1:-1}"
}

############################################
# Detect package manager
############################################
PM="unknown"

if command -v apt >/dev/null 2>&1; then
  PM="apt"
elif command -v dnf >/dev/null 2>&1; then
  PM="dnf"
elif command -v pacman >/dev/null 2>&1; then
  PM="pacman"
fi

if [[ "$PM" == "unknown" ]]; then
  echo "Unsupported Linux distribution."
  exit 1
fi

echo "Package manager detected: $PM"
pause

############################################
# Helper functions
############################################
install_pkgs() {
  case "$PM" in
    apt)
      sudo apt update
      sudo apt install -y "$@"
      ;;
    dnf)
      sudo dnf install -y "$@"
      ;;
    pacman)
      sudo pacman -Sy --noconfirm "$@"
      ;;
  esac
}

remove_pkgs() {
  case "$PM" in
    apt)
      sudo apt remove -y "$@"
      ;;
    dnf)
      sudo dnf remove -y "$@"
      ;;
    pacman)
      sudo pacman -Rns --noconfirm "$@"
      ;;
  esac
}

############################################
# STATUS MODE
############################################
if [[ "$MODE" == "status" ]]; then
  echo "VM Bootstrap Status"
  echo "-------------------"

  command -v node >/dev/null && node -v || echo "Node.js: not installed"
  command -v pm2 >/dev/null && pm2 -v || echo "PM2: not installed"
  command -v docker >/dev/null && docker --version || echo "Docker: not installed"

  if command -v docker-compose >/dev/null; then
    docker-compose --version
  elif docker compose version >/dev/null 2>&1; then
    docker compose version
  else
    echo "Docker Compose: not installed"
  fi

  command -v cloudflared >/dev/null && cloudflared --version || echo "Cloudflared: not installed"
  command -v python3 >/dev/null && python3 --version || echo "Python: not installed"
  command -v gcc >/dev/null && gcc --version | head -n1 || echo "GCC: not installed"
  systemctl is-active nginx >/dev/null 2>&1 && echo "Nginx: active" || echo "Nginx: inactive or not installed"

  exit 0
fi

############################################
# INSTALL MODE
############################################
if [[ "$MODE" == "install" ]]; then
  echo "Starting VM bootstrap install"
  pause 2

  echo "Installing core system & build tools"
  install_pkgs curl wget git ca-certificates gnupg unzip zip tar \
               gcc g++ make pkg-config \
               iproute2 net-tools lsof htop rsync cron logrotate

  echo "Installing Python runtime"
  install_pkgs python3 python3-pip python3-venv

  echo "Installing Node.js LTS"
  if ! command -v node >/dev/null 2>&1; then
    if [[ "$PM" == "apt" ]]; then
      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
      sudo apt install -y nodejs
    elif [[ "$PM" == "dnf" ]]; then
      curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
      sudo dnf install -y nodejs
    elif [[ "$PM" == "pacman" ]]; then
      sudo pacman -Sy --noconfirm nodejs npm
    fi
  fi

  echo "Installing PM2"
  sudo npm install -g pm2 || true

  echo "Installing Docker (not started)"
  if ! command -v docker >/dev/null 2>&1; then
    if [[ "$PM" == "apt" ]]; then
      sudo apt install -y docker.io
    elif [[ "$PM" == "dnf" ]]; then
      sudo dnf install -y docker
    elif [[ "$PM" == "pacman" ]]; then
      sudo pacman -Sy --noconfirm docker
    fi
  fi

  echo "Installing Docker Compose (best available option)"
  if [[ "$PM" == "apt" ]]; then
    if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
      sudo apt install -y docker-compose-plugin
    elif apt-cache show docker-compose >/dev/null 2>&1; then
      sudo apt install -y docker-compose
    else
      echo "Docker Compose not available via apt, skipping"
    fi
  elif [[ "$PM" == "dnf" ]]; then
    sudo dnf install -y docker-compose || true
  elif [[ "$PM" == "pacman" ]]; then
    sudo pacman -Sy --noconfirm docker-compose || true
  fi

  echo "Adding user to docker group"
  sudo groupadd docker 2>/dev/null || true
  sudo usermod -aG docker "$USER"

  echo "Installing Nginx"
  install_pkgs nginx

  echo "Installing firewall tooling"
  if [[ "$PM" == "apt" ]]; then
    install_pkgs ufw
  elif [[ "$PM" == "dnf" ]]; then
    install_pkgs firewalld
  fi

  echo "Installing Cloudflare Tunnel (cloudflared)"
  if ! command -v cloudflared >/dev/null 2>&1; then
    if [[ "$PM" == "apt" ]]; then
      curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloudflare.gpg
      echo "deb [signed-by=/usr/share/keyrings/cloudflare.gpg] https://pkg.cloudflare.com/ $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/cloudflare.list
      sudo apt update
      sudo apt install -y cloudflared
    elif [[ "$PM" == "dnf" ]]; then
      sudo dnf install -y cloudflared
    elif [[ "$PM" == "pacman" ]]; then
      sudo pacman -Sy --noconfirm cloudflared
    fi
  fi

  echo ""
  echo "VM bootstrap completed successfully."
  echo ""
  echo "Important notes:"
  echo "- Docker is installed but NOT started."
  echo "- Docker Compose installed if available."
  echo "- Cloudflared is installed but NOT configured."
  echo "- Log out and log back in for docker group changes to apply."
  echo ""
  pause 2
  exit 0
fi

############################################
# UNINSTALL MODE (SAFE)
############################################
if [[ "$MODE" == "uninstall" ]]; then
  echo "Starting safe uninstall"
  pause 2

  echo "Removing PM2"
  sudo npm uninstall -g pm2 || true

  echo "Removing Node.js"
  remove_pkgs nodejs npm || true

  echo "Removing Docker & Compose"
  remove_pkgs docker docker.io docker-compose docker-compose-plugin || true

  echo "Removing Nginx"
  remove_pkgs nginx || true

  echo "Removing Cloudflared"
  remove_pkgs cloudflared || true

  echo "Removing build and ops tools"
  remove_pkgs gcc g++ make pkg-config htop lsof rsync net-tools iproute2 || true

  echo ""
  echo "Uninstall completed."
  echo "Log out and log back in to ensure a clean environment."
  pause 2
  exit 0
fi
