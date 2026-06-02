# AwesomeWeldoneSkills

Agent Skills marketplace for the Weldone welding robotics team.

Each top-level directory is a skill. See [CONTRIBUTING.md](../CONTRIBUTING.md) for skill creation guidelines.

## Structure

- Each skill directory contains `SKILL.md` (required) plus optional `scripts/`, `references/`, `assets/`
- `catalog.json`: machine-readable index of all skills
- `skill-creator/`: meta-skill for creating and validating new skills

## When Working in This Repo

- Skills must have `SKILL.md` with at minimum `name` and `description` frontmatter
- The `name` field must match the directory name (lowercase, hyphens, max 64 chars)
- Run `python skill-creator/scripts/quick_validate.py <skill-dir>` to validate
- Update `catalog.json` when adding or modifying skills
