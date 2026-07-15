#!/usr/bin/env python3
"""
migrate_to_contexts.py — 把扁平知识库迁移到多上下文（A1）结构。

读 context→domain 映射，把
    archive/knowledge/<domain>/
搬进
    archive/contexts/<ctx>/knowledge/<domain>/
并生成 archive/CONTEXT-MAP.md 骨架、各上下文 CONTEXT.md 占位、重写 INDEX.md 路径与交叉引用。

用法（在项目仓库根目录运行）：
    python migrate_to_contexts.py --map weld-core:weld-seam,weld-template,wsg-merge,transition-line,dual-arm \
                                  --map robotics:coordinate,coarse-positioning \
                                  --map orchestration:workflow,scanning \
                                  --map peripheral:frontend,device-robot,capacity,weld-tracking,tools
    python migrate_to_contexts.py --map-file archive/CONTEXT-MAP.md   # 从已有映射读
    python migrate_to_contexts.py --dry-run ...                        # 只打印计划，不写盘

设计：
- 幂等：已是 A1 结构（存在 archive/contexts/）时安全跳过/报错。
- 不碰 archive/CONTEXT.md 的内容拆分（需判断，留给 agent/人）——只改名留作 .legacy，
  并为每个上下文生成空 CONTEXT.md 占位，供 /domain-modeling 填充。
- 可回退：所有移动用 git mv（若在 git 仓库内），便于 git checkout 回退。

注意：本脚本只做机械搬运 + 路径重写；术语表拆分、语义判断不在范围内。
"""
from __future__ import annotations
import argparse, json, os, re, sys
from pathlib import Path

# Windows 控制台默认 GBK 会把警告符号等非 ASCII 字符编爆；强制 stdout/stderr 用 UTF-8
try:
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    sys.stderr.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
except Exception:
    pass


def parse_map(items: list[str]) -> dict[str, list[str]]:
    """['weld-core:a,b', 'robotics:c'] -> {'weld-core': ['a','b'], ...}"""
    out: dict[str, list[str]] = {}
    for it in items or []:
        ctx, _, domains = it.partition(":")
        ctx = ctx.strip()
        if not ctx:
            sys.exit(f"非法 --map 值：{it!r}（应为 ctx:dom1,dom2）")
        out[ctx] = [d.strip() for d in domains.split(",") if d.strip()]
    return out


def parse_map_file(path: Path) -> dict[str, list[str]]:
    """从 CONTEXT-MAP.md 的列表项解析 context→domain。容忍多种写法。"""
    if not path.exists():
        sys.exit(f"--map-file 不存在：{path}")
    text = path.read_text(encoding="utf-8")
    out: dict[str, list[str]] = {}
    # 匹配 [Label](./contexts/<ctx>/CONTEXT.md) 行
    cur = None
    for line in text.splitlines():
        m = re.search(r"contexts/([a-z0-9-]+)/CONTEXT\.md", line)
        if m and "- " in line:
            cur = m.group(1)
            out.setdefault(cur, [])
            continue
    # 兜底：再扫一次 contexts/<ctx>/ 出现过的目录名
    # （domain 名通常不出现在 MAP，只在后续真实目录里；这里只取上下文名）
    return out


def git_mv(src: Path, dst: Path, dry: bool) -> bool:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        print(f"  [跳过-已存在] {dst}")
        return False
    in_git = (src.parent / ".git").exists() or _repo_root_has_git(src)
    if dry:
        print(f"  [dry] mv {src} -> {dst}")
        return True
    if in_git:
        os.system(f'git mv "{src}" "{dst}"')
    else:
        import shutil
        shutil.move(str(src), str(dst))
    return True


def _repo_root_has_git(p: Path) -> bool:
    for parent in p.resolve().parents:
        if (parent / ".git").exists():
            return True
    return False


