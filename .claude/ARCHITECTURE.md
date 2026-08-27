# ARCHITECTURE — deep dive

Read on demand. Companion to [CLAUDE.md](CLAUDE.md); that file is the lean summary that loads
every session. This one carries the line-referenced detail: bootstrap trace, symlink map,
cross-tool coupling, and the latent bugs. Line numbers are accurate as of writing but drift with
edits — treat them as pointers and re-open the file to confirm. `install.sh` and `symlinks.yaml`
churn fastest (both have already drifted a full audit's worth of citations once), so §1 and §2
below cite by function/flag/YAML-key name rather than line number wherever the name is stable —
prefer that pattern when extending this doc.

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
   - `cd ~/.dotfiles && ./install.sh "$@"` (`RUNME.sh:45-46`) — forwards every flag through.

2. **`install.sh`** (`#!/bin/sh`, **no `set -e`** — read [CLAUDE.md](CLAUDE.md) footguns):
   - The **arg loop** resolves `--corporate` / `--personal` (default) / `--dry-run` / `--help`
     into `DOTFILES_PROFILE` and `export`s it right after — every child script and dotbot's `if:`
     conditions inherit it. Unknown flags error out rather than being silently ignored. See §9 for
     the full profile system.
   - The **`--dry-run` block** prints the resolved profile, Brewfile paths, the macOS/tool scripts
     that would run, and a dotbot `-n` (dry-run) preview of the symlink set, then `exit 0` —
     nothing below this block executes. If `lib/dotbot` isn't initialised yet, the symlink preview
     is skipped with a warning instead — `--dry-run` no longer initialises the submodule itself,
     since that's a real network fetch and working-tree write that broke its "prints only, changes
     nothing" contract.
   - Sources `config/zsh/.zshenv` early — *before* the tools that file's PATH lines reference
     (rustup, bob, brew) necessarily exist. The rustup PATH line used to invoke `rustup` directly
     here and could error on a fresh box; see §6 — it now reads `~/.rustup/settings.toml` instead
     and never invokes `rustup` at all.
   - `system_verify` hard-requires only **`git`**; `zsh`/`vim`/`nvim`/`tmux` are warn-only.
   - The **git-identity block**: if `~/.config/git/local` doesn't exist yet (or still contains the
     `CHANGEME` stub), reads name + email from **`/dev/tty`** (not stdin — the README install path
     is `curl … | bash`, so stdin is the pipe) and writes them there. No tty ⇒ writes a `CHANGEME`
     stub and records a failure rather than hanging. Under `--corporate`, also appends a
     `url."https://…".insteadOf` rewrite to that file — guarded by an exact
     `git config --get-all url.https://github.com/.insteadOf` check (not a bare `grep`), so an
     unrelated `insteadOf` line elsewhere in the file can't cause a false "already configured"
     skip — so *future* manual submodule/clone work off this machine goes over HTTPS too.
   - `git pull origin main` (still fatal via `terminate`) then, profile-gated,
     `git submodule update --recursive --remote --init` — under `--corporate` with an **inline**
     `-c url."https://github.com/".insteadOf="git@github.com:"` rewrite. Inline, not via the
     `~/.config/git/local` rule just written, because dotbot hasn't linked `~/.gitconfig` yet at
     this point in the script (that's the next step) — the `[include]` isn't active. The
     `--remote` drift is unrelated, see [CLAUDE.md](CLAUDE.md) and §7.
   - Under `--corporate` only, a **skill-collision pre-scan** runs immediately before dotbot: it
     walks `config/skills/*` and, for any skill name that already exists as a **real**
     (non-symlink) directory under `$HOME/.claude/skills/` or `$HOME/.agents/skills/`, prints a
     `Note:` pointing at the exact colliding path. dotbot still exits 1 on that collision (no
     `force:` on that glob — see §2), but the cause now prints directly above the generic
     `dotbot symlinks` failure instead of leaving a bare red banner.
   - dotbot: `"$DOTBOT_DIR/$DOTBOT_BIN" -d . -c "$SYMLINK_FILE"`, failure-tracked rather than bare.
     `SYMLINK_FILE` defaults to `symlinks.yaml` but is overridable via env.
   - Immediately after, under `--corporate` only: if `~/.claude/CLAUDE.md` exists and is **not** a
     symlink (i.e. dotbot's existence guard, see §2, skipped it because something was already
     there), print a `Note:` with the exact `@`-import line to append by hand.
   - macOS only (`SYSTEM_TYPE = Darwin`): install Homebrew if missing, `brew update`, then
     `brew upgrade` **only on personal** (it upgrades every installed formula/cask, including
     anything IT put on a corporate machine), then `brew bundle install --file=".../Brewfile"`
     always and `--file=".../Brewfile.personal"` only on personal, then `brew cleanup`. See §9 for
     the base/personal package split.
   - `scripts/macos/install.sh` — runs `common/macos-*.sh` always and `personal/macos-*.sh` only
     `if [ "$DOTFILES_PROFILE" = "personal" ]` (fail-safe: an unset or misspelled profile runs
     neither, rather than accidentally running the personal set), still under `sh "$script"`
     **regardless of git tracking or the script's own `#!/usr/bin/env bash` shebang**.
   - `launchctl bootout` then `launchctl bootstrap gui/$(id -u)` over every plist dotbot just
     linked into `~/Library/LaunchAgents/` (profile-gated the same way as the scripts above) —
     idempotent, and the first thing in the repo to actually *load* a LaunchAgent rather than just
     symlink its plist. Verified: `launchctl bootstrap` resolves a symlinked plist fine (the
     `path =` it reports is the symlink target), so no copy-into-place fallback was needed.
   - Post-install (runs on all platforms, after the Darwin block): `rustup default stable` if
     rustup exists; then `scripts/installs/tools/install.sh` — the cross-platform twin of the
     `scripts/macos/` runner, same `common/`+`personal` split (also fail-safe on
     `= "personal"` now), globbing `tool-*.sh` (`tool-neovim.sh` — the bob/`v0.11.5` install — and
     `tool-java.sh`, both in `common/`; `personal/` currently holds no `tool-*.sh` scripts, so this
     split is latent there); then `/bin/zsh -i -c "antigen update && antigen-apply"` near the very
     end of the script, under **Apply Preferences**.
   - Tracks every step's failure via `record_failure` rather than `set -e` — too many steps are
     legitimately best-effort to abort the whole run on. Prints a summary and the green
     **"✨ Dotfiles configured successfully"** banner only if nothing failed; otherwise a failure
     list and a non-green banner, and `exit 1`. The banner is no longer unconditionally green.

---

## 2. Symlink map (`symlinks.yaml`)

Config is symlinked **piecemeal**, not as one big `config/` → `~/.config` link. `link` defaults:
`create: true`, `relink: true`. `clean: ['~', '${XDG_CONFIG_HOME}', '~/Library/LaunchAgents',
'~/.claude/skills', '~/.agents/skills']` removes dangling symlinks under those roots on every run
— the last two entries matter only on the corporate profile, where `~/.claude/skills/<name>` and
`~/.agents/skills/<name>` are individual per-skill glob-links (below), not one directory link, so
`clean:` is what reaps a dangling per-skill link after a skill is removed from `config/skills/`.

The file has **two `link:` directives** (the main block, and a second "profile-split variants"
block below it) — dotbot allows multiple top-level `link:` blocks and processes each
independently, which is the only way to point two different profile-gated sources at the *same*
target key (a YAML mapping can't repeat a key, so the personal and corporate variants of
`~/.claude/CLAUDE.md`, `~/.claude/skills/`, `~/.agents/skills/`, and `~/Library/LaunchAgents/`
each need their own block). See §9 for how `if:` gating on `DOTFILES_PROFILE` works.

| Target | Source | Notes |
|---|---|---|
| `~/.zshenv` | `config/zsh/.zshenv` | **`force: true`** (both profiles) — corporate moves a real pre-existing file aside to `~/.zshenv.local` first, so only personal is genuinely destructive here, see §9 |
| `~/.zshrc` | `config/zsh/.zshrc` | **`force: true`** (both profiles) — same `~/.zshrc.local` move-aside on corporate, see §9 |
| `~/.tmux/plugins/tpm` | `lib/tpm` | submodule |
| `~/.tmux.conf` | `config/tmux/tmux.conf` | |
| `~/.claude` | `config/claude` | **personal only** (`if: DOTFILES_PROFILE = personal`), **`force: true`** — live global Claude Code state. No separate `~/.claude/skills` entry exists: `config/claude/skills` is itself a **tracked symlink** (`-> ../skills`), so force-linking `~/.claude` here already makes `~/.claude/skills` resolve through to `config/skills` for free — see §5. A dotbot entry for that path used to exist and fought the tracked symlink on every run (rewriting it from relative to absolute); removed for that reason. |
| `~/.claude/CLAUDE.md` | `config/claude/CLAUDE.md` | **corporate only**, existence-guarded (`if:` requires `DOTFILES_PROFILE = corporate` **and** (path doesn't exist **or** is already a symlink)), no `force` — second `link:` block |
| `~/.claude/skills/` | `config/skills/*` | **corporate only**, `glob: true` — **per-skill** links, not one directory link, no `force` — second `link:` block |
| `~/.agents/skills` | `config/skills` | **personal**, **`force: true`** — Codex CLI's personal skills path; same physical files as `~/.claude/skills` |
| `~/.agents/skills/` | `config/skills/*` | **corporate only**, `glob: true`, no `force` — second `link:` block |
| `~/.omnigent/plans` | `config/omnigent/plans` | no `force` — see §2a, `~/.omnigent` itself is untouched |
| `~/AGENTS.md` | `config/claude/CLAUDE.md` | existence-guarded the same way as `~/.claude/CLAUDE.md` above — **both profiles**, no `force` |
| `${XDG_CONFIG_HOME}/zsh` | `config/zsh` | |
| `${XDG_CONFIG_HOME}/nvim` | `config/nvim` | submodule |
| `${XDG_CONFIG_HOME}/kitty` | `config/kitty` | |
| `${XDG_CONFIG_HOME}/starship.toml` | `config/general/starship.toml` | |
| `${HOME}/.gitconfig` | `config/general/.gitconfig` | existence-guarded (`if:` requires the path doesn't exist **or** is already a symlink) — same pattern as `~/AGENTS.md`, no `force` |
| `${XDG_CONFIG_HOME}/.gitignore_global` | `config/general/.gitignore_global` | |
| `~/Library/LaunchAgents/` | `config/macos/LaunchAgents/common/*` | Darwin-gated, `glob: true`, both profiles |
| `~/Library/LaunchAgents/` | `config/macos/LaunchAgents/personal/*` | Darwin + personal gated, `glob: true` — second `link:` block |

`create:` also makes `~/Downloads`, `~/Documents`, `~/Applications` if absent. `~/Applications`
matters because the Brewfile sets `cask_args appdir: '~/Applications'` (`Brewfile:2`, which also
sets `require_sha: true`), so casks and (on personal) `macos-openwhispr.sh` install there rather
than `/Applications`.

`~/.Brewfile` is gone — the Brewfile split means one symlink can no longer describe the truth,
`install.sh` now calls `brew bundle --file=` directly instead.

The commented-out `yabairc` block is dormant.

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
- **Prefix is `C-a`** (`tmux.conf:38`, `C-b` unbound `:35`). Prefixless `M-1`..`M-9` jump windows
  (`tmux.conf:86-94`). Those Alt chords reach tmux through kitty's `macos_option_as_alt left`
  (`kitty.conf:9`) — the only mechanism involved. The backtick/tilde swap is a separate, unrelated
  remap via `hidutil` in `scripts/macos/personal/macos-keyremap.sh`.
- **Seamless pane nav across tmux ⇄ nvim** is hand-rolled on the tmux side and plugin-driven on
  the nvim side: `tmux.conf` defines `is_vim` (`:49-50`) and forwards `C-h/j/k/l` / `M-h/j/k/l`
  conditionally (`:53-62`), while nvim uses `aserowy/tmux.nvim`
  (`config/nvim/lua/1henrypage/plugins/tmux.lua`). The **resize step of 5** is duplicated by hand
  on both sides: `resize-pane … 5` (`tmux.conf:59-62,70-73`) and `resize_step_x/y = 5`
  (`lua/1henrypage/plugins/tmux.lua:7`). Change one, change the other.
- **Theming is Tokyo Night everywhere but maintained per-tool**, so exact shades differ by design
  (not a bug):
  - kitty (`kitty.conf`) and starship (`starship.toml`) share an **identical hardcoded hex
    palette** (`#1d2230` bg, `#e3e5e5` fg, `#769ff0`, `#a3aed2`, `#394260`, `#212736`, …).
  - tmux themes via the **`janoamaral/tokyo-night-tmux` plugin** with `_theme night`
    (`tmux.conf:139-149`) — its own palette, not the kitty hex.
  - nvim uses **tokyonight _storm_** (transparent) per `config/nvim/CLAUDE.md` — a different
    Tokyo Night variant again.
- **A Nerd Font is assumed.** kitty sets `font_family FantasqueSansM Nerd Font Mono`
  (`kitty.conf:68`); starship, the sesh picker, and nvim all render glyphs that require it.
- **`EDITOR`/`VISUAL` = `vim`** (`.zshenv:13-14`), but git's `core.editor = nvim`
  (`.gitconfig:12`). Different editors for shell vs git, and there's no `vim`→`nvim` bridging
  alias.
- **tmux PATH + plugin path:** kitty's `shell tmux` gives the tmux server a truncated PATH (no
  `/opt/homebrew/bin`, no `~/.local/bin`) and none of `.zshenv`'s exports, and `run-shell` itself
  uses `/bin/sh`. Two `run-shell` lines at the **top** of `tmux.conf` (`:9-10`) repair this at load
  by pulling the real login `PATH` **and** `TMUX_PLUGIN_MANAGER_PATH` from a login `zsh`
  (`/bin/zsh -lc`), keeping `.zshenv` the single source of truth. Both invoke tmux by its
  **absolute** path (`/opt/homebrew/bin/tmux`) because tmux isn't on the truncated PATH yet — an
  earlier WIP used bare `tmux`, which resolved to nothing and returned 127, so PATH was never set
  and tpm (loaded at `:156`) failed with the plugin path unset and never bound `prefix + I`. These
  lines must stay above the tpm loader so tpm sees a correct env. Downstream: `run-shell`/popup
  bindings (sesh, lazygit, `bind L`, `fd`) also see jenv/rustup/bob/`~/.local/bin`.

---

## 4. zsh specifics

Load order (interactive): `.zshenv` (always) → `.zshrc` sources `aliases/*.zsh`, then
`setup-antigen.zsh`, then `lib/*.zsh` (`.zshrc:10-23`).

- **`.zshrc` refuses non-interactive execution.** `if [[ $- != *i* ]]; then … return 1; fi`
  (`.zshrc:4-7`). Sourcing `.zshrc` from a script yields nothing. `.zshenv` has no such guard and
  always runs — that's why `install.sh` sources `.zshenv`, and why the antigen step near the very
  end of `install.sh` (under **Apply Preferences**) uses `zsh -i -c` to force interactivity.
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
wholesale to this directory. Under `--corporate` only `CLAUDE.md` and per-skill links under
`skills/` are linked in individually, without `force` — see §9.

**Tracked** (7 entries — `git ls-files config/claude`): `.gitignore`, `CLAUDE.md`, `WRITING.md`,
`settings.json`, `hooks/notify.sh`, `commands/.gitkeep`, and **`skills`** — the 7th entry is not a
directory but a **tracked symlink** (`config/claude/skills -> ../skills`), git mode `120000`.
Skills themselves moved to the tool-neutral `config/skills/`; this one committed symlink is what
makes `~/.claude/skills` (personal, via the wholesale `~/.claude` force-link) resolve straight
through to `config/skills` with no separate `symlinks.yaml` entry — see §2. `~/.agents/skills`
(Codex CLI's personal skills path) is a genuinely separate `symlinks.yaml` entry pointing straight
at `config/skills`, so there is exactly one physical copy on disk shared by both tools via two
different link mechanisms. Don't paste a static list of the skill directories here either - same
drift risk as §8's file tree. Run `git ls-files config/skills` for the current set; verify
`git ls-files config/claude` too rather than trusting a stale doc.

Notable `settings.json`: this file is **live, self-mutating state** — Claude Code itself rewrites
keys in it (e.g. `model` already differs between `HEAD` and the working tree at the time of
writing), so treat the list below as the *categories* present, not pinned values — read the file
for current values:
- `env`: disables adaptive thinking, the 1M context window, and auto-memory; pins the subagent
  model and the default-Opus-alias model.
- top-level: `model`, `effortLevel`, `showClearContextOnPlanAccept`,
  `skipDangerousModePermissionPrompt`, `skipWorkflowUsageWarning`, `enabledPlugins`.
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

- ~`.zshenv`'s PATH line unconditionally ran `rustup show active-toolchain` inside a PATH
  assignment, erroring on a machine without rustup~ — fixed: it now reads `default_toolchain`
  straight out of `~/.rustup/settings.toml` instead of invoking `rustup` at all, which also avoids
  rustup's auto-install of a full toolchain (~1.3GB) on a plain `source` — confirmed to trigger
  even through a `rust-toolchain.toml` override pinning an uninstalled channel. `.zshenv` still
  uses bash-only `[[ … ]]` (`:32,39,46,58`), which breaks if a Linux `/bin/sh` is `dash`.
- **zsh alias bugs** (`config/zsh/aliases/general.zsh`):
  - `dotfiles` / `dots` (`:117-118`) point at `${DOTFILES_DIR:-$HOME/Documents/config/dotfiles}` —
    but `DOTFILES_DIR` is never set and the repo actually lives at `~/.dotfiles`, so the alias
    targets a nonexistent path.
  - `fd` (`:89`) is only aliased to `find … -type d` when the real `fd` binary is **absent**
    (`(( $+commands[fd] )) || alias …`).
- **completion.zsh oddities.** `if [ -f $zsh_dump_file ]` (`:55`) guards on an **undefined**
  variable (the real one is `$zcompdump`, `:52`), so that `compinit` branch never fires. And
  `extendedglob` is enabled at `:46` but **`unsetopt extendedglob` at `:66`** leaves it globally
  **off** after the file loads.
- ~~`top-history` is broken by nested single quotes~~ — an earlier revision of this doc claimed
  that; re-verified and it's **false**. `general.zsh:94` double-quotes the alias body with an
  escaped `\$`, so `awk '{print $2}'` never closes the string early; the alias works. Recorded here
  as a correction, not re-added as a bug, since a wrong entry in this list is worse than no entry.

~LaunchAgents are symlinked but never loaded~ — resolved: `install.sh` now runs `launchctl
bootstrap` over every linked agent.

~`--dry-run` initialised `lib/dotbot` (a real network fetch) just to run the symlink preview~ —
resolved: when the submodule isn't present yet, `--dry-run` now skips the preview with a warning
instead, keeping it genuinely side-effect-free (§1). `${HOME}/.gitconfig` (§2, §9) is now
existence-guarded the same way as `~/AGENTS.md`, so a pre-provisioned `~/.gitconfig` is skipped
with a message instead of hard-failing the whole dotbot run.

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
`install.sh` tpm auto-install line — the old `[ -f "$XDG_DATA_HOME/tmux/tpm" ]` test hit a path
that never exists (tpm lives at `~/.tmux/plugins/tpm`, a directory), so plugins never
auto-installed; it now tests/runs `~/.tmux/plugins/tpm/bin/install_plugins` directly.

As of the last doc pass this WIP is fully committed — `git status`/`git diff` no longer show
`tmux.conf`, `kitty.conf`, or `Brewfile` as modified. Left here as a record of *why* those files
look the way they do; don't read it as describing the current working tree.

### Submodule drift, precisely

`git diff --submodule=short` shows `lib/dotbot` and `lib/tpm` as `…-dirty`; drilling in,
`git -C lib/dotbot status` is ` M lib/pyyaml` and `git -C lib/tpm status` is ` M lib/tmux-test`.
So the dirtiness is entirely their **nested** submodules being fast-forwarded by
`--recursive --remote` (the submodule-update step in `install.sh`), not any local edit.
`config/nvim` (the user's fork) tracks clean.

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
  `if [ "$DOTFILES_PROFILE" = "personal" ]`. That positive test (not a negated `!= corporate`) is
  deliberate: an unset or misspelled `DOTFILES_PROFILE` falls back to running **neither** extra
  set rather than accidentally running the personal one. No manifest to drift: which script runs
  on which profile is just which directory it lives in.
- **`install.sh`'s own Darwin block** — gates `brew upgrade` (personal only, since it upgrades
  *every* installed formula/cask, not just Brewfile entries — IT-provisioned software on a
  corporate box shouldn't get silently upgraded by this script) and the second `brew bundle
  install --file=` call against `Brewfile.personal` (personal only) directly on the same check.

**The package split.** `scripts/installs/Brewfile` (base, 30 brews + 5 casks) installs on both
profiles; `scripts/installs/Brewfile.personal` (5 brews + 17 casks) only on personal. Both carry
their own `cask_args appdir: '~/Applications', require_sha: true` header since each is passed to
`brew bundle install --file=` independently — there's no shared "global" Brewfile context anymore.
Three casks (`intellij-idea`, `pycharm`, `aldente`) and one brew (`tlrc`) are
deleted outright, on both profiles, as unused. Personal-only: `transmission` (torrent), `tailscale`
+ `protonvpn` (VPN — would conflict with a corporate VPN anyway), `signal`/`whatsapp`/`telegram`/
`discord`/`spotify`/`iina` (social/media), `zotero` + `macfuse` + the rclone LaunchAgent (personal
cloud mount; macfuse is a kernel extension), `nmap`/`wireshark` (packet capture), `docker-desktop`
+ `container` (the work Mac gets no local container runtime at all), `stats`, `postman` (syncs
collections to Postman's cloud by default), `claude` desktop app, the AI coding agent CLIs
(`claude-code` + `omnigent` + `opencode`; corporate uses Databricks' own provisioned Claude
Code), and the `macos-openwhispr.sh` / `macos-power.sh` scripts (below).

**Corporate bootstrap is HTTPS, not SSH.** There's no personal SSH key on a fresh corporate laptop.
`RUNME.sh` clones `https://github.com/1henrypage/.dotfiles.git` instead of the `git@github.com:`
SSH form when `--corporate` is in `"$@"`, and forwards all args to `install.sh "$@"`. Submodule
fetches need the same treatment: `install.sh`'s git-identity block writes `~/.config/git/local`
*before* the submodule update runs, but writing the `insteadOf` rewrite into that file wouldn't
help here anyway, because on corporate the submodule update is invoked with the rewrite passed
**inline** — `git -c url."https://github.com/".insteadOf="git@github.com:" submodule update
--recursive --remote --init` — rather than relying on the persisted config file. This sidesteps an
ordering trap: `~/.gitconfig` isn't linked by dotbot until later in the run, and isn't
`force: true` either — now existence-guarded (§2), so a real file materializing there first is
skipped instead of failing the dotbot step. The persisted `~/.config/git/local` rule (written with
the `insteadOf` block appended, corporate only) still covers any submodule work done by hand later.

**This assumes the repo (and its submodules) stay public.** Neither `RUNME.sh`'s HTTPS clone nor
`install.sh`'s `git pull origin main` (still fatal via `terminate`) has a credential source on a
corporate machine - no personal SSH key, no PAT wired in anywhere. If `1henrypage/.dotfiles` or
any of the three submodules (`lib/dotbot`, `lib/tpm`, `config/nvim`) ever goes private, both fail
hard on a corporate box with no fallback.

**Git identity is always prompted, never hardcoded.** `config/general/.gitconfig` no longer carries
a `[user]` section — it `[include]`s `~/.config/git/local`, a file outside the repo that
`install.sh` creates on first run by reading name/email from `/dev/tty` (not stdin, since the
documented install path is `curl … | bash`, where stdin is the pipe body, not a keyboard). No tty
available ⇒ writes a `CHANGEME` stub and records a non-fatal failure rather than hanging. One
residual quirk on at least git 2.55: `git config --global user.name` alone can return empty/exit 1
even when identity resolves correctly for real operations — it doesn't walk `[include]`. Use
`git config --global --includes user.name` or `git var GIT_AUTHOR_IDENT` to probe identity from a
script or CI; the bare `--global user.name` form is not a reliable "is identity configured" check
against this repo's `[include]`-based setup.

**`~/.claude` is the one target that differs in *how* it's linked, not just *whether*.** Personal
force-links the whole live global state wholesale to `config/claude` (`symlinks.yaml`'s first
`link:` block, `~/.claude`, `force: true`, gated `if: '[ "$DOTFILES_PROFILE" = personal ]'`) —
`~/.claude/skills` comes along for free via the tracked `config/claude/skills -> ../skills`
symlink, see §5. Corporate instead links `~/.claude/CLAUDE.md` (existence-guarded), and
`~/.claude/skills/` + `~/.agents/skills/` (per-skill globs), all **without** `force`, from a
second top-level `link:` block gated the other way — dotbot's YAML mapping keys must be unique
within a single `link:` block, and these same target paths already appear (gated oppositely) in
the first block, so the corporate variants need their own block. Without `force`, dotbot's default
`relink: true` still repairs a stale symlink but refuses to overwrite a real file or directory, so
a pre-provisioned enterprise `~/.claude` (auth tokens, org settings, `settings.json`) survives
intact instead of being destroyed. One consequence: corporate never links `settings.json`, so
`skipDangerousModePermissionPrompt: true` and the personal model pins in it never reach the work
Mac. The same second-block pattern also splits `~/Library/LaunchAgents/` — `common/*` glob-linked
always, `personal/*` glob-linked only off-corporate — since a single glob `link:` entry can't source
from two different directories at once. `~/AGENTS.md` gets the same existence guard as
`~/.claude/CLAUDE.md`, on **both** profiles (it's in the first `link:` block, ungated on
`DOTFILES_PROFILE`) — a real pre-existing `~/AGENTS.md` survives rather than failing the whole
dotbot run. `${HOME}/.gitconfig` (§2) now uses the same existence-guard pattern, also on both
profiles, so a pre-provisioned `~/.gitconfig` is skipped with a message instead of hard-failing
the install.

**`~/.zshenv`/`~/.zshrc` no longer lose corporate content to `force: true`.** Both stay `force:
true` on **both** profiles (§2) — dotbot's own link definition doesn't gate this by
`DOTFILES_PROFILE` — but `install.sh` now runs a preprocessing step immediately before the dotbot
call, corporate only: for each of `~/.zshenv`/`~/.zshrc`, if the target exists and is a **real**
file (not already a symlink, so the step is a no-op on a second run), it's moved aside to
`<target>.local` before dotbot force-links the repo's version over it. `config/zsh/.zshenv` and
`.zshrc` each source their `.local` sibling as their last line, so any IT-managed content (proxy
settings, internal registry auth) from the original file still runs, and wins on any conflicting
assignment made earlier in the repo's own file. Personal is unaffected by this step and remains
genuinely destructive on `force: true`, same as `~/.claude` above — there's no pre-existing
content worth protecting on the user's own machine.

The tilde/backtick remap is **personal profile only**:
`scripts/macos/personal/macos-keyremap.sh` (hidutil, see §3) and its LaunchAgent — no cask, no
kernel extension, no sudo. It's deliberately not in `common/`: this swaps two ISO-only keys, and
doing that on an ANSI keyboard would make backtick untypeable. The corporate machine currently
gets no remap at all. See the script's own comment for what it does and why.
One limitation worth knowing: the LaunchAgent is `RunAtLoad` with no `KeepAlive`, and
`hidutil property --set` only applies to devices already attached when it runs, so an **external
keyboard plugged in later does not get remapped** until the next login (or a manual re-run of the
script).

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

### Migrating an existing machine

The profile split above describes a fresh install. Landing a breaking change on this repo (a
moved file, a new gate, a renamed target) on a machine that already ran an older version needs a
one-time manual repair, not new install machinery - automating a repair path that only ever runs
once per breaking change isn't worth the complexity. Precedent, from the `--corporate` split
itself: the `personal/` LaunchAgents move orphaned `com.rclone.zotero.plist` (dotbot's `clean:`
didn't cover `~/Library/LaunchAgents` at the time - since fixed, see the symlink map above). The
repair shape: relink with the correct `DOTFILES_PROFILE` set so `clean:` reaps the dangling links,
re-run the affected setup script directly (e.g. `DOTFILES_PROFILE=corporate sh
scripts/macos/install.sh`, matching whatever profile the machine is actually on), reload the
affected LaunchAgents with `launchctl bootout`/`bootstrap`, and `brew uninstall` whatever the
package split left behind.

Whenever a breaking change removes a vendor app entirely, add a fifth step: **check for vendor
agents that self-register** - `launchctl list`, `systemextensionsctl list`, and `ps aux` - since a
vendor's own installer can register a DriverKit system extension, root LaunchDaemons, or
`SMAppService` user agents that persist as running processes even after the cask, the app bundle,
and dotbot's own symlinks are gone. None of that is reached by `brew uninstall --cask` or dotbot's
`clean:`; remove it through the vendor's own uninstaller (or `launchctl bootout` + manual
plist/binary removal for user agents) rather than assuming a Homebrew or dotbot cleanup step
reaches it. Bare `systemextensionsctl uninstall` is SIP-gated and unreliable; prefer reinstalling
the cask and running the vendor's bundled uninstaller before removing it again.

Reach for the same shape - relink, re-run the specific script, reload, check for self-registered
vendor agents, uninstall - the next time a breaking change like this lands.
