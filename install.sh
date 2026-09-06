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
    echo "${YELLOW}Dry run - no config will be changed.${RESET} (symlink preview is skipped if lib/dotbot isn't initialised yet - dry-run never fetches it.)"

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
    if [ -f "$DOTBOT_DIR/$DOTBOT_BIN" ] && [ -x "$DOTBOT_DIR/$DOTBOT_BIN" ]; then
        "$DOTBOT_DIR/$DOTBOT_BIN" -d . -c "$SYMLINK_FILE" -n
    elif [ -f "$DOTBOT_DIR/$DOTBOT_BIN" ]; then
        # --dry-run must be side-effect-free, so unlike the real run below, we do NOT
        # chmod it executable here - that's a filesystem permission change, which breaks
        # the "prints only, changes nothing" contract of --dry-run.
        echo "  ${YELLOW}Warning:${RESET} $DOTBOT_DIR/$DOTBOT_BIN exists but is not executable; skipping symlink preview."
        echo "  Run install.sh for real once, or 'chmod +x $DOTBOT_DIR/$DOTBOT_BIN' yourself, then re-run --dry-run."
    else
        # --dry-run must be side-effect-free, so unlike the real run below, we do NOT
        # `git submodule update` here - that's a network fetch + working-tree write, which
        # breaks the "prints only, changes nothing" contract of --dry-run.
        echo "  ${YELLOW}Warning:${RESET} $DOTBOT_DIR not initialised; skipping symlink preview (dry-run performs no git fetch)."
        echo "  Run 'git submodule update --init --recursive $DOTBOT_DIR' first to see the preview, or drop --dry-run."
    fi

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
if [ ! -f "$GIT_LOCAL_CONFIG" ] || grep -q CHANGEME "$GIT_LOCAL_CONFIG" 2>/dev/null; then
    mkdir -p "$(dirname "$GIT_LOCAL_CONFIG")"
    if [ -r /dev/tty ]; then
        git_user_name=""
        while [ -z "$git_user_name" ]; do
            printf "Git user name: " > /dev/tty
            read -r git_user_name < /dev/tty
        done
        git_user_email=""
        while [ -z "$git_user_email" ]; do
            printf "Git user email: " > /dev/tty
            read -r git_user_email < /dev/tty
        done
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
fi

if [ "$DOTFILES_PROFILE" = "corporate" ] && ! git config --file "$GIT_LOCAL_CONFIG" --get-all 'url.https://github.com/.insteadOf' 2>/dev/null | grep -qx 'git@github.com:'; then
    {
        echo ""
        echo "[url \"https://github.com/\"]"
        echo "    insteadOf = git@github.com:"
    } >> "$GIT_LOCAL_CONFIG"
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

if [ "$DOTFILES_PROFILE" = "corporate" ]; then
    for skill_dir in "$SRC_DIR"/config/skills/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        for skills_root in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
            collision="$skills_root/$skill_name"
            if [ -d "$collision" ] && [ ! -L "$collision" ]; then
                echo "${YELLOW}Note:${RESET} $collision already exists as a real directory (pre-provisioned)"
                echo "      - dotbot will fail on it. Resolve by hand, then re-run."
            fi
        done
    done
fi

