# Working on this repo (project memory)

Personal, **macOS-first** dotfiles. Config is deployed as dotbot symlinks; the machine is
bootstrapped by `RUNME.sh` → `install.sh`, over SSH by default or HTTPS under `--corporate`
(a work-machine install profile — see Conventions below). Linux/Arch support is aspirational and
underspecified.

> **Where we are going.**
> I still use this for MacOS laptop. I've underspecified it on the linux side cause im planning to migrate from ubuntu to arch anyways.

Don't trust or paste a file tree here — the last one drifted ~5 months out of date. Run
`git ls-files` for the real structure. For the deep dive (full bootstrap trace, symlink map,
cross-tool coupling, and the known latent bugs) read **[ARCHITECTURE.md](ARCHITECTURE.md)**.

## The two "claude" directories — read this first

The single most confusing thing about this repo. They are unrelated:

- **`.claude/`** (repo root) = project memory for working **on this repo** — *this file*. Root
  `.gitignore` ignores `.claude/*` but explicitly un-ignores `CLAUDE.md` and `ARCHITECTURE.md`
  (so they track normally); everything else here (e.g. `settings.local.json`) stays ignored.
  Adding a **new** doc under `.claude/` needs a matching `!.claude/<name>` line in `.gitignore`,
  or it won't show in `git status`.
- **`config/claude/`** = the user's **live global `~/.claude`**, force-symlinked in on the
  **personal** install profile (`symlinks.yaml`, `if: DOTFILES_PROFILE = personal`). Editing
  anything under it mutates **live, machine-wide Claude Code state**. Only 7 entries are tracked
  (`.gitignore`, `CLAUDE.md`, `WRITING.md`, `settings.json`, `hooks/notify.sh`,
  `commands/.gitkeep`, and a tracked symlink `skills -> ../skills` that pulls in the real skill
  directories from `config/skills/`); runtime state (sessions, history, projects, cache) lives in
  the working tree but is gitignored via **two** layers — root `.gitignore` +
  `config/claude/.gitignore`. **Never `git add`** that runtime state.
  On the **corporate** profile (`install.sh --corporate`), only `~/.claude/CLAUDE.md`
  (existence-guarded) and per-skill links under `~/.claude/skills/` + `~/.agents/skills/` are
  linked, all without `force`, so a pre-provisioned enterprise `~/.claude` (auth, org settings,
  `settings.json`) is left alone — see `ARCHITECTURE.md` §9.

## Footguns (destructive / surprising)

- **`force: true` symlinks destroy pre-existing files.** `~/.zshenv`, `~/.zshrc`, and (on the
  **personal** profile only) `~/.claude` and `~/.agents/skills` are `force: true` -> dotbot
  `rm`/`rmtree`s any real file or dir already at that path, **no backup, no prompt**, by default.
  On the **corporate** profile, `install.sh` now moves a pre-existing real `~/.zshenv` or
  `~/.zshrc` aside to a `.local` sibling *before* dotbot's force-link runs, and the repo's
  `.zshenv`/`.zshrc` source that sibling last, so corporate content survives (see
  `ARCHITECTURE.md` §9). On the **personal** profile they are still destroyed outright, with no
  such move-aside step. Adopting these dotfiles on a machine that already has a real `~/.claude`
  **destroys it** on the personal profile. The **corporate** profile does not force-link
  `~/.claude` at all - it links `~/.claude/CLAUDE.md` (existence-guarded) and per-skill globs
  under `~/.claude/skills/` + `~/.agents/skills/`, all without `force`, so a real pre-existing
  `~/.claude` survives.
- **`clean: ['~', '${XDG_CONFIG_HOME}', '~/Library/LaunchAgents', '~/.claude/skills',
  '~/.agents/skills']`** (`symlinks.yaml:6`) deletes dangling symlinks under those roots on every
  run — the last two matter only on corporate, where skills are per-skill glob-links rather than
  one directory link, so a removed skill leaves a dangling link `clean:` needs to reap.
- **`install.sh` has no `set -e`.** Steps fail silently; each failure is tracked and the final
  banner is only green if nothing failed. Don't assume `install.sh`'s own line citations here stay
  accurate — it's one of the fastest-churning files in the repo (see `ARCHITECTURE.md`'s note on
  citing by name instead of line number for it).
- **`brew upgrade` upgrades every installed formula/cask**, not just Brewfile entries — that's why
  it's gated to the personal profile only.
- **AeroSpace owns `ctrl-alt` globally; tmux owns bare `alt` and bare `ctrl`.** AeroSpace registers
  *global* macOS hotkeys, so it intercepts a keystroke before kitty (and therefore tmux/nvim) ever
  sees it. Never bind `alt-*` in `config/aerospace/aerospace.toml` - it would shadow tmux window
  switching (`M-1`..`M-9`) and pane resize in every kitty window - and never bind `ctrl-alt-*` in
  `tmux.conf`, because AeroSpace swallows it first. `macos_option_as_alt left` does not help:
  macOS hotkey registration cannot distinguish left Option from right. Full table in
  `ARCHITECTURE.md` §3.