def rewrite_paths(root: Path, old_to_new: dict[str, str], dry: bool, verbose=True):
    """在所有 .md 里把知识路径前缀 old→new，单次扫描避免对替换结果二次匹配。
    old_to_new 键是仓库相对路径，如 'archive/knowledge/weld-seam'。
    同时处理仓库相对（archive/knowledge/...）与 archive 相对（knowledge/...）两种前缀形式。
    用 regex 一次匹配所有旧前缀（长前缀优先），按查表重写——替换后的新串不会被再次扫描。
    """
    # 构造 (old, new) 对，含两种前缀形式
    pairs = []
    for old, new in old_to_new.items():
        pairs.append((old, new))
        if old.startswith("archive/"):
            pairs.append((old[len("archive/"):], new[len("archive/"):]))
    # 去重 + 长前缀优先
    seen = set()
    uniq = []
    for o, n in pairs:
        if o not in seen:
            seen.add(o)
            uniq.append((o, n))
    uniq.sort(key=lambda p: -len(p[0]))
    lookup = {o: n for o, n in uniq}
    pattern = re.compile("|".join(re.escape(o) for o, _ in uniq))

    files = [f for f in root.rglob("*.md") if ".git" not in f.parts]
    changed = []
    for f in files:
        try:
            orig = f.read_text(encoding="utf-8")
        except Exception:
            continue
        t = pattern.sub(lambda m: lookup[m.group(0)], orig)
        if t != orig:
            changed.append(f)
            if not dry:
                f.write_text(t, encoding="utf-8")
    if verbose:
        for f in changed:
            print(f"  [改路径] {f.relative_to(root)}")
    return changed


