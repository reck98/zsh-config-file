#!/usr/bin/env bash
set -e

MODE=${1:-install}

echo "🔧 Mode: $MODE"

# ------------------------------
# Detect OS / Package Manager
# ------------------------------
if command -v apt >/dev/null 2>&1; then
  PM_UPDATE="sudo apt update"
  PM_INSTALL="sudo apt install -y"
  PM_REMOVE="sudo apt remove --purge -y"
elif command -v dnf >/dev/null 2>&1; then
  PM_UPDATE="sudo dnf makecache"
  PM_INSTALL="sudo dnf install -y"
  PM_REMOVE="sudo dnf remove -y"
elif command -v pacman >/dev/null 2>&1; then
  PM_UPDATE="sudo pacman -Sy"
  PM_INSTALL="sudo pacman -Sy --noconfirm"
  PM_REMOVE="sudo pacman -Rns --noconfirm"
else
  echo "❌ Unsupported package manager"
  exit 1
fi

# ------------------------------
# INSTALL MODE
# ------------------------------
if [ "$MODE" = "install" ]; then
  echo "📦 Installing dependencies..."
  $PM_UPDATE
  $PM_INSTALL zsh git curl util-linux-user || true

  # Install Oh My Zsh (only if missing)
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "✨ Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi

  # Plugins
  ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

  [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
  git clone https://github.com/zsh-users/zsh-autosuggestions \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

  [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

  # Clean old config block
  sed -i '/# >>> ZSH_CUSTOM_START >>>/,/# <<< ZSH_CUSTOM_END <<</d' ~/.zshrc 2>/dev/null || true

  # Append config
  cat << 'EOF' >> ~/.zshrc

# >>> ZSH_CUSTOM_START >>>

# ---- History ----
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS

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

  # Enable plugins safely
  sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

  # Switch shell ONLY if zsh exists
  if command -v zsh >/dev/null 2>&1; then
    if [ "$SHELL" != "$(which zsh)" ]; then
      echo "🔁 Switching default shell to zsh"
      chsh -s "$(which zsh)"
    fi
  fi

  echo "✅ Zsh installed safely. Logout & reopen terminal."
  exit 0
fi

# ------------------------------
# UNINSTALL MODE
# ------------------------------
if [ "$MODE" = "uninstall" ]; then
  echo "🧼 Reverting to bash..."

  # Switch back to bash FIRST
  if command -v bash >/dev/null 2>&1; then
    chsh -s "$(which bash)" || true
  fi

  # Remove zsh configs
  rm -rf ~/.oh-my-zsh
  rm -f ~/.zshrc ~/.zprofile ~/.zshenv ~/.zlogin

  # Remove zsh package (only if installed)
  if command -v zsh >/dev/null 2>&1; then
    $PM_REMOVE zsh || true
  fi

  echo "✅ Zsh fully removed. Logout & reopen terminal."
  exit 0
fi

echo "❌ Unknown mode: $MODE"
echo "Usage: bash zsh-global-config.sh install | uninstall"
exit 1
