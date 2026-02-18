# Agent Skills

Reusable skills for AI coding agents.

This repo is tool-agnostic: the same skill folders can be used with Codex, Claude Code, or any agent framework that supports file-based skills/instructions.

## Why This Repo Exists

- Keep a portable, versioned backup of my skills
- Reuse the same skill set across multiple laptops
- Track improvements and updates in git

## What Is Inside

- Skill folders with `SKILL.md` instructions
- System and custom skills
- Supporting assets/scripts for specific skills

## Quick Start

1. Clone this repo:
   - `git clone https://github.com/AnasX7/skills.git`
2. Copy the skill folders to your agent's skills directory.
3. Restart your agent tool (if required) so it reloads skills.

## Common Skill Directories

Use the path that matches your agent environment:

- Codex: `~/.codex/skills` (Windows: `C:\Users\<you>\.codex\skills`)
- Claude Code: `~/.claude/skills`
- Other agents: your platform's configured skills/instructions directory

## Sync Workflow Across Machines

1. On machine A, update skills and commit:
   - `git add .`
   - `git commit -m "Update skills"`
   - `git push origin main`
2. On machine B, pull latest:
   - `git pull origin main`
3. Re-copy or sync files into that machine's agent skills directory.

## Notes

- Some skills are process-oriented (planning, debugging, reviews).
- Some skills are domain-oriented (auth, UI, framework-specific work).
- Keep skill names and folder structure stable to avoid broken references.
