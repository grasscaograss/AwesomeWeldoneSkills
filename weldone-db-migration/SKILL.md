---
name: weldone-db-migration
description: Weldone 数据库迁移守护 skill；当拉取最新代码、实体/DbContext/配置出现数据库字段或表结构变化、运行时报缺列/缺表/模型快照不一致、或 AI 准备直接修改数据库/schema 来“补字段”时使用。强制先检查 EF Core 迁移状态并优先执行 just update-db；执行 just migrate 前必须先 dump PostgreSQL 到动态 APPDATA 备份目录，禁止绕过迁移自说自话改数据库结构。
---

# Weldone Db Migration

## Overview

规范处理 Weldone 项目的数据库结构同步问题。优先遵循仓库已有 EF Core migration 与 `justfile` 数据库任务，避免直接往 PostgreSQL 里添加字段、建表、改约束或手写 schema 修复。

当最新代码包含数据库模型变更但本地数据库未同步时，执行迁移更新数据库；当代码确实缺少迁移时，先明确需要新增 migration，不要伪造数据库状态；当需要运行 DbMigrator 时，先备份数据库以防数据丢失。

## Trigger Conditions

触发此 skill 当出现以下任一情况：

- 拉取、切换、合并代码后，用户提到没有执行 `update-db`、数据库结构不匹配、缺字段、缺表、migration 没跑。
- 运行、测试、启动报错包含 `column does not exist`、`relation does not exist`、`42703`、`42P01`、`pending migrations`、`The model backing the context has changed`、`Npgsql.PostgresException` 等数据库 schema 相关信号。
- 任务涉及修改 Entity、`WeldoneDbContext`、EF Core configuration、migration、seed data、数据库枚举、索引、约束或外键。
- 准备通过 SQL、脚本、Adminer、psql、数据库客户端或硬编码逻辑直接补字段、补表、改 schema。
- 准备执行 `just migrate` 或需要判断“代码最新但数据库不是最新”还是“代码缺少 migration”。

## Hard Rules

- 禁止直接向数据库添加业务字段、表、索引、约束或外键来匹配代码，除非用户明确要求手工 SQL，并且说明这是临时修复。
- 禁止把数据库缺字段问题修成代码 fallback、忽略字段、空值兜底或删除属性，除非确认需求就是代码回滚。
- 优先执行仓库任务：`just update-db`；需要种子数据时，必须先备份 PostgreSQL 数据库，再执行 `just migrate`。
- 需要新增迁移时使用：`just add-m <MigrationName>`，不要手写 migration 文件替代 EF 生成结果。
- 回滚或移除迁移时使用：`just remove-m` 或 `just update-db <MigrationName>`，不要删除 migration 文件后假装完成。
- 执行数据库命令前，先确认工作目录为 Weldone 仓库根目录；默认是 `D:\weldone`，如项目位于其他路径，给脚本传入 `-RepoRoot <路径>`。
- `migrate` 前备份路径必须从 `$env:APPDATA` 拼接到 `Roboticplus\Weldone\backup-db`，禁止写死 `C:\Users\<用户名>`。
- 备份文件名必须使用当前时间生成，格式为 `ai-backup-before-migrate-yyyy-MMdd-HHmm-ssff.backup`，不要复用固定示例名。
- 遇到数据库连接失败，优先检查 PostgreSQL 是否启动、连接串配置和 `just pod`，不要改模型或迁移。

## Workflow

### 1. Classify the Failure

先判断问题类型：

- **本地数据库落后**：migration 已存在，但数据库未应用。执行 `just update-db`。
- **需要种子数据**：schema 已更新，但基础数据、权限、配置或默认记录缺失。先备份，再执行 `just migrate`。
- **代码缺少 migration**：实体或 DbContext 变化存在，但 migration 列表没有对应变更。先运行检查，再用 `just add-m <Name>` 生成 migration。
- **连接/环境问题**：数据库不可达、认证失败、连接串错误、容器未启动。先修环境，不改 schema。

### 2. Inspect Before Acting

运行快速检查：

```powershell
powershell -ExecutionPolicy Bypass -File <skill>/scripts/check-db-migration-state.ps1 -RepoRoot D:\weldone
```

检查输出中的：

- `Recent migrations`：确认最新 migration 是否已经在代码中。
- `Changed EF-related files`：判断是否可能需要 migration。
- `Recommended next command`：优先执行建议命令。

### 3. Apply Existing Migrations

当已有 migration 但本地数据库未更新时，在 Weldone 仓库根目录执行：

