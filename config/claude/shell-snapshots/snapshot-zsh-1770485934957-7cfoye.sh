# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
# Functions
# Shell Options
setopt nohashdirs
setopt login
# Aliases
alias -- run-help=man
alias -- which-command=whence
# Check for rg availability
if ! (unalias rg 2>/dev/null; command -v rg) >/dev/null 2>&1; then
  alias rg='/opt/homebrew/Caskroom/claude-code/2.1.34/claude --ripgrep'
fi
export PATH=/Users/henry/.jenv/shims\:/usr/local/bin\:/System/Cryptexes/App/usr/bin\:/usr/bin\:/bin\:/usr/sbin\:/sbin\:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin\:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin\:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin\:/opt/pmk/env/global/bin\:/Applications/Wireshark.app/Contents/MacOS\:/opt/homebrew/bin\:/Users/henry/.local/share/bob/nvim-bin\:/Users/henry/.rustup/toolchains/stable-aarch64-apple-darwin/bin\:/Users/henry/.local/bin\:/Users/henry/Applications/kitty.app/Contents/MacOS\:/Users/henry/.cache/zsh/antigen/bundles/zsh-users/zsh-syntax-highlighting\:/Users/henry/.cache/zsh/antigen/bundles/zsh-users/zsh-completions\:/Users/henry/.cache/zsh/antigen/bundles/zsh-users/zsh-autosuggestions\:/Users/henry/.cache/zsh/antigen/bundles/supercrabtree/k\:/Users/henry/.cache/zsh/antigen/bundles/1henrypage/zsh-treehouse-main
