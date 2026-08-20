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
   - Scans `"$@"` for `--corporate` (`RUNME.sh:15-20`) and picks the clone URL accordingly:
     SSH (`git@github.com:1henrypage/.dotfiles.git`) by default, HTTPS
     (`https://github.com/1henrypage/.dotfiles.git`) under `--corporate` — there's no personal SSH
     key on a corporate machine. **No `--recursive`**, so submodules are empty until `install.sh`
     inits them.
   - `cd ~/.dotfiles && ./install.sh "$@"` (`:47`) — forwards every flag through.

2. **`install.sh`** (`#!/bin/sh`, **no `set -e`** — read [CLAUDE.md](CLAUDE.md) footguns):
   - Arg loop (`:68-90`) resolves `--corporate` / `--personal` (default) / `--dry-run` / `--help`
     into `DOTFILES_PROFILE` and `export`s it (`:92`) — every child script and dotbot's `if:`
     conditions inherit it. Unknown flags error out (`:83-87`) rather than being silently ignored.
     See §9 for the full profile system.
   - `--dry-run` (`:139-178`) prints the resolved profile, Brewfile paths, the macOS/tool scripts
     that would run, and a dotbot `-n` (dry-run) preview of the symlink set, then exits — nothing
     below this block executes.
   - Sources `config/zsh/.zshenv` early (`install.sh:121-123`) — *before* the tools that file's
     PATH lines reference (rustup, bob, brew) necessarily exist. See §6 for the unconditional
     `rustup` line that errors here on a fresh box.
   - `system_verify` hard-requires only **`git`** (`install.sh:181`); `zsh`/`vim`/`nvim`/`tmux`
     are `false` (warn-only).
   - Git identity prompt (`:187-220`): if `~/.config/git/local` doesn't exist yet, reads name +
     email from **`/dev/tty`** (not stdin — the README install path is `curl … | bash`, so stdin
     is the pipe) and writes them there. No tty ⇒ writes a `CHANGEME` stub and records a failure
     rather than hanging. Under `--corporate`, also appends a `url."https://…".insteadOf` rewrite
     to that file, so *future* manual submodule/clone work off this machine goes over HTTPS too.
   - `git pull origin main` (`:223`, still fatal via `terminate`) then, profile-gated
     (`:225-235`), `git submodule update --recursive --remote --init` — under `--corporate` with
     an **inline** `-c url."https://github.com/".insteadOf="git@github.com:"` rewrite. Inline,
     not via the `~/.config/git/local` rule just written, because dotbot hasn't linked
     `~/.gitconfig` yet at this point in the script (that's the next step) — the `[include]` isn't
     active. The `--remote` drift is unrelated, see [CLAUDE.md](CLAUDE.md) and §7.
   - dotbot: `"$DOTBOT_DIR/$DOTBOT_BIN" -d . -c "$SYMLINK_FILE"` (`:239`), now failure-tracked
     rather than bare. `SYMLINK_FILE` defaults to `symlinks.yaml` but is overridable via env
     (`:127` — `SYMLINK_FILE="${SYMLINK_FILE:-symlinks.yaml}"`).
   - macOS only (`SYSTEM_TYPE = Darwin`, `:244-329`): install Homebrew if missing, `brew update`,
     then `brew upgrade` **only on personal** (`:262-267` — it upgrades every installed
     formula/cask, including anything IT put on a corporate machine), then
     `brew bundle install --file=".../Brewfile"` always and `--file=".../Brewfile.personal"` only
     on personal (`:269-279`), then `brew cleanup`. See §9 for the base/personal package split.
   - `scripts/macos/install.sh` (`:286-291`) — now runs `common/macos-*.sh` always and
     `personal/macos-*.sh` only off `--corporate`, still under `sh "$script"` **regardless of git
     tracking or the script's own `#!/usr/bin/env bash` shebang**.
   - `launchctl bootout` then `launchctl bootstrap gui/$(id -u)` over every plist dotbot just
     linked into `~/Library/LaunchAgents/` (`:293-321`, profile-gated the same way as the scripts
     above) — idempotent, and the first thing in the repo to actually *load* a LaunchAgent rather
     than just symlink its plist. Verified: `launchctl bootstrap` resolves a symlinked plist fine
     (the `path =` it reports is the symlink target), so no copy-into-place fallback was needed.
   - Post-install (runs on all platforms, after the Darwin block): `rustup default stable` if
     rustup exists (`:333-338`); then `scripts/installs/tools/install.sh` (`:342-346`) — the
     cross-platform twin of the `scripts/macos/` runner, same `common/`+`personal` split, globbing
     `tool-*.sh` (`tool-neovim.sh` — the bob/`v0.11.5` install — and the new `tool-java.sh` in
     `common/`); `/bin/zsh -i -c "antigen update && antigen-apply"` (`:355-359`).
   - Tracks every step's failure via `record_failure` (`:99-104`) rather than `set -e` — too many
     steps are legitimately best-effort to abort the whole run on. Prints a summary and the green
     **"✨ Dotfiles configured successfully"** banner only if nothing failed; otherwise a failure
     list and a non-green banner, and `exit 1` (`:371-379`). The banner is no longer
     unconditionally green.

---

## 2. Symlink map (`symlinks.yaml`)

Config is symlinked **piecemeal**, not as one big `config/` → `~/.config` link. `link` defaults:
`create: true`, `relink: true` (`:2-4`). A global `clean: ['~', '${XDG_CONFIG_HOME}']` (`:6`)
removes dangling links on every run.

The file has **two `link:` directives** (`:9` and `:58`), not one — dotbot allows multiple
top-level `link:` blocks and processes each independently, which is the only way to point two
different profile-gated sources at the *same* target key (a YAML mapping can't repeat a key, so
the personal and corporate variants of `~/.claude/skills` and `~/Library/LaunchAgents/` each need
their own block). See §9 for how `if:` gating on `DOTFILES_PROFILE` works.

| Target | Source | Notes |
|---|---|---|
| `~/.zshenv` | `config/zsh/.zshenv` | **`force: true`** (`:12`) |
| `~/.zshrc` | `config/zsh/.zshrc` | **`force: true`** (`:13`) |
| `~/.tmux/plugins/tpm` | `lib/tpm` | submodule |
| `~/.tmux.conf` | `config/tmux/tmux.conf` | |
| `~/.claude` | `config/claude` | **personal only** (`if: DOTFILES_PROFILE != corporate`), **`force: true`** (`:20-23`) — live global Claude Code state |
| `~/.claude/skills` | `config/skills` | **personal only**, **`force: true`** (`:24-27`) — Claude Code skills |
| `~/.claude/CLAUDE.md` | `config/claude/CLAUDE.md` | **corporate only** (`if: DOTFILES_PROFILE = corporate`), no `force` (`:59-61`, second `link:` block) |
| `~/.claude/skills` | `config/skills` | **corporate only**, no `force` (`:62-64`, second `link:` block) |
| `~/.agents/skills` | `config/skills` | **`force: true`** (`:29`) — Codex CLI personal skills; same physical files as `~/.claude/skills` |
| `~/.omnigent/plans` | `config/omnigent/plans` | no `force` — see §2a, `~/.omnigent` itself is untouched |
| `${XDG_CONFIG_HOME}/zsh` | `config/zsh` | |
| `${XDG_CONFIG_HOME}/nvim` | `config/nvim` | submodule |
| `${XDG_CONFIG_HOME}/kitty` | `config/kitty` | |
| `${XDG_CONFIG_HOME}/starship.toml` | `config/general/starship.toml` | |
| `${HOME}/.gitconfig` | `config/general/.gitconfig` | |
| `${XDG_CONFIG_HOME}/.gitignore_global` | `config/general/.gitignore_global` | |
| `~/Library/LaunchAgents/` | `config/macos/LaunchAgents/common/*` | Darwin-gated **`glob: true`**, both profiles (`:51-54`) |
| `~/Library/LaunchAgents/` | `config/macos/LaunchAgents/personal/*` | Darwin + personal gated **`glob: true`** (`:65-68`, second `link:` block) |

`create:` also makes `~/Downloads`, `~/Documents`, `~/Applications` if absent (`:72-74`).
`~/Applications` matters because the Brewfile sets `cask_args appdir: '~/Applications'`
(`Brewfile:2`, which also sets `require_sha: true`), so casks and (on personal)
`macos-openwhispr.sh` install there rather than `/Applications`.

`${XDG_CONFIG_HOME}/karabiner` and `~/.Brewfile` are gone — see §9 (Karabiner is replaced by
hidutil on both profiles; the Brewfile split means one symlink can no longer describe the truth,
`install.sh` now calls `brew bundle --file=` directly instead).

The commented-out `yabairc` block (`:47-50`) is dormant.

### 2a. `config/omnigent/` — only the `plans/` subdir is claimed

Unlike `~/.claude`, `~/.omnigent` is **not** force-symlinked wholesale to a `config/omnigent`
mirror. `~/.omnigent` holds live daemon/session state (`chat.db`, `daemons/`, `logs/`,
`artifacts/`, `config.yaml`) that must never be `rm`'d the way `force: true` would. Instead only
`~/.omnigent/plans` (a subdir omnigent itself never creates) is symlinked to
`config/omnigent/plans/`, giving the `plan` skill (`config/skills/plan/SKILL.md`) a stable,
per-machine-persistent, dotfiles-tracked place to write planning-mode output. Generated plan
files themselves are gitignored (`config/omnigent/.gitignore`); only the directory (via
`plans/.gitkeep`) is tracked. The skill writes there with `sys_os_shell`/plain shell redirection,
never a sandboxed file-write tool — those are typically confined to the caller's project
workspace and can't reach a `~/...` path outside it.

---

## 3. Cross-tool coupling (the non-obvious "why")

These configs are entangled; changing one in isolation breaks another.

- **kitty *is* the tmux frontend.** `kitty.conf:89` `shell tmux` → every kitty window launches
  straight into tmux (no login shell). Native kitty tab/window keys are `no_op`'d
  (`kitty.conf:72-83`: `cmd+t`, `cmd+shift+[`/`]`, `cmd+1`..`cmd+9`) so **all** window/tab
  management is tmux's, per the config's own "Force windows/tabs through tmux" comment. The tab
  bar is hidden (`tab_bar_style hidden`).
- **Prefix is `C-a`** (`tmux.conf:33`, `C-b` unbound `:31`). Prefixless `M-1`..`M-9` jump windows
  (`tmux.conf:81-89`). Those Alt chords reach tmux through **one** mechanism, not two: kitty's
  `macos_option_as_alt left` (`kitty.conf:9`) does 100% of the work. There used to be a Karabiner
  rule rewriting `left_option → left_alt` at the system level too, but Karabiner's own
  `simple_modifications.json` labels `left_alt` as *"equal to `left_option`"* — a PC-style alias
  for the same physical key, not a distinct target — so that rule was always a no-op layered on
  top of kitty's remap, never a second remap in the chain. Karabiner is gone now (see §9); the
  backtick/tilde remap it also carried is reimplemented via `hidutil` in
  `scripts/macos/common/macos-keyremap.sh`, which has no bearing on Option/Alt at all.
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

Everything below describes the **personal** profile, where `~/.claude` is force-symlinked
wholesale to this directory. Under `--corporate` only `CLAUDE.md` and `skills/` are linked in
individually, without `force` — see §9.

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
~Karabiner writes backups into the repo~ and ~LaunchAgents are symlinked but never loaded~ —
both resolved by the `--corporate` install-profile change (§9): Karabiner is deleted outright, and
`install.sh` now runs `launchctl bootstrap` over every linked agent.

---

## 7. Current WIP snapshot

At investigation time the working tree carried a batch of **uncommitted** changes that read as
one coherent in-progress feature: the tmux/sesh/lazygit/fzf/`fd` popup workflow (`tmux.conf`),
`kitty.conf`, and the `Brewfile`. (`scripts/macos/macos-openwhispr.sh` was untracked at that time;
it's since been committed and relocated to `scripts/macos/personal/macos-openwhispr.sh` by the
`--corporate` profile split, §9.) Concretely this WIP **replaces** the committed `tmux.conf` PATH
hardcode
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

Untracked-but-present files (e.g. a fresh WIP script) won't show in `git ls-files` — cross-check
with `git status` when completeness matters.

---

## 9. Install profiles (`--corporate`)

Why this exists: the installer used to put one fixed set of software and config on every machine —
torrent client, VPN clients, social/media apps, packet-capture tooling, an unsigned de-quarantined
app, a personal cloud mount, and a `.gitconfig` hardcoding a personal email. None of that belongs
on a corporate laptop. `install.sh --corporate` splits the whole install surface — Homebrew
packages, macOS scripts, tool scripts, LaunchAgents, and `~/.claude` — into a **base** set
(both machines) and a **personal** set (personal machine only, the default).

**Stateless by design.** There is no marker file and no persisted profile anywhere on disk.
`install.sh` is run exactly once per machine (never re-run, and `brew bundle` is never invoked
again after initial setup — day-to-day maintenance is plain `brew update && brew upgrade &&
brew cleanup`), so the profile only needs to exist for the duration of one invocation. Adding
persistence would be state to keep in sync for no benefit.

**How the profile propagates.** `install.sh`'s ARGS section (`:50-90`) parses `--corporate` /
`--personal` / `--dry-run` / `--help` in an arg loop (`:68-90`); unknown flags error out rather
than being silently ignored. It resolves to `DOTFILES_PROFILE=corporate|personal` and `export`s
it (`:92`) before doing anything else. Three consumers read it:

- **dotbot's `if:` conditions** (`symlinks.yaml`) — dotbot's `_test_success` (`link.py:173`) calls
  `shell_command` (`util/common.py:8`), which passes no `env=` override to `subprocess`, so the
  exported var flows through to every `if:` shell test unchanged. Confirmed with real scratch-`HOME`
  runs (`HOME=/tmp/... DOTFILES_PROFILE=corporate lib/dotbot/bin/dotbot -d . -c symlinks.yaml`) for
  both profiles — this was the main technical risk in the design and it resolves cleanly.
- **The two glob runners** (`scripts/macos/install.sh`, `scripts/installs/tools/install.sh`) —
  both always run every script under their local `common/` subdirectory, then run `personal/` only
  `if [ "$DOTFILES_PROFILE" != "corporate" ]`. No manifest to drift: which script runs on which
  profile is just which directory it lives in.
- **`install.sh`'s own Darwin block** (`:244-329`) — gates `brew upgrade` (personal only, since it
  upgrades *every* installed formula/cask, not just Brewfile entries — IT-provisioned software on
  a corporate box shouldn't get silently upgraded by this script) and the second `brew bundle
  install --file=` call against `Brewfile.personal` (personal only) directly on the same check.

**The package split.** `scripts/installs/Brewfile` (base, 32 brews + 6 casks) installs on both
profiles; `scripts/installs/Brewfile.personal` (3 brews + 15 casks) only on personal. Both carry
their own `cask_args appdir: '~/Applications', require_sha: true` header since each is passed to
`brew bundle install --file=` independently — there's no shared "global" Brewfile context anymore.
Four casks (`karabiner-elements`, `intellij-idea`, `pycharm`, `aldente`) and one brew (`tlrc`) are
deleted outright, on both profiles, as unused. Personal-only: `transmission` (torrent), `tailscale`
+ `protonvpn` (VPN — would conflict with a corporate VPN anyway), `signal`/`whatsapp`/`telegram`/
`discord`/`spotify`/`iina` (social/media), `zotero` + `macfuse` + the rclone LaunchAgent (personal
cloud mount; macfuse is a kernel extension), `nmap`/`wireshark` (packet capture), `docker-desktop`
+ `container` (the work Mac gets no local container runtime at all), `stats`, `postman` (syncs
collections to Postman's cloud by default), `claude` desktop app (`claude-code` is base), and the
`macos-openwhispr.sh` / `macos-power.sh` scripts (below).

**Corporate bootstrap is HTTPS, not SSH.** There's no personal SSH key on a fresh corporate laptop.
`RUNME.sh` clones `https://github.com/1henrypage/.dotfiles.git` instead of the `git@github.com:`
SSH form when `--corporate` is in `"$@"`, and forwards all args to `install.sh "$@"`. Submodule
fetches need the same treatment: `install.sh`'s git-identity block (`:187-220`) writes
`~/.config/git/local` *before* the submodule update runs, but writing the `insteadOf` rewrite into
that file wouldn't help here anyway, because on corporate the submodule update is invoked with the
rewrite passed **inline** —
`git -c url."https://github.com/".insteadOf="git@github.com:" submodule update --recursive
--remote --init` — rather than relying on the persisted config file. This sidesteps an ordering
trap: `~/.gitconfig` isn't linked by dotbot until later in the run, and it isn't `force: true`
either, so a real file materializing there first would make the dotbot symlink step fail. The
persisted `~/.config/git/local` rule (written with the `insteadOf` block appended, corporate only)
still covers any submodule work done by hand later.

**Git identity is always prompted, never hardcoded.** `config/general/.gitconfig` no longer carries
a `[user]` section — it `[include]`s `~/.config/git/local`, a file outside the repo that
`install.sh` creates on first run by reading name/email from `/dev/tty` (not stdin, since the
documented install path is `curl … | bash`, where stdin is the pipe body, not a keyboard). No tty
available ⇒ writes a `CHANGEME` stub and records a non-fatal failure rather than hanging.

**`~/.claude` is the one target that differs in *how* it's linked, not just *whether*.** Personal
force-links the whole live global state wholesale (`symlinks.yaml`'s first `link:` block,
`~/.claude` and `~/.claude/skills`, `force: true`, gated `if: '[ "$DOTFILES_PROFILE" != corporate ]'`).
Corporate instead links only `~/.claude/CLAUDE.md` and `~/.claude/skills`, **without** `force`, from
a second top-level `link:` block gated the other way — dotbot's YAML mapping keys must be unique
within a single `link:` block, and these same target paths already appear (gated oppositely) in the
first block, so the corporate variants need their own block. Without `force`, dotbot's default
`relink: true` still repairs a stale symlink but refuses to overwrite a real file or directory, so a
pre-provisioned enterprise `~/.claude` (auth tokens, org settings, `settings.json`) survives intact
instead of being destroyed. One consequence: corporate never links `settings.json`, so
`skipDangerousModePermissionPrompt: true` and the personal model pins in it never reach the work
Mac. The same second-block pattern also splits `~/Library/LaunchAgents/` — `common/*` glob-linked
always, `personal/*` glob-linked only off-corporate — since a single glob `link:` entry can't source
from two different directories at once.

**Karabiner is gone on both profiles**, replaced by `scripts/macos/common/macos-keyremap.sh`
(hidutil, see §3) and its LaunchAgent — no cask, no kernel extension, no Input Monitoring prompt.
**LaunchAgents are now actually loaded**: `install.sh` runs `launchctl bootout` (ignoring failure —
the agent may not be loaded yet) then `launchctl bootstrap gui/$(id -u)` over every plist linked
into `~/Library/LaunchAgents/`, for both the `common` and (personal-only) `personal` sets, fixing
the bug in the old §6.

**`tool-java.sh` fixes the missing `jenv add`.** `jenv` is a JDK version *switcher*, not an
installer or discoverer — the `openjdk@17`/`openjdk@21` Homebrew formulae install the JDKs
keg-only (never symlinked into `/Library/Java/JavaVirtualMachines/`), so without registering each
one by hand, `jenv versions` shows only `system` forever. `scripts/installs/tools/common/tool-java.sh`
globs `$(brew --prefix)/opt/openjdk@*/libexec/openjdk.jdk/Contents/Home`, runs `jenv add` on each
(idempotent — a no-op if already registered), and sets `jenv global 21`. Lands in `common/` since
Databricks is a JVM shop and both profiles need working Java out of the box.

**The always-green banner is fixed.** `install.sh` has no `set -e` (many steps are legitimately
best-effort), so instead every step that can fail now calls `record_failure "<step name>"` into a
counter/list on non-zero exit. The final banner is green with `exit 0` only if `$FAILURE_COUNT -eq
0`; otherwise it prints the failed-step list and `exit 1`.