- **`ctrl-alt-<letter>` is a named-workspace namespace, not free real estate.** 19 letters
  (`a c d e g i m n o p q s t u v w x y z`) are bound to `workspace <LETTER>` /
  `move-node-to-workspace --focus-follows-window <LETTER>` for mnemonic workspaces (e.g.
  `ctrl-alt-s` for Spotify). Only `b f h j k l r` are free, because they're already claimed by
  window-management bindings. Binding a new `ctrl-alt-<letter>` for anything else silently steals
  a workspace letter - see the `MODIFIER LAYER CONTRACT` comment in `aerospace.toml`.
- **AeroSpace errors out if it finds a config in more than one location.** It reads
  `${XDG_CONFIG_HOME}/aerospace/aerospace.toml` (the dotbot symlink); a stray `~/.aerospace.toml`
  makes it refuse to start rather than picking one.
- **Any glyph added to the tmux status bar (or anywhere else a Nerd Font is assumed) must be
  checked against the font's cmap first, or it silently renders as tofu.** This is exactly the bug
  that shipped for months in the old tokyo-night-tmux window-number styling (Unicode 13 Segmented
  Digits, absent from `FantasqueSansMNerdFontMono-Regular.ttf`) - no error, no warning, just an
  invisible glyph in place of `M-1`..`M-9`. See `ARCHITECTURE.md` §3 for how to check a codepoint
  against the live font before adding it.
- **tmux's `#{>=:x,y}` and friends compare strings, not numbers** - `#{>=:90,100}` is *true*,
  `#{>=:100,80}` is *false*. Any numeric test (e.g. the status bar's `client_width` tiers) must use
  an arithmetic sign test instead: `#{e|-|:x,N}` goes negative iff `x < N`, detected with
  `#{m:-*,...}`. Silent, and it *looks* correct whenever both numbers have the same digit count.
  Relatedly, a `#{?...}` condition must be inline - factored into an option and referenced as
  `#{?#{E:@opt},a,b}` it is always false, because a bare `1`/`0` there is read as a variable name.
  Both are documented in place in `tmux.conf`; see `ARCHITECTURE.md` §3.
- **`macos-openwhispr.sh:70`** strips the Gatekeeper quarantine flag
  (`xattr -dr com.apple.quarantine`) from a freshly-downloaded, unsigned `.app`.

## Submodule drift is expected, not damage

Three submodules (`.gitmodules`): `lib/dotbot`, `lib/tpm` (upstream tools) and `config/nvim`
(the user's **own** fork, `git@github.com:1henrypage/nvim`). `install.sh` runs
`git submodule update --recursive --remote --init` (over an inline HTTPS rewrite on the
corporate profile, since there's no personal SSH key there); `--remote` fast-forwards them (and
their nested `pyyaml` / `tmux-test`) past their pinned SHAs on every run. The `m` beside
`lib/dotbot` and `lib/tpm` in `git status` is that nested drift — **harmless, not a manual edit;
don't blindly commit it.**

## The `.zwc` edit trap

`config/zsh/setup-antigen.zsh.zwc` is committed compiled bytecode (tracked despite `*.zwc` in
`.gitignore`). zsh loads a `.zwc` in place of its `.zsh` source whenever the `.zwc` is newer —
and it currently is. So **editing `setup-antigen.zsh` is silently ignored** until you re-compile
it (`zcompile`) or delete the `.zwc`.

## `config/nvim` is a separate repo

It's a submodule with its **own** `config/nvim/CLAUDE.md` and conventions (all hex colors only in
`extras/colors.lua`; language config only in `plugins/lang/`; one file per plugin — never
`ftplugin/`). Changes there are committed/pushed to `1henrypage/nvim`, **not** this repo.

## Conventions

- Commits: terse, imperative, **no** Conventional-Commits prefixes (no `feat:`/`fix:`); casing is
  loose (mostly lowercase). Match the existing `git log`.
- Bootstrap defaults to **SSH** (`git@github.com:…`) but supports **HTTPS** via `install.sh
  --corporate` (see below) — `RUNME.sh` still hardcodes the `1henrypage` identity either way, and
  `config/general/.gitconfig` no longer hardcodes an identity at all (see below) — a forker must
  edit `RUNME.sh`'s repo URLs regardless of profile.
- No build or test harness — it's configs plus POSIX-ish install scripts. Verify any claim by
  reading the file it cites; the working tree often carries uncommitted WIP, so `git blame` on a
  live config can mislead.
- **Install profiles.** `install.sh --corporate` (work machine) vs. the default `--personal`
  split every package, script, and symlink the installer touches into a base set (both machines)
  and a personal-only set. There's no persisted state — the flag is resolved fresh on every
  invocation and exported as `DOTFILES_PROFILE`, which both dotbot's `if:` conditions and every
  child script read. Any new macOS setup script or cross-platform tool installer goes into either
  `common/` (runs on both profiles) or `personal/` (personal only) under `scripts/macos/` and
  `scripts/installs/tools/` — never loose at the top of those directories, since the runners only
  glob those two subdirectories. Likewise `config/macos/LaunchAgents/{common,personal}/`. Git
  identity is never hardcoded — `config/general/.gitconfig` `[include]`s a gitignored
  `~/.config/git/local` that `install.sh` writes on first run by prompting over `/dev/tty`. Full
  writeup: `ARCHITECTURE.md` §9.
