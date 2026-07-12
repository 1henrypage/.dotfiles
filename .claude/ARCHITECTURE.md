# ARCHITECTURE — deep dive

Read on demand. Companion to [CLAUDE.md](CLAUDE.md); that file is the lean summary that loads
every session. This one carries the line-referenced detail: bootstrap trace, symlink map,
cross-tool coupling, and the latent bugs. Line numbers are accurate as of writing but drift with
edits — treat them as pointers and re-open the file to confirm.

---

## 1. End-to-end bootstrap trace

A clean machine comes up like this:

1. **`RUNME.sh`** (the only file curl-piped; it *does* have `set -e`, unlike `install.sh`):
   - `curl … prerequisites.sh | bash` — pulls `scripts/installs/prerequisites.sh` **fresh from
     `main`** every run (not the local copy).
   - On macOS, `prerequisites.sh` runs `install_macos()` → `xcode-select --install` and then
     `exit 0` immediately. That GUI installer is **fire-and-forget** — the script does not wait
     for the Command Line Tools to finish. On a truly clean Mac (no `git` yet) this **races** the
     `git clone` that follows.
   - `git clone` the repo over **SSH** (`git@github.com:1henrypage/.dotfiles.git`) into
     `~/.dotfiles`. **No `--recursive`**, so submodules are empty until `install.sh` inits them.
   - `cd ~/.dotfiles && ./install.sh`.

2. **`install.sh`** (`#!/bin/sh`, **no `set -e`** — read [CLAUDE.md](CLAUDE.md) footguns):
   - Sources `config/zsh/.zshenv` early (`install.sh:65-67`) — *before* the tools that file's
     PATH lines reference (rustup, bob, brew) necessarily exist. See §6 for the unconditional
     `rustup` line that errors here on a fresh box.
   - `system_verify` hard-requires only **`git`** (`install.sh:83`); `zsh`/`vim`/`nvim`/`tmux`
     are `false` (warn-only).
   - `git pull origin main` (`:90`) then `git submodule update --recursive --remote --init`
     (`:91`) — the `--remote` drift, see [CLAUDE.md](CLAUDE.md) and §7.
   - dotbot: `"$DOTBOT_DIR/$DOTBOT_BIN" -d . -c "$SYMLINK_FILE"` (`:95`). `SYMLINK_FILE` defaults
     to `symlinks.yaml` but is overridable via env (`:71` — `SYMLINK_FILE="${SYMLINK_FILE:-symlinks.yaml}"`).
   - macOS only (`SYSTEM_TYPE = Darwin`): install Homebrew if missing, then
     `brew update && brew upgrade && brew bundle --global --verbose && brew cleanup`
     (`:106-110`). `brew upgrade` touches **everything** installed. `--global` reads `~/.Brewfile`
     (the symlink, see §2).
   - `scripts/macos/install.sh` (`:116-117`) — globs `macos-*.sh` in that dir and runs each with
     `sh "$script"`, **regardless of git tracking or the script's own `#!/usr/bin/env bash`
     shebang**. So the untracked WIP `macos-openwhispr.sh` and the `bash`-shebang'd
     `macos-power.sh` both get executed under `sh`.
   - Post-install (runs on all platforms, after the Darwin block): `rustup default stable` if
     rustup exists (`:129-132`); then `scripts/installs/tools/install.sh` — the cross-platform
     twin of the `scripts/macos/` glob-runner, globbing `tool-*.sh` (currently `tool-neovim.sh`,
     which is the bob/`v0.11.5` install, and `tool-no-mistakes.sh`) and running each under `sh`;
     `/bin/zsh -i -c "antigen update && antigen-apply"` (`:141`).
   - Always prints the green **"✨ Dotfiles configured successfully"** banner and `exit 0`
     (`:153-154`) — even if earlier steps failed.

---

## 2. Symlink map (`symlinks.yaml`)

Config is symlinked **piecemeal**, not as one big `config/` → `~/.config` link. `link` defaults:
`create: true`, `relink: true` (`:2-4`). A global `clean: ['~', '${XDG_CONFIG_HOME}']` (`:6`)
removes dangling links on every run.

