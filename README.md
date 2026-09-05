# Agent Skills

Portable, versioned skills for Codex, Antigravity, and other file-based coding agents.

This repository is the portable snapshot of my personal global skills. It currently contains:

- Direct user skills from `~/.agents/skills`, including skills installed with the Vercel Skills CLI.
- Portable, non-system Codex skills from `~/.codex/skills`.

Codex system skills, plugin caches, MCP configuration, and plugin hooks are intentionally not copied here. Install those separately when they are needed.

## Install on a new device

```bash
git clone git@github.com:AnasX7/skills.git
cd skills
mkdir -p ~/.agents/skills
rsync -a --exclude='.git/' --exclude='/README.md' ./ ~/.agents/skills/
```

Restart the agent if the new skills do not appear immediately.

## Update the repository

After installing or updating direct global skills, synchronize them back into this repository, review the diff, and commit it:

```bash
rsync -a --delete --exclude='.git/' --exclude='/README.md' ~/.agents/skills/ ./
git add .
git commit -m "Sync global skills"
git push origin main
```

Keep custom skills such as `nestjs-better-auth` in this repository so they are included in the next-device snapshot.
