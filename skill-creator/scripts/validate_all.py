#!/usr/bin/env python3
"""
Batch validation script for all skills in the marketplace.
Iterates all top-level directories containing SKILL.md and validates each one.
"""

import sys
import os
from pathlib import Path

# Add parent directory to path for importing quick_validate
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quick_validate import validate_skill


def find_skills(repo_root: Path) -> list[Path]:
    """Find all skill directories (containing SKILL.md) at repo root."""
    skills = []
    for item in sorted(repo_root.iterdir()):
        if item.is_dir() and not item.name.startswith('.'):
            skill_md = item / 'SKILL.md'
            if skill_md.exists():
                skills.append(item)
    return skills


def main():
    if len(sys.argv) > 1:
        repo_root = Path(sys.argv[1])
    else:
        repo_root = Path(__file__).resolve().parent.parent.parent

    if not repo_root.is_dir():
        print(f"Error: {repo_root} is not a directory")
        sys.exit(1)

    skills = find_skills(repo_root)
    if not skills:
        print("No skills found.")
        sys.exit(1)

    passed = 0
    failed = 0
    results = []

    for skill_path in skills:
        valid, message = validate_skill(skill_path)
        status = "PASS" if valid else "FAIL"
        results.append((skill_path.name, status, message))
        if valid:
            passed += 1
        else:
            failed += 1

    # Print results
    max_name = max(len(r[0]) for r in results)
    for name, status, message in results:
        icon = "ok" if status == "PASS" else "!!"
        print(f"  [{icon}] {name:<{max_name}}  {message}")

    print(f"\n{'='*60}")
    print(f"Total: {len(skills)}  Passed: {passed}  Failed: {failed}")

    if failed > 0:
        print("\nValidation FAILED. Fix the issues above and retry.")
        sys.exit(1)
    else:
        print("\nAll skills are valid!")
        sys.exit(0)


if __name__ == "__main__":
    main()
