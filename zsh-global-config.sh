#!/usr/bin/env bash
set -e

# --------------------------------------------------
# Mode parsing
# --------------------------------------------------
MODE="${1:-install}"

if [ "$MODE" != "install" ] && [ "$MODE" != "uninstall" ]; then
  echo "❌ Invalid mode: $MODE"
  echo ""
  echo "Usage:"
  echo "  bash zsh-global-config.sh install"
  echo "  bash zsh-global-config.sh uninstall"
  exit 1
fi

# --------------------------------------------------
# TTY-aware pause (human-friendly, automation-safe)
# --------------------------------------------------
pause() {
  local seconds=${1:-2}
  if [ -t 1 ]; then
    sleep "$seconds"
  fi
}

echo "🚀 Starting zsh global script ($MODE mode)"
pause 2

# --------------------------------------------------
# Detect package manager
# --------------------------------------------------
PM="unknown"

if command -v apt >/dev/null 2>&1; then
  PM="apt"
elif command -v dnf >/dev/null 2>&1; then
  PM="dnf"
elif command -v pacman >/dev/null 2>&1; then
  PM="pacman"
fi

echo "📦 Package manager detected: $PM"
pause 1

# --------------------------------------------------
# Handle unsupported distros
# --------------------------------------------------
if [ "$PM" = "unknown" ]; then
  echo ""
  echo "⚠️  Unsupported or unknown Linux distribution."
  echo ""
  echo "Supported:"
  echo "  • Ubuntu / Debian (apt)"
  echo "  • Fedora / RHEL (dnf)"
  echo "  • Arch / Manjaro (pacman)"
  echo ""
  echo "Please install manually:"
  echo "  zsh git curl"
  echo ""
  echo "Then re-run this script."
  echo ""
  exit 1
fi

# ==================================================
# INSTALL MODE
# ==================================================
if [ "$MODE" = "install" ]; then

 

  # ----------------------------------------------
  # Install base packages
  # ----------------------------------------------
  echo "📦 Installing base packages"
  pause 1

  if [ "$PM" = "apt" ]; then
    sudo apt update
    sudo apt install -y zsh git curl
  elif [ "$PM" = "dnf" ]; then
    sudo dnf makecache
    sudo dnf install -y zsh git curl util-linux-user
  elif [ "$PM" = "pacman" ]; then
    sudo pacman -Sy --noconfirm zsh git curl
  fi

  # ----------------------------------------------
  # Verify zsh
  # ----------------------------------------------
  if ! command -v zsh >/dev/null 2>&1; then
    echo ""
    echo "❌ zsh installation failed."
    echo "Please install zsh manually and re-run."
    echo ""
    exit 1
  fi

  echo "✅ zsh installed at $(which zsh)"
  pause 1

  # ----------------------------------------------
  # Install Oh My Zsh (NO shell switching)
  # ----------------------------------------------
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "✨ Installing Oh My Zsh"
    pause 1
    RUNZSH=no CHSH=no \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo "✔ Oh My Zsh already installed"
  fi

  pause 1

  # ----------------------------------------------
  # Install plugins
  # ----------------------------------------------
  echo "🔌 Installing zsh plugins"
  pause 1

  ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

  [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
    git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

  [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

  # ----------------------------------------------
  # Clean old custom block
  # ----------------------------------------------
  sed -i '/# >>> ZSH_CUSTOM_START >>>/,/# <<< ZSH_CUSTOM_END <<</d' ~/.zshrc 2>/dev/null || true

  # ----------------------------------------------
  # Write zsh configuration
  # ----------------------------------------------
  echo "📝 Writing zsh configuration"
  pause 1

  cat << 'EOF' >> ~/.zshrc

# >>> ZSH_CUSTOM_START >>>

# ---- History ----
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# ---- Autosuggestions ----
ZSH_AUTOSUGGEST_STRATEGY=(history)

# ---- Prompt (user@host + last 3 dirs) ----
PROMPT='%F{green}%n@%m%f %F{cyan}%3~%f
➜ '

# ---- Blank line between commands ----
precmd() {
  print ""
}

# <<< ZSH_CUSTOM_END <<<
EOF

  # Enable plugins
  sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

  # ----------------------------------------------
  # Final INSTALL message
  # ----------------------------------------------
  echo ""
  echo "✅ Zsh setup complete."
  pause 1
  echo ""
  echo "🔧 To make zsh your default shell:"
  echo ""
  echo "   👉 Replace <username> with your Linux username"
  echo ""
  echo "       chsh -s $(which zsh) <username>"
  echo ""
  pause 2
  echo "   💡 Example for you:"
  echo ""
  echo "       chsh -s $(which zsh) $USER"
  echo ""
  pause 2
  echo "➡️  Then logout and login again."
  echo ""
  echo "ℹ️  This step is manual to avoid PAM / SSH issues."
  pause 2

  exit 0
fi

# ==================================================
# UNINSTALL MODE
# ==================================================
if [ "$MODE" = "uninstall" ]; then
  echo "🧹 Starting zsh uninstall"
  pause 2

  # Remove Oh My Zsh
  if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "🗑️  Removing Oh My Zsh"
    rm -rf "$HOME/.oh-my-zsh"
  else
    echo "ℹ️  Oh My Zsh not found (skipping)"
  fi

  pause 1

  # Remove zsh config files
  echo "🗑️  Removing zsh config files"
  rm -f ~/.zshrc ~/.zprofile ~/.zshenv ~/.zlogin

  pause 1

  # Remove zsh package (optional but included)
  if command -v zsh >/dev/null 2>&1; then
    echo "📦 Removing zsh package"
    if [ "$PM" = "apt" ]; then
      sudo apt remove -y zsh
    elif [ "$PM" = "dnf" ]; then
      sudo dnf remove -y zsh
    elif [ "$PM" = "pacman" ]; then
      sudo pacman -Rns --noconfirm zsh
    fi
  else
    echo "ℹ️  zsh not installed (skipping)"
  fi

  pause 2

  # ----------------------------------------------
  # Final UNINSTALL message
  # ----------------------------------------------
  echo ""
  echo "✅ Zsh uninstall complete."
  echo ""
  echo "➡️  Your system is now using bash (or your previous shell)."
  echo ""
  echo "ℹ️  If you were previously using zsh:"
  echo "    - Logout and login again"
  echo "    - Or start bash manually with: bash"
  echo ""
  pause 2

  exit 0
fi
