#!/bin/sh

# Dotfiles Install Script: 1henrypage
# Clone/update dotfiles and setup symlink
# Compatibility for macOS, arch will be supported in future.

# ---------- UTILITY --------------------
CYAN='\033[1;96m'
YELLOW='\033[1;93m'
RED='\033[1;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RESET='\033[0m'

make_banner() {
    text="$1"
    color="${2:-$CYAN}"
    len=$(echo "$text" | wc -c)
    line=""
    i=0
    while [ $i -lt $len ]; do
        line="$line─"
        i=$((i + 1))
    done
    printf "\n${color}╭${line}╮\n│ ${text} │\n╰${line}╯${RESET}\n"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

terminate() {
    make_banner "Installation failed. Terminating..." "$RED"
    exit 1
}

system_verify() {
    pkg="$1"
    required="$2"
    if ! command_exists "$pkg"; then
        if [ "$required" = "true" ]; then
            echo "${RED}Error:${RESET} $pkg is not installed"
            terminate
        else
            echo "${YELLOW}Warning:${RESET} $pkg is not installed"
        fi
    fi
}

# ------------- ARGS ---------------------------

DOTFILES_PROFILE="personal"
DRY_RUN="false"

print_help() {
    cat <<EOF
Usage: install.sh [--corporate|--personal] [--dry-run] [--help]

  --corporate   Work-machine profile: base packages/config only, HTTPS submodule
                bootstrap, no wholesale ~/.claude force-link, skips 'brew upgrade'.
  --personal    Personal-machine profile (default): base + personal packages/config.
  --dry-run     Print the resolved profile, Brewfile paths, installer scripts, and
                symlink set without changing anything.
  --help        Show this help and exit.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --corporate)
            DOTFILES_PROFILE="corporate"
            ;;
        --personal)
            DOTFILES_PROFILE="personal"
            ;;
        --dry-run)
            DRY_RUN="true"
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            echo "${RED}Error:${RESET} unknown flag: $1"
            print_help
            exit 1
            ;;
    esac
    shift
done

export DOTFILES_PROFILE

# ------------- FAILURE TRACKING ----------------

FAILURE_COUNT=0
FAILED_STEPS=""

record_failure() {
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    FAILED_STEPS="$FAILED_STEPS
  - $1"
    echo "${RED}Failed:${RESET} $1"
}

# ------------- VARS ---------------------------

ORIG_PWD=$(pwd)
SRC_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

cd "$SRC_DIR" || terminate

cleanup() {
  # Restore original wd
  cd "$ORIG_PWD" || exit 1
}

trap cleanup EXIT

# Load environment variables from zshenv
if [ -f "$SRC_DIR/config/zsh/.zshenv" ]; then
    . "$SRC_DIR/config/zsh/.zshenv" || terminate
fi

SYSTEM_TYPE=$(uname -s)
START_TIME=$(date +%s)
SYMLINK_FILE="${SYMLINK_FILE:-symlinks.yaml}"
DOTBOT_DIR="lib/dotbot"
DOTBOT_BIN="bin/dotbot"

# ---- PRE - SETUP
make_banner "1henrypage Setup" "$CYAN"
echo "Profile: $DOTFILES_PROFILE"

# Ensure XDG directories are set
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"

if [ "$DRY_RUN" = "true" ]; then
    echo ""
    echo "${YELLOW}Dry run - no changes will be made.${RESET}"

    echo ""
    echo "Brewfiles:"
    echo "  $SRC_DIR/scripts/installs/Brewfile"
    if [ "$DOTFILES_PROFILE" = "personal" ]; then
        echo "  $SRC_DIR/scripts/installs/Brewfile.personal"
    fi

    echo ""
    echo "macOS setup scripts:"
    for script in "$SRC_DIR"/scripts/macos/common/macos-*.sh; do
        [ -f "$script" ] && echo "  $script"
    done
    if [ "$DOTFILES_PROFILE" = "personal" ]; then
        for script in "$SRC_DIR"/scripts/macos/personal/macos-*.sh; do
            [ -f "$script" ] && echo "  $script"
        done
    fi

    echo ""
    echo "Cross-platform tool installers:"
    for script in "$SRC_DIR"/scripts/installs/tools/common/tool-*.sh; do
        [ -f "$script" ] && echo "  $script"
    done
    if [ "$DOTFILES_PROFILE" = "personal" ]; then
        for script in "$SRC_DIR"/scripts/installs/tools/personal/tool-*.sh; do
            [ -f "$script" ] && echo "  $script"
        done
    fi

    echo ""
    echo "Symlinks (dotbot dry run, DOTFILES_PROFILE=$DOTFILES_PROFILE):"
    chmod +x "$DOTBOT_DIR/$DOTBOT_BIN"
    "$DOTBOT_DIR/$DOTBOT_BIN" -d . -c "$SYMLINK_FILE" -n

    exit 0
