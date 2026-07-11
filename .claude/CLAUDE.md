# Working on this repo (project memory)

Personal, **macOS-first** dotfiles. Config is deployed as dotbot symlinks; the machine is
bootstrapped over SSH by `RUNME.sh` → `install.sh`. Linux/Arch support is aspirational and
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
- **`config/claude/`** = the user's **live global `~/.claude`**, force-symlinked in
  (`symlinks.yaml:16`). Editing anything under it mutates **live, machine-wide Claude Code
  state**. Only 11 files are tracked (`settings.json`, `hooks/notify.sh`, `skills/labrador/*`,
  a few `.gitkeep`s); runtime state (sessions, history, projects, cache) lives in the working
  tree but is gitignored via **two** layers — root `.gitignore` + `config/claude/.gitignore`.
  **Never `git add`** that runtime state.

## Footguns (destructive / surprising)

- **`force: true` symlinks destroy pre-existing files.** `~/.zshenv`, `~/.zshrc`, and `~/.claude`
  are `force: true` (`symlinks.yaml:12,13,16`) → dotbot `rm`/`rmtree`s any real file or dir
  already at that path, **no backup, no prompt**. Adopting these dotfiles on a machine that
  already has a real `~/.claude` **destroys it**.
- **`clean: ['~', '${XDG_CONFIG_HOME}']`** (`symlinks.yaml:6`) deletes dangling symlinks under
  those roots on every run.
- **`install.sh` has no `set -e`.** Steps fail silently and the green "configured successfully"
  banner **always** prints. Don't read exit success as proof each step worked.
- **`brew upgrade` (`install.sh:108`) upgrades every installed formula/cask**, not just Brewfile
  entries.
- **`macos-openwhispr.sh:70`** strips the Gatekeeper quarantine flag
  (`xattr -dr com.apple.quarantine`) from a freshly-downloaded, unsigned `.app`.

## Submodule drift is expected, not damage

Three submodules (`.gitmodules`): `lib/dotbot`, `lib/tpm` (upstream tools) and `config/nvim`
(the user's **own** fork, `git@github.com:1henrypage/nvim`). `install.sh:91` runs
`git submodule update --recursive --remote --init`; `--remote` fast-forwards them (and their
nested `pyyaml` / `tmux-test`) past their pinned SHAs on every run. The `m` beside `lib/dotbot`
and `lib/tpm` in `git status` is that nested drift — **harmless, not a manual edit; don't blindly
commit it.**

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
- Bootstrap is **SSH-only** (`git@github.com:…`). `RUNME.sh` hardcodes the `1henrypage` identity
  and `config/general/.gitconfig` hardcodes `Henry Page` / `dev@henrypage.com` — a forker must
  edit both.
- No build or test harness — it's configs plus POSIX-ish install scripts. Verify any claim by
  reading the file it cites; the working tree often carries uncommitted WIP, so `git blame` on a
  live config can mislead.
