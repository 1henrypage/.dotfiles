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
  **personal** profile only) `~/.claude` and `~/.agents/skills` are `force: true` → dotbot
  `rm`/`rmtree`s any real file or dir already at that path, **no backup, no prompt**. Adopting
  these dotfiles on a machine that already has a real `~/.claude` **destroys it**. The
  **corporate** profile (`install.sh --corporate`) does not take this path at all — it links
  `~/.claude/CLAUDE.md` (existence-guarded) and per-skill globs under `~/.claude/skills/` +
  `~/.agents/skills/`, all without `force`, so a real pre-existing `~/.claude` survives.
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