fi

# Verify required commands
system_verify git true
system_verify zsh false
system_verify vim false
system_verify nvim false
system_verify tmux false

# ---- GIT IDENTITY ----
# Never hardcode name/email into the tracked .gitconfig; prompt once per machine into a
# gitignored, out-of-repo file that .gitconfig [include]s. Must read from /dev/tty since the
# README install path is `curl | bash`, so stdin is the pipe, not a terminal.
GIT_LOCAL_CONFIG="$HOME/.config/git/local"
if [ ! -f "$GIT_LOCAL_CONFIG" ]; then
    mkdir -p "$(dirname "$GIT_LOCAL_CONFIG")"
    if [ -r /dev/tty ]; then
        printf "Git user name: " > /dev/tty
        read -r git_user_name < /dev/tty
        printf "Git user email: " > /dev/tty
        read -r git_user_email < /dev/tty
        {
            echo "[user]"
            echo "    name = $git_user_name"
            echo "    email = $git_user_email"
        } > "$GIT_LOCAL_CONFIG"
    else
        echo "${YELLOW}Warning:${RESET} no controlling tty; writing a stub git identity to $GIT_LOCAL_CONFIG - edit it by hand."
        {
            echo "[user]"
            echo "    name = CHANGEME"
            echo "    email = CHANGEME"
        } > "$GIT_LOCAL_CONFIG"
        record_failure "git identity (no tty, wrote stub - edit $GIT_LOCAL_CONFIG)"
    fi
    if [ "$DOTFILES_PROFILE" = "corporate" ]; then
        {
            echo ""
            echo "[url \"https://github.com/\"]"
            echo "    insteadOf = git@github.com:"
        } >> "$GIT_LOCAL_CONFIG"
    fi
fi

echo "Updating dotfiles from remote..."
git pull origin main || terminate

if [ "$DOTFILES_PROFILE" = "corporate" ]; then
    # No personal SSH key on a corporate machine - rewrite submodule SSH URLs to HTTPS inline.
    # Can't rely on ~/.gitconfig's [include] here: it isn't linked until dotbot runs below.
    if ! git -c url."https://github.com/".insteadOf="git@github.com:" submodule update --recursive --remote --init; then
        record_failure "git submodule update (https)"
    fi
else
    if ! git submodule update --recursive --remote --init; then
        record_failure "git submodule update"
    fi
fi

echo "Setting up symlinks..."
chmod +x "$DOTBOT_DIR/$DOTBOT_BIN"
if ! "$DOTBOT_DIR/$DOTBOT_BIN" -d . -c "$SYMLINK_FILE"; then
    record_failure "dotbot symlinks"
fi

