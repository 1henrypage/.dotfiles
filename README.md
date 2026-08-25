## One-Line Install (Fresh System)

This setup supports **completely fresh machines** with nothing installed except `curl`.

### Run:

```bash
curl -fsSL https://raw.githubusercontent.com/1henrypage/.dotfiles/main/RUNME.sh | bash
```

This installs the **personal** profile: base packages/config plus personal apps (VPN, social,
media, etc.) and a wholesale, force-linked `~/.claude`.

### Corporate / work machine

For a work machine, pass `--corporate` through to `install.sh`:

```bash
curl -fsSL https://raw.githubusercontent.com/1henrypage/.dotfiles/main/RUNME.sh | bash -s -- --corporate
```

This installs only the base package/config set, clones and fetches submodules over HTTPS instead
of SSH, and links `~/.claude/CLAUDE.md` + `~/.claude/skills` individually (no `force`, no
wholesale link) so a pre-provisioned enterprise `~/.claude` survives. See
[`.claude/ARCHITECTURE.md`](.claude/ARCHITECTURE.md) §9 for the full split.

## Requirements
Git identity (name/email) is prompted on first run and never hardcoded in the repo.

The **personal** profile requires an SSH key configured on GitHub (`RUNME.sh` clones over SSH).
The **corporate** profile (`--corporate`) clones and fetches submodules over HTTPS instead, so no
SSH key is required.