def build_context_map(ctx_domains: dict[str, list[str]], descriptions: dict[str, str] | None = None) -> str:
    descriptions = descriptions or {}
    lines = ["# Context Map", ""]
    lines += ["## Contexts", ""]
    for ctx, doms in ctx_domains.items():
        desc = descriptions.get(ctx, "")
        lines.append(f"- [{ctx}](./contexts/{ctx}/CONTEXT.md){' — ' + desc if desc else ''}")
    lines += ["", "## Shared kernels", ""]
    lines += ["_（待 /domain-modeling 填充：哪些术语跨上下文共享、谁拥有、谁引用）_", ""]
    lines += ["## Relationships", ""]
    lines += ["_（待 /domain-modeling 填充：上下文间依赖、事件流向）_", ""]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description="迁移扁平知识库到多上下文 A1 结构")
    ap.add_argument("--map", action="append", default=[],
                    help='ctx:dom1,dom2 （可多次）。如 weld-core:weld-seam,wsg-merge')
    ap.add_argument("--map-file", help="从该 CONTEXT-MAP.md 读上下文名（domain 仍需 --map 或真实目录）")
    ap.add_argument("--archive-root", default="archive", help="知识库根（默认 archive）")
    ap.add_argument("--dry-run", action="store_true", help="只打印计划，不写盘")
    ap.add_argument("--legacy-context", action="store_true",
                    help="把现有扁平 archive/CONTEXT.md 改名为 .legacy（不自动拆分，留给 agent）")
    args = ap.parse_args()

    root = Path.cwd()
    archive = root / args.archive_root
    flat_knowledge = archive / "knowledge"
    contexts_root = archive / "contexts"

    ctx_domains = parse_map(args.map)
    if args.map_file and not ctx_domains:
        ctx_domains = {c: [] for c in parse_map_file(Path(args.map_file))}

    # 1. 状态检测
    if contexts_root.exists() and any(contexts_root.iterdir()):
        print("⚠ 检测到 archive/contexts/ 已存在内容——可能已是 A1 结构。用 --dry-run 复核，或手动处理。")
        if not args.dry_run:
            sys.exit("中止：目标已是多上下文结构。")

    if not flat_knowledge.exists() and not ctx_domains:
        sys.exit("既无 archive/knowledge/ 又无 --map，无可迁移。")

    # 没给 domain 列表时，从现有扁平目录推断（每个目录名待用户归类）
    if flat_knowledge.exists():
        existing = sorted(d.name for d in flat_knowledge.iterdir() if d.is_dir())
    else:
        existing = []
    if not ctx_domains and existing:
        sys.exit("未提供 --map。请提供 context→domain 映射，例如：\n  --map weld-core:weld-seam,wsg-merge "
                 + "\n现有扁平领域：" + ", ".join(existing))

    print(f"=== 迁移计划{'（dry-run）' if args.dry_run else ''} ===")
    print(f"扁平源: {flat_knowledge}")
    print(f"A1 目标: {contexts_root}/<ctx>/knowledge/<domain>/")
    plan_moves: dict[str, str] = {}
    unmapped: list[str] = []
    mapped_domains = set()
    for ctx, doms in ctx_domains.items():
        for dom in doms:
            src = flat_knowledge / dom
            dst = contexts_root / ctx / "knowledge" / dom
            # 统一用正斜杠（markdown 路径约定），且必须是仓库相对路径
            plan_moves[src.relative_to(root).as_posix()] = (root / dst).relative_to(root).as_posix()
            mapped_domains.add(dom)
            print(f"  {dom:24s} -> {ctx}/")
    unmapped = [d for d in existing if d not in mapped_domains]
    if unmapped:
        print("⚠ 未归类的扁平领域（不会被移动，需补充 --map）：" + ", ".join(unmapped))

    if args.dry_run:
        print("\n[dry-run] 到此为止，未写盘。")
        return

    # 2. 执行移动
    print("\n=== 执行移动 ===")
    for ctx, doms in ctx_domains.items():
        for dom in doms:
            src = flat_knowledge / dom
            if not src.exists():
                print(f"  [缺] {src} 不存在，跳过")
                continue
            dst = contexts_root / ctx / "knowledge" / dom
            git_mv(src, dst, args.dry_run)

    # 3. 每个上下文 CONTEXT.md 占位
    print("\n=== 生成上下文 CONTEXT.md 占位 ===")
    for ctx in ctx_domains:
        cctx = contexts_root / ctx / "CONTEXT.md"
        if not cctx.exists():
            cctx.parent.mkdir(parents=True, exist_ok=True)
            cctx.write_text(f"# {ctx}\n\n_（术语表占位，由 /domain-modeling 填充）_\n\n## Language\n\n", encoding="utf-8")
            print(f"  [建] {cctx.relative_to(root)}")

    # 4. CONTEXT-MAP.md
    cmap = archive / "CONTEXT-MAP.md"
    print("\n=== 生成 CONTEXT-MAP.md 骨架 ===")
    if not cmap.exists():
        cmap.write_text(build_context_map(ctx_domains), encoding="utf-8")
        print(f"  [建] {cmap.relative_to(root)}")
    else:
        print(f"  [跳过-已存在] {cmap.relative_to(root)}")

    # 5. 扁平 CONTEXT.md -> .legacy
    flat_ctx = archive / "CONTEXT.md"
    if args.legacy_context and flat_ctx.exists():
        leg = archive / "CONTEXT.md.legacy"
        print(f"\n=== 扁平 CONTEXT.md -> {leg.name}（拆分留给 agent）===")
        if not leg.exists():
            import shutil
            shutil.move(str(flat_ctx), str(leg))
            print(f"  [改名] {flat_ctx.relative_to(root)} -> {leg.name}")

    # 6. 重写 INDEX.md 与交叉引用里的路径
    print("\n=== 重写路径引用 ===")
    rewrite_paths(root, plan_moves, args.dry_run)

    print("\n=== 完成 ===")
    print("下一步（本脚本不做的判断性工作）：")
    print("  1. /knowledge-reorg inspect 复核结构")
    print("  2. 用 /domain-modeling 把 CONTEXT.md.legacy 的术语拆进各上下文 CONTEXT.md")
    print("  3. 填充 archive/CONTEXT-MAP.md 的共享内核与关系")
    print("  4. git diff 复核，git checkout 可回退")


if __name__ == "__main__":
    main()
