# Contributing to AwesomeWeldoneSkills

## Adding a New Skill

1. Initialize using the skill-creator skill:
   ```bash
   python skill-creator/scripts/init_skill.py <skill-name> --path .
   ```
2. Edit `SKILL.md` — fill in `name` and `description` frontmatter (required)
3. Ensure `name` matches the directory name exactly
4. Naming rules: lowercase letters, digits, hyphens only; max 64 chars; no leading/trailing/consecutive hyphens
5. Description: max 1024 chars; describe what the skill does AND when to use it
6. Run validation:
   ```bash
   python skill-creator/scripts/quick_validate.py <skill-directory>
   ```
7. Add an entry to `catalog.json` under the appropriate category
8. Submit MR

## Skill Quality Checklist

- [ ] `SKILL.md` has valid frontmatter with `name` and `description`
- [ ] `name` matches directory name
- [ ] `name` is hyphen-case (lowercase letters, digits, hyphens)
- [ ] `description` is concise and explains WHEN to use the skill
- [ ] No hardcoded secrets or credentials
- [ ] `metadata` includes `author` and `version`
- [ ] If skill uses specific tools, `allowed-tools` is set

## Updating Existing Skills

1. Edit `SKILL.md` in the skill directory
2. Run validation
3. Update `catalog.json` if description changed
4. Submit MR

## License

By contributing, you agree your skill is licensed under Apache 2.0
unless you specify otherwise in the skill's `license` frontmatter field.
