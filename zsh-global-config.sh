#!/usr/bin/env bash
set -e

MODE=${1:-install}
echo "🔧 Mode: $MODE"

# ------------------------------
# Detect package manager
# ------------------------------
if command -v apt >/dev/null 2>&1; then
  PM="apt"
elif command -v dnf >/dev/null 2>&1; then
  PM="dnf"
elif command -v pacman >/dev/null 2>&1; then
  PM="pacman"
else
  echo "❌ Unsupported package manager"
  exit 1
fi

# ------------------------------
# INSTALL MODE
# ------------------------------
if [ "$MODE" = "install" ]; then
  echo "📦 Installing base packages..."

  if [ "$PM" = "apt" ]; then
    sudo apt update
    sudo apt install -y zsh git curl
  elif [ "$PM" = "dnf" ]; then
    sudo dnf makecache
    sudo dnf install -y zsh git curl util-linux-user
  elif [ "$PM" = "pacman" ]; then
    sudo pacman -Sy --noconfirm zsh git curl
  fi

  # Verify zsh exists
  if ! command -v zsh >/dev/null 2>&1; then
    echo "❌ zsh installation failed"
    exit 1
  fi

  echo "✔ zsh found at $(which zsh)"

  # ------------------------------
  # Install Oh My Zsh safely
  # ------------------------------
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "✨ Installing Oh My Zsh..."
    RUNZSH=no CHSH=no \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  # ------------------------------
  # Install plugins
  # ------------------------------
  ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

  [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
    git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

  [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

  # ------------------------------
  # Clean old config block
  # ------------------------------
  sed -i '/# >>> ZSH_CUSTOM_START >>>/,/# <<< ZSH_CUSTOM_END <<</d' ~/.zshrc 2>/dev/null || true

  # ------------------------------
  # Write config
  # ------------------------------
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

# ---- Prompt ----
PROMPT='%F{green}%n@%m%f %F{cyan}%3~%f
➜ '

# ---- Blank line spacing ----
precmd() {
  print ""
}

# <<< ZSH_CUSTOM_END <<<
EOF

  # Enable plugins
  sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

  # ------------------------------
  # Switch shell LAST
  # ------------------------------
  if [ "$SHELL" != "$(which zsh)" ]; then
    echo "🔁 Setting zsh as default shell"
    chsh -s "$(which zsh)"
  fi

  echo "✅ Zsh installation complete."
  echo "➡️  Logout & open a new terminal."
  exit 0
fi

# ------------------------------
# UNINSTALL MODE
# ------------------------------
if [ "$MODE" = "uninstall" ]; then
  echo "🧼 Reverting to bash..."

  command -v bash >/dev/null 2>&1 && chsh -s "$(which bash)" || true

  rm -rf ~/.oh-my-zsh
  rm -f ~/.zshrc ~/.zprofile ~/.zshenv ~/.zlogin

  if command -v zsh >/dev/null 2>&1; then
    if [ "$PM" = "apt" ]; then
      sudo apt remove --purge -y zsh
    elif [ "$PM" = "dnf" ]; then
      sudo dnf remove -y zsh
    elif [ "$PM" = "pacman" ]; then
      sudo pacman -Rns --noconfirm zsh
    fi
  fi

  echo "✅ Zsh removed. Logout & reopen terminal."
  exit 0
fi

echo "❌ Unknown mode: $MODE"
echo "Usage: bash zsh-global-config.sh install | uninstall"
exit 1