| Target | Source | Notes |
|---|---|---|
| `~/.zshenv` | `config/zsh/.zshenv` | **`force: true`** (`:12`) |
| `~/.zshrc` | `config/zsh/.zshrc` | **`force: true`** (`:13`) |
| `~/.tmux/plugins/tpm` | `lib/tpm` | submodule |
| `~/.tmux.conf` | `config/tmux/tmux.conf` | |
| `~/.claude` | `config/claude` | **`force: true`** (`:16`) — live global Claude Code state |
| `~/.claude/skills` | `config/skills` | **`force: true`** — Claude Code skills |
| `~/.agents/skills` | `config/skills` | **`force: true`** — Codex CLI personal skills; same physical files as above |
| `${XDG_CONFIG_HOME}/zsh` | `config/zsh` | |
| `${XDG_CONFIG_HOME}/nvim` | `config/nvim` | submodule |
| `${XDG_CONFIG_HOME}/kitty` | `config/kitty` | |
| `${XDG_CONFIG_HOME}/karabiner` | `config/karabiner` | |
| `${XDG_CONFIG_HOME}/starship.toml` | `config/general/starship.toml` | |
| `${HOME}/.gitconfig` | `config/general/.gitconfig` | |
| `${XDG_CONFIG_HOME}/.gitignore_global` | `config/general/.gitignore_global` | |
| `~/.Brewfile` | `scripts/installs/Brewfile` | gated `if: [ \`uname\` = Darwin ]` (`:31-33`) |
| `~/Library/LaunchAgents/` | `config/macos/LaunchAgents/*` | Darwin-gated **`glob: true`** (`:34-37`) |

`create:` also makes `~/Downloads`, `~/Documents`, `~/Applications` if absent (`:40-43`).
`~/Applications` matters because the Brewfile sets `cask_args appdir: '~/Applications'`
(`Brewfile:2`, which also sets `require_sha: true`), so casks and `macos-openwhispr.sh` install
there rather than `/Applications`.

The commented-out `yabairc` block (`:28-30`) is dormant.

---

## 3. Cross-tool coupling (the non-obvious "why")

These configs are entangled; changing one in isolation breaks another.

- **kitty *is* the tmux frontend.** `kitty.conf:89` `shell tmux` → every kitty window launches
  straight into tmux (no login shell). Native kitty tab/window keys are `no_op`'d
  (`kitty.conf:72-83`: `cmd+t`, `cmd+shift+[`/`]`, `cmd+1`..`cmd+9`) so **all** window/tab
  management is tmux's, per the config's own "Force windows/tabs through tmux" comment. The tab
  bar is hidden (`tab_bar_style hidden`).
- **Prefix is `C-a`** (`tmux.conf:33`, `C-b` unbound `:31`). Prefixless `M-1`..`M-9` jump windows
  (`tmux.conf:81-89`). Those Alt chords only reach tmux through a **double Option→Alt remap**:
  Karabiner rewrites `left_option → left_alt` at the system level (`config/karabiner/karabiner.json`
  ~L13-14) **and** kitty sets `macos_option_as_alt left` (`kitty.conf:9`).
- **Seamless pane nav across tmux ⇄ nvim** is hand-rolled on the tmux side and plugin-driven on
  the nvim side: `tmux.conf` defines `is_vim` (`:44-45`) and forwards `C-h/j/k/l` / `M-h/j/k/l`
  conditionally (`:47-57`), while nvim uses `aserowy/tmux.nvim` (`plugins/tmux.lua`). The **resize
  step of 5** is duplicated by hand on both sides: `resize-pane … 5` (`tmux.conf:54-57,65-68`) and
  `resize_step_x/y = 5` (`plugins/tmux.lua:7`). Change one, change the other.
- **Theming is Tokyo Night everywhere but maintained per-tool**, so exact shades differ by design
  (not a bug):
  - kitty (`kitty.conf`) and starship (`starship.toml`) share an **identical hardcoded hex
    palette** (`#1d2230` bg, `#e3e5e5` fg, `#769ff0`, `#a3aed2`, `#394260`, `#212736`, …).
  - tmux themes via the **`janoamaral/tokyo-night-tmux` plugin** with `_theme night`
    (`tmux.conf:131-142`) — its own palette, not the kitty hex.
  - nvim uses **tokyonight _storm_** (transparent) per `config/nvim/CLAUDE.md` — a different
    Tokyo Night variant again.
- **A Nerd Font is assumed.** kitty sets `font_family FantasqueSansM Nerd Font Mono`
  (`kitty.conf:68`); starship, the sesh picker, and nvim all render glyphs that require it.
- **`EDITOR`/`VISUAL` = `vim`** (`.zshenv:13-14`), but git's `core.editor = nvim`
  (`.gitconfig:13`). Different editors for shell vs git, and there's no `vim`→`nvim` bridging
  alias.
