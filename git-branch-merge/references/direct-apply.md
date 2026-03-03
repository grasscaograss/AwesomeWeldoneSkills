# 直接迁移指南（不开 spec）

当改动简单且目的明确时，直接将源分支的改动迁移到目标分支，无需通过 opsx:new。

## 适用场景

- 配置文件、依赖版本更新（.csproj, global.json, appsettings.json）
- 单文件 bug fix，diff 清晰可读
- 注释/文档改动
- 工具类新增方法（不影响现有接口）

## 操作步骤

1. 读取源分支的 diff：

```bash
# 查看单个提交
git show <hash>

# 查看多个提交涉及某文件的变更
git diff <merge-base>..<source> -- <file-path>
```

2. 理解改动内容，在目标分支的对应文件手动应用
3. 构建验证：`dotnet build`
4. 更新进度文件

## 注意事项

- 不要盲目 copy-paste diff，要理解上下文再应用
- 目标分支的文件结构可能和源分支不同，需要适配
- 应用过程中发现比预期复杂时，停下来改用 opsx:new