# --- Install Packages ---
if [ "$SYSTEM_TYPE" = "Darwin" ]; then
    # macOS Homebrew
    if ! command_exists brew; then
        echo "Installing Homebrew..."
        if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            record_failure "Homebrew install"
        fi
        export PATH=/opt/homebrew/bin:$PATH
    fi

    if command_exists brew; then
        echo "Updating Homebrew..."
        if ! brew update; then
            record_failure "brew update"
        fi

        # Corporate skips this: it upgrades every installed formula/cask, including anything IT
        # already put on the machine.
        if [ "$DOTFILES_PROFILE" = "personal" ]; then
            echo "Upgrading Homebrew packages..."
            if ! brew upgrade; then
                record_failure "brew upgrade"
            fi
        fi

        echo "Installing Homebrew packages (base)..."
        if ! brew bundle install --file="$SRC_DIR/scripts/installs/Brewfile"; then
            record_failure "brew bundle (base)"
        fi

        if [ "$DOTFILES_PROFILE" = "personal" ]; then
            echo "Installing Homebrew packages (personal)..."
            if ! brew bundle install --file="$SRC_DIR/scripts/installs/Brewfile.personal"; then
                record_failure "brew bundle (personal)"
            fi
        fi

        brew cleanup
    else
        record_failure "brew unavailable after install attempt"
    fi

    echo "Running MacOS specific setup scripts"
    macos_script="$SRC_DIR/scripts/macos/install.sh"
    chmod +x "$macos_script"
    if ! "$macos_script"; then
        record_failure "macOS setup scripts"
    fi

    # LaunchAgents are only symlinked by dotbot above, launchd never picks them up on its own.
    echo "Loading LaunchAgents..."
    load_launch_agents() {
        dir="$1"
        status=0
        for plist in "$dir"/*.plist; do
            [ -f "$plist" ] || continue
            name=$(basename "$plist")
            label=$(basename "$name" .plist)
            target="$HOME/Library/LaunchAgents/$name"
            if [ ! -e "$target" ]; then
                echo "${YELLOW}Warning:${RESET} $target not linked, skipping"
                status=1
                continue
            fi
            launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1
            if ! launchctl bootstrap "gui/$(id -u)" "$target"; then
                echo "${RED}Failed:${RESET} launchctl bootstrap $label"
                status=1
            fi
        done
        return $status
    }
    agents_status=0
    load_launch_agents "$SRC_DIR/config/macos/LaunchAgents/common" || agents_status=1
    if [ "$DOTFILES_PROFILE" = "personal" ]; then
        load_launch_agents "$SRC_DIR/config/macos/LaunchAgents/personal" || agents_status=1
    fi
    [ $agents_status -eq 0 ] || record_failure "LaunchAgents"
# debian is shit, setup arch
#elif [ -f "/etc/debian_version" ]; then
#    echo "Installing packages via apt..."
#    apt update && apt upgrade -y
#    if [ -f "$DOTFILES_DIR/scripts/installs/debian-apt.sh" ]; then
#        sh "$DOTFILES_DIR/scripts/installs/debian-apt.sh"
#    fi
fi

# --- POST INSTALL --- This is stuff that can't be installed via standard methods
# Ensure Rust default toolchain is stable (non-interactive)
if command_exists rustup; then
    echo "Setting Rust default toolchain to stable..."
    if ! rustup default stable; then
        record_failure "rustup default stable"
    fi
fi

# Cross-platform curl/script-based installs (tools with no brew/pacman formula)
echo "Running cross-platform tool installers..."
tools_script="$SRC_DIR/scripts/installs/tools/install.sh"
chmod +x "$tools_script"
if ! "$tools_script"; then
    record_failure "cross-platform tool installers"
fi

# --- Apply Preferences ---
echo "Applying ZSH, Vim, TMUX plugins..."
if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    if ! "$HOME/.tmux/plugins/tpm/bin/install_plugins"; then
        record_failure "tmux plugin install"
    fi
fi
if [ -x "$(command -v zsh)" ]; then
    if ! /bin/zsh -i -c "antigen update && antigen-apply"; then
        record_failure "antigen update"
    fi
fi

# --- Finishing Up ---
# source "$HOME/.zshenv" 2>/dev/null

elapsed=$(( $(date +%s) - START_TIME ))
if [ $elapsed -gt 60 ]; then
    elapsed="$((elapsed / 60)) minutes"
else
    elapsed="$elapsed seconds"
fi

if [ $FAILURE_COUNT -eq 0 ]; then
    make_banner "✨ Dotfiles configured successfully in $elapsed" "$GREEN"
    exit 0
else
    echo ""
    echo "${RED}$FAILURE_COUNT step(s) failed:${RESET}$FAILED_STEPS"
    make_banner "Dotfiles configured with failures in $elapsed" "$RED"
    exit 1
fi