- **tmux PATH + plugin path:** kitty's `shell tmux` gives the tmux server a truncated PATH (no
  `/opt/homebrew/bin`, no `~/.local/bin`) and none of `.zshenv`'s exports, and `run-shell` itself
  uses `/bin/sh`. Two `run-shell` lines at the **top** of `tmux.conf` (`:5-6`) repair this at load
  by pulling the real login `PATH` **and** `TMUX_PLUGIN_MANAGER_PATH` from a login `zsh`
  (`/bin/zsh -lc`), keeping `.zshenv` the single source of truth. Both invoke tmux by its
  **absolute** path (`/opt/homebrew/bin/tmux`) because tmux isn't on the truncated PATH yet — an
  earlier WIP used bare `tmux`, which resolved to nothing and returned 127, so PATH was never set
  and tpm (loaded at `:148`) failed with the plugin path unset and never bound `prefix + I`. These
  lines must stay above the tpm loader so tpm sees a correct env. Downstream: `run-shell`/popup
  bindings (sesh, lazygit, `bind L`, `fd`) also see jenv/rustup/bob/`~/.local/bin`.

---

## 4. zsh specifics

Load order (interactive): `.zshenv` (always) → `.zshrc` sources `aliases/*.zsh`, then
`setup-antigen.zsh`, then `lib/*.zsh` (`.zshrc:10-23`).

- **`.zshrc` refuses non-interactive execution.** `if [[ $- != *i* ]]; then … return 1; fi`
  (`.zshrc:4-7`). Sourcing `.zshrc` from a script yields nothing. `.zshenv` has no such guard and
  always runs — that's why `install.sh` sources `.zshenv`, and why `install.sh:141` uses
  `zsh -i -c` to force interactivity for the antigen step.
- **antigen** installs to `~/.cache/zsh/antigen` (`ADOTDIR` in `.zshenv:19`, consumed by
  `setup-antigen.zsh:5`). Bundles: zsh-syntax-highlighting, zsh-completions, zsh-autosuggestions,
  `supercrabtree/k`, and **`1henrypage/sh-treehouse`** (`setup-antigen.zsh:22-26`).
- **`wt` (git-worktree helper) comes from `sh-treehouse`**, loaded via antigen — i.e. *before*
  `lib/completion.zsh` runs `compinit`, which the plugin relies on for its completions.
- **Space auto-expands aliases inline** (globalias): `lib/expansions.zsh` binds Space to a
  `globalias` widget that runs `_expand_alias` (`:4-19`). Typing an alias + Space rewrites it in
  place; `Ctrl-Space` inserts a literal space.
- **History lives in the cache dir**: `HISTFILE="${XDG_CACHE_HOME}/zsh/history"`
  (`lib/history.zsh:4`), with `share_history`/`inc_append_history` on.
- **Trailing `eval`s are unguarded**: `.zshrc:25-27` runs `zoxide`, `starship`, and `jenv` init
  with no `command -v` guard — a missing binary errors on shell start.

---

## 5. `config/claude/` internals (the live global `~/.claude`)