```powershell
just update-db
```

如果需要更新到指定 migration：

```powershell
just update-db <MigrationName>
```

执行后重试原来的启动、测试或复现命令。

### 4. Backup Before Seed or Repair Data

当 schema 正确但缺少种子数据、默认配置、权限或初始化记录时，执行 `just migrate` 前必须先 dump PostgreSQL 数据库，防止 DbMigrator 或 seed 逻辑导致数据丢失。

使用本 skill 的备份脚本，自动计算当前用户的 APPDATA 路径，并将 `just backup-db` 产生的备份重命名为 AI 专用文件名：

```powershell
powershell -ExecutionPolicy Bypass -File <skill>/scripts/backup-before-migrate.ps1 -RepoRoot D:\weldone
```

备份目标目录：

```powershell
Join-Path $env:APPDATA "Roboticplus\Weldone\backup-db"
```

备份文件名格式：

```text
ai-backup-before-migrate-yyyy-MMdd-HHmm-ssff.backup
```

示例形态：`ai-backup-before-migrate-2026-0411-1037-0121.backup`。日期部分必须使用当前时间生成，不要写死示例值。

备份成功并记录实际输出文件后再执行：

```powershell
just migrate
```

不要用 `INSERT` 手工补系统种子数据，除非用户明确要求一次性数据库修复。

### 5. Generate a Missing Migration

当实体、DbContext 或 EF 配置已经变更，但没有对应 migration 时：

1. 取一个语义明确的 migration 名称，如 `AddWeldProcessTemplateFields`。
2. 执行：

```powershell
just add-m <MigrationName>
```

3. 检查生成的 migration 是否只包含预期 schema 变化。
4. 执行：

```powershell
just update-db
```

5. 重试原问题。

## Common Error Mapping

| Signal | Meaning | Action |
|---|---|---|
| `column ... does not exist` / `42703` | 数据库缺字段 | 先 `just update-db`，不要手工 `ALTER TABLE ADD COLUMN` |
| `relation ... does not exist` / `42P01` | 数据库缺表 | 先 `just update-db`，必要时备份后 `just migrate` |
| `pending migrations` | migration 未应用 | `just update-db` |
| `model backing the context has changed` | 模型和 migration 不一致 | 检查是否缺 migration；必要时 `just add-m <Name>` |
| 连接拒绝 / auth failed | 数据库环境问题 | 检查 PostgreSQL、连接串、`just pod` |
| 种子数据、权限、菜单缺失 | 初始化数据缺失 | 先备份到 `$env:APPDATA\Roboticplus\Weldone\backup-db`，再 `just migrate` |

## Weldone Commands

数据库任务由 Weldone 仓库根目录 `justfile` 提供：

```powershell
just add-m <Name>       # 添加 EF Core migration
just remove-m          # 移除最近一次 migration
just update-db         # 更新数据库到最新 migration
just update-db <Name>  # 更新/回滚到指定 migration
just backup-db         # 备份数据库；migrate 前必须先执行备份
just migrate           # 运行 DbMigrator 创建/刷新种子数据
just pod               # 启动本地 PostgreSQL 容器
```

## Implementation Notes

- EF Core 项目：`src/Weldone.EntityFrameworkCore`。
- DbContext：`WeldoneDbContext`。
- DbMigrator 项目：`src/Weldone.DbMigrator`。
- justfile 的 EF helper 会进入 `src/Weldone` 后执行 `dotnet ef ... --project Weldone.EntityFrameworkCore --context WeldoneDbContext`。
- `backup-db.ps1` 默认按数据库名和时间戳生成 `.backup` 文件；执行 `migrate` 前使用本 skill 的 `scripts/backup-before-migrate.ps1` 统一改名为 `ai-backup-before-migrate-<当前日期>.backup`。
- 业务修复应提交 migration 文件和代码变更；本地数据库执行状态通常不提交。

## Response Pattern

处理此类问题时，简洁说明：

1. 判断为 migration 未应用、缺 migration、seed 缺失或环境问题。
2. 列出实际执行的命令；如果执行 `migrate`，必须列出备份目录和实际备份文件名。
3. 明确没有手工改数据库 schema。
4. 说明复验结果或下一步需要用户提供的错误日志。

示例：

```text
这是种子数据缺失问题，不应该手工补表或补字段。我已先备份数据库到 `%APPDATA%\Roboticplus\Weldone\backup-db\ai-backup-before-migrate-<当前日期>.backup`，再执行 `just migrate`，没有直接改 schema；现在可以重试启动命令。
```