# Corporate machines often have IT-managed ~/.zshenv / ~/.zshrc (proxy settings, internal
# registry auth). symlinks.yaml force-links both, which would otherwise destroy them with no
# backup. Move any real (non-symlink) file aside first, preserving its content - the repo's
# config/zsh/.zshenv and .zshrc each source the .local file back in as their last line, so
# nothing IT-managed is lost. Idempotent: once the target is already a symlink (i.e. this has
# already run), skip it.
#
# Must run immediately before dotbot below, after git pull / submodule update / etc above have
# already succeeded - so a failure in any of those earlier steps leaves the user's real
# zshenv/zshrc completely untouched instead of moved aside with no symlink yet in place to
# replace them. By this point config/zsh/.zshenv (and transitively ~/.zshenv.local) has already
# been sourced into this same shell process, so a function named terminate defined anywhere in
# that chain could silently shadow install.sh's own terminate(). The abort below therefore does
# not call terminate by name - it inlines the same banner and calls the exit builtin directly,
# which cannot be shadowed the way a same-named function can.
if [ "$DOTFILES_PROFILE" = "corporate" ]; then
    # Guard against moving the user's real zshenv/zshrc aside when dotbot cannot run to put the
    # replacement symlinks back. lib/dotbot is a submodule RUNME.sh's initial clone never fetches
    # (non-recursive) - it only shows up once the submodule update above succeeds. That update is
    # non-fatal on failure (record_failure only), so a network/submodule failure there would
    # otherwise fall straight through into the mv loop below with no dotbot binary on disk to
    # replace what it moves. Same shadow-proof abort as below: inline banner + exit, not terminate.
    if [ ! -f "$DOTBOT_DIR/$DOTBOT_BIN" ]; then
        echo "${RED}Error:${RESET} $DOTBOT_DIR/$DOTBOT_BIN is missing - dotbot cannot run yet."
        echo "         This almost always means the 'git submodule update' step above failed (network"
        echo "         issue, HTTPS rewrite problem, etc.) and the lib/dotbot submodule was never fetched."
        echo "         Refusing to move your existing ~/.zshenv / ~/.zshrc aside, since dotbot wouldn't be"
        echo "         able to symlink their replacements back in - your existing files are untouched."
        echo "         Resolve the submodule fetch (e.g. re-run install.sh --corporate, or run"
        echo "         'git submodule update --init --recursive $DOTBOT_DIR' by hand), then re-run install.sh --corporate."
        make_banner "Installation failed. Terminating..." "$RED"
        exit 1
    fi

    PRESERVE_FAILED="false"
    for rc in zshenv zshrc; do
        target="$HOME/.$rc"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            if [ -e "${target}.local" ] || [ -L "${target}.local" ]; then
                echo "${RED}Warning:${RESET} ${target}.local already exists - refusing to overwrite it with $target."
                echo "         Resolve the two by hand, then re-run."
                record_failure "preserve $target (${target}.local already exists)"
                PRESERVE_FAILED="true"
                continue
            fi
            echo "${YELLOW}Note:${RESET} preserving pre-existing $target as ${target}.local"
            if ! mv "$target" "${target}.local"; then
                echo "${RED}Warning:${RESET} failed to move $target to ${target}.local."
                record_failure "preserve $target (mv failed)"
                PRESERVE_FAILED="true"
            fi
        fi
    done
    if [ "$PRESERVE_FAILED" = "true" ]; then
        echo "${RED}Error:${RESET} could not safely preserve your existing zshenv/zshrc - aborting before dotbot runs."
        echo "         Any file already reported above as preserved to a .local path is safe and untouched there."
        echo "         Only the failure(s) listed above still need manual resolution - resolve them by hand, then re-run install.sh --corporate."
        make_banner "Installation failed. Terminating..." "$RED"
        exit 1
    fi
fi

echo "Setting up symlinks..."
chmod +x "$DOTBOT_DIR/$DOTBOT_BIN"
if ! "$DOTBOT_DIR/$DOTBOT_BIN" -d . -c "$SYMLINK_FILE"; then
    record_failure "dotbot symlinks"
fi

if [ "$DOTFILES_PROFILE" = "corporate" ] && [ -e "$HOME/.claude/CLAUDE.md" ] && [ ! -L "$HOME/.claude/CLAUDE.md" ]; then
    echo "${YELLOW}Note:${RESET} ~/.claude/CLAUDE.md is pre-provisioned - not overwriting."
    echo "      To pull in the dotfiles rules, append to it:  @$SRC_DIR/config/claude/CLAUDE.md"
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

        # Homebrew 6 refuses to load formulae/casks from third-party taps until they are
        # explicitly trusted, so every fully-qualified `owner/tap/pkg` entry in a Brewfile needs
        # its tap trusted first or `brew bundle` hard-fails on it. `brew trust` itself only
        # exists on Homebrew >= 6; on older brews the taps load unconditionally and the command
        # is absent, so skip it rather than recording a bogus failure.
        if brew commands 2>/dev/null | grep -qx trust; then
            echo "Trusting third-party Homebrew taps..."
            trust_taps="felixkratz/formulae nikitabobko/tap"
            if [ "$DOTFILES_PROFILE" = "personal" ]; then
                trust_taps="$trust_taps omnigent-ai/tap anomalyco/tap"
            fi
            for tap in $trust_taps; do
                if ! brew trust --tap "$tap"; then
                    record_failure "brew trust $tap"
                fi
            done
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
            label=$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist" 2>/dev/null)
            [ -n "$label" ] || label=$(basename "$name" .plist)
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