**Tracked** (7 files — `git ls-files config/claude`): `.gitignore`, `CLAUDE.md`, `WRITING.md`,
`settings.json`, `hooks/notify.sh`, `commands/.gitkeep`. `skills/` is **no longer a physical
directory here** — skills moved to the tool-neutral `config/skills/` (`labrador/` and
`no-mistakes/`), symlinked in via two new `symlinks.yaml` entries: `~/.claude/skills` and
`~/.agents/skills` (Codex CLI's personal skills path). One physical copy on disk, shared across
both tools. Verify with `git ls-files config/claude` and `git ls-files config/skills` rather than
trusting a stale doc.

Notable `settings.json`:
- `env`: `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`, `CLAUDE_CODE_DISABLE_1M_CONTEXT=1`,
  `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`, `CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-5`,
  `ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-8`.
- `model: opus`, `effortLevel: high`, `showClearContextOnPlanAccept: true`,
  `skipDangerousModePermissionPrompt: true`, `enabledPlugins: { lua-lsp@claude-plugins-official }`.
- **`hooks: {}`** — so `hooks/notify.sh` (a cross-platform desktop-notification script) is
  **orphaned**: tracked and symlinked in, but wired to nothing.

**Two-layer gitignore** keeps runtime state out of git:
- root `.gitignore:6-9` — `config/claude/daemon/`, `config/claude/image-cache/`,
  `config/claude/jobs/`, `config/claude/.last-cleanup`.
- `config/claude/.gitignore` — `cache/`, `projects/`, `tasks/`, `todos/`, `history.jsonl`,
  `shell-snapshots/`, `telemetry/`, `backups/`, `plans/`, `plugins/`, and more.

Because `~/.claude` is a `force: true` symlink to this dir, that runtime state accumulates **in
the working tree**. Don't `git add -A` here — you'll try to commit live session data.

---

## 6. Known quirks & latent bugs

Documented so an agent neither trusts them nor "helpfully" fixes working things. **Verify before
relying; fixing them is out of scope for a docs task** — flag to the user instead.

- **`.zshenv` PATH line is fragile.** `.zshenv:52` unconditionally runs
  `rustup show active-toolchain` inside a PATH assignment — it **errors on a machine without
  rustup** (the guarded variant right below is commented out, `:54-55`). `.zshenv` also uses
  bash-only `[[ … ]]` (`:32,39,46,58`), which breaks if a Linux `/bin/sh` is `dash`.
- **zsh alias bugs** (`config/zsh/aliases/general.zsh`):
  - `top-history` (`:94`) is broken by nested single quotes — the `awk '{print $2}'` closes the
    alias string early.
  - `dotfiles` / `dots` (`:115-116`) point at `${DOTFILES_DIR:-$HOME/Documents/config/dotfiles}` —
    but `DOTFILES_DIR` is never set and the repo actually lives at `~/.dotfiles`, so the alias
    targets a nonexistent path.
  - `fd` (`:89`) is only aliased to `find … -type d` when the real `fd` binary is **absent**
    (`(( $+commands[fd] )) || alias …`).
- **completion.zsh oddities.** `if [ -f $zsh_dump_file ]` (`:55`) guards on an **undefined**
  variable (the real one is `$zcompdump`, `:52`), so that `compinit` branch never fires. And
  `extendedglob` is enabled at `:46` but **`unsetopt extendedglob` at `:66`** leaves it globally
  **off** after the file loads.
- **Karabiner writes backups into the repo.** `config/karabiner/automatic_backups/*.json` are
  written by Karabiner itself and are **tracked** (there's no `.gitignore` there), so fresh
  backups periodically appear as untracked files in `git status`.
- **LaunchAgents are symlinked but never loaded.** `config/macos/LaunchAgents/com.rclone.zotero.plist`
  is symlinked into `~/Library/LaunchAgents/` (`symlinks.yaml:34-37`) but **no script runs
  `launchctl load`** — grep confirms `launchctl` appears nowhere in the repo. The agent isn't
  activated by the install.

---

## 7. Current WIP snapshot

At investigation time the working tree carried a batch of **uncommitted** changes that read as
one coherent in-progress feature: the tmux/sesh/lazygit/fzf/`fd` popup workflow (`tmux.conf`),
`kitty.conf`, the `Brewfile`, and a new untracked `scripts/macos/macos-openwhispr.sh`. Concretely
this WIP **replaces** the committed `tmux.conf` PATH hardcode
(`set-environment -g PATH "/opt/homebrew/bin:/bin:/usr/bin"`) with the two `run-shell` login-`zsh`
captures described in §3 (PATH + `TMUX_PLUGIN_MANAGER_PATH`, absolute-`tmux`), and fixes the
`install.sh:140` tpm auto-install line — the old `[ -f "$XDG_DATA_HOME/tmux/tpm" ]` test hit a
path that never exists (tpm lives at `~/.tmux/plugins/tpm`, a directory), so plugins never
auto-installed; it now tests/runs `~/.tmux/plugins/tpm/bin/install_plugins` directly.

Consequences while unstaged:
- `git blame` / `git log` on `tmux.conf` and `kitty.conf` reflect the **old** committed state,
  not what's on disk — misleading if you reason from history alone.
- The submodule pointers `lib/dotbot` / `lib/tpm` show `-dirty` (`m` in `git status`) purely from
  nested-submodule drift (§ below), independent of this feature work.

This may already be committed by the time you read it — reconcile against `git status` /
`git diff` before trusting the above.

### Submodule drift, precisely

`git diff --submodule=short` shows `lib/dotbot` and `lib/tpm` as `…-dirty`; drilling in,
`git -C lib/dotbot status` is ` M lib/pyyaml` and `git -C lib/tpm status` is ` M lib/tmux-test`.
So the dirtiness is entirely their **nested** submodules being fast-forwarded by
`--recursive --remote` (`install.sh:91`), not any local edit. `config/nvim` (the user's fork)
tracks clean.

---

## 8. Regenerating the structure

The previous `CLAUDE.md` pasted a fixed `tree` that went ~5 months stale (it omitted
`config/claude/`, `config/macos/`, `scripts/macos/macos-power.sh`, and the WIP
`macos-openwhispr.sh`). **Don't** re-paste a static tree. When you need the layout, generate it
live:

```sh
git ls-files                        # tracked files only (authoritative)
git ls-files | tree --fromfile      # if tree(1) is installed
git submodule status                # submodule SHAs + drift markers
```

Untracked-but-present files (e.g. a fresh WIP script, Karabiner backups) won't show in
`git ls-files` — cross-check with `git status` when completeness matters.
