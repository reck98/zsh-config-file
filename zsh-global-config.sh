#!/usr/bin/env bash
set -e

MODE=${1:-install}

echo "🔧 Mode: $MODE"

# ------------------------------
# Detect package manager
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
  echo "📦 Installing base packages..."
  $PM_UPDATE
  $PM_INSTALL zsh git curl util-linux-user || true

  # HARD CHECK — this is the key fix
  if ! command -v zsh >/dev/null 2>&1; then
    echo "❌ zsh installation failed or not in PATH"
    exit 1
  fi

  echo "✔ zsh installed at $(which zsh)"

  # Install Oh My Zsh WITHOUT shell switching
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "✨ Installing Oh My Zsh (no shell switch)..."
    RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  # Plugins
  ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

  [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
    git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

  [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

  # Clean old config
  sed -i '/# >>> ZSH_CUSTOM_START >>>/,/# <<< ZSH_CUSTOM_END <<</d' ~/.zshrc 2>/dev/null || true

  # Write config
  cat << 'EOF' >> ~/.zshrc

# >>> ZSH_CUSTOM_START >>>

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS

ZSH_AUTOSUGGEST_STRATEGY=(history)

PROMPT='%F{green}%n@%m%f %F{cyan}%3~%f
➜ '

precmd() {
  print ""
}

# <<< ZSH_CUSTOM_END <<<
EOF

  # Enable plugins
  sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

  # Switch shell LAST (safe)
  if [ "$SHELL" != "$(which zsh)" ]; then
    echo "🔁 Setting zsh as default shell"
    chsh -s "$(which zsh)"
  fi

  echo "✅ Install complete. Logout & reopen terminal."
  exit 0
fi

# ------------------------------
# UNINSTALL MODE
# ------------------------------
if [ "$MODE" = "uninstall" ]; then
  echo "🧼 Reverting to bash..."

  chsh -s "$(which bash)" || true

  rm -rf ~/.oh-my-zsh
  rm -f ~/.zshrc ~/.zprofile ~/.zshenv ~/.zlogin

  if command -v zsh >/dev/null 2>&1; then
    $PM_REMOVE zsh || true
  fi

  echo "✅ Uninstall complete. Logout & reopen terminal."
  exit 0
fi

echo "❌ Unknown mode"
exit 1
