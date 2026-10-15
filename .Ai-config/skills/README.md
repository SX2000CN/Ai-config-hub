# Legacy skills directory

This directory is retained as a migration and cleanup candidate. Do not add Skill content here.

For ordinary target projects, this repository's convention is to store a complete Agent Skill package in `.agents/skills/<name>/`; `.Ai-config/skills-registry.md` records package paths and client adapters. This repository's own packages live in `skills/shared/<name>/`. `.agents/skills/` is a discovery path supported by some clients, not a path prescribed by the Agent Skills format. Claude Code uses an exported package under `.claude/skills/`.

The hub's own global Skill packages remain under `skills/shared/<name>/` because they are source packages owned by this repository. Their rendered copies are adapters, not additional sources.
