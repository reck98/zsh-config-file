#!/usr/bin/env bash
set -e

echo "🔍 Detecting system..."

# ------------------------------
# Detect OS / Distro
# ------------------------------
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "❌ Cannot detect OS"
  exit 1
fi

echo "🖥️  OS detected: $OS"

# ------------------------------
# Detect Package Manager
# ------------------------------
if command -v apt >/dev/null 2>&1; then
  PKG_INSTALL="sudo apt install -y"
  PKG_UPDATE="sudo apt update"
elif command -v dnf >/dev/null 2>&1; then
  PKG_INSTALL="sudo dnf install -y"
  PKG_UPDATE="sudo dnf makecache"
elif command -v pacman >/dev/null 2>&1; then
  PKG_INSTALL="sudo pacman -Sy --noconfirm"
  PKG_UPDATE="sudo pacman -Sy"
else
  echo "❌ Unsupported package manager"
  exit 1
fi

# ------------------------------
# Install Base Dependencies
# ------------------------------
echo "📦 Installing base packages..."
$PKG_UPDATE
$PKG_INSTALL zsh git curl util-linux-user || true

# ------------------------------
# Install Oh My Zsh (if missing)
# ------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "✨ Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "✔ Oh My Zsh already installed"
fi

# ------------------------------
# Install Plugins (safe)
# ------------------------------
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
git clone https://github.com/zsh-users/zsh-autosuggestions \
"$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
git clone https://github.com/zsh-users/zsh-syntax-highlighting \
"$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# ------------------------------
# Clean Old Custom Config Block
# ------------------------------
sed -i '/# >>> ZSH_CUSTOM_START >>>/,/# <<< ZSH_CUSTOM_END <<</d' ~/.zshrc 2>/dev/null || true

# ------------------------------
# Append Custom Zsh Config
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

# ---- Prompt (user@host + last 3 dirs) ----
PROMPT='%F{green}%n@%m%f %F{cyan}%3~%f
➜ '

# ---- Blank line between commands ----
precmd() {
  print ""
}

# <<< ZSH_CUSTOM_END <<<
EOF

# ------------------------------
# Enable Plugins in Oh My Zsh
# ------------------------------
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

# ------------------------------
# Switch Default Shell to Zsh
# ------------------------------
if [ "$SHELL" != "$(which zsh)" ]; then
  echo "🔁 Setting zsh as default shell..."
  chsh -s "$(which zsh)"
fi

# ------------------------------
# Detect WSL (info only)
# ------------------------------
if grep -qi microsoft /proc/version; then
  echo "🧠 WSL detected"
fi

echo "✅ Zsh bootstrap complete."
echo "➡️  Logout and open a new terminal."
