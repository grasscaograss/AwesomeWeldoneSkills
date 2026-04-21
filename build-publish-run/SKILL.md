---
name: build-publish-run
description: 项目构建、发布和运行工作流。当用户请求编译(build/compile)、发布(publish/deploy)、运行(run/start/launch)项目,或询问如何构建、发布、运行项目时使用。支持完整的开发工作流:构建项目、发布构建产物、在 Windows 环境运行已发布的应用。
---

# 构建项目

编译项目并生成构建产物:

```bash
just build
```

# 发布项目

发布构建产物到目标位置:

```bash
just publish
```

# 运行项目

**注意**: 运行命令仅在 Windows 环境下可用。

运行已发布的项目:

```bash
just run-pub
```

不加载插件运行(使用 `-np` 标志):

```bash
just run-pub -np
```

# 故障排查

如果执行上述命令遇到问题:

1. 读取项目根目录的 `justfile` 文件
2. 分析具体的任务定义和依赖关系
3. 检查错误信息并根据 `justfile` 中的配置调整命令
