---
name: code-simplify
description: 审核代码可读性与复杂度，重点识别 AI 编程常见问题：过度设计、过度抽象、命名晦涩、注释失衡、重复类型、冗余代码、防御代码过多、单次使用却过度封装，以及超出项目需求的复杂度。用于"代码审核""简化代码""可读性优化""重构过度设计""删减废弃代码"或 code review；如无特殊说明，默认审查当前工作区未提交改动。
version: 0.0.2
author: yolanda
---

# Code Simplify

执行"以减法为先"的代码审查。目标不是补更多结构，而是让代码更短、更直白、更贴近当前项目规模。

## User Input Tools

When this skill prompts the user, follow this tool-selection rule (priority order):

1. **Prefer built-in user-input tools** exposed by the current agent runtime — e.g., `AskUserQuestion`, `request_user_input`, `clarify`, `ask_user`, `questionnaire`, or any equivalent.
2. **Fallback**: if no such tool exists, emit a numbered plain-text message and ask the user to reply with the chosen number/answer for each question.
3. **Batching**: if the tool supports multiple questions per call, combine all applicable questions into a single call; if only single-question, ask them one at a time in priority order.

Concrete tool names above are examples — substitute the local equivalent in other runtimes.

## Core Principles

- 先判断能不能删，再判断要不要改。
- 没有真实复用、真实约束、真实变化来源的抽象，默认可疑。
- 不为假想场景保留当前复杂度。
- 结论必须落到文件、位置、影响和建议动作。

## Default Scope

1. 默认审查当前工作区未提交改动，包含暂存、未暂存和未跟踪文件。
2. 用户指定文件、目录、提交或 PR 时，以用户指定范围为准。
3. 如果工作区没有改动，明确告知并请求用户提供范围。

## Key Checks

- **可读性与命名**：必须检查文件职责是否过多、函数是否过长、嵌套是否过深、阅读跳转是否过多。文件名、目录名、函数名、参数名必须短、直白、贴近职责；不得使用过长、过虚、过抽象的命名。需要结合上下文猜含义，或名称明显长于职责本身时，必须判定为问题，并直接给出更短、更直白的替代建议。
- **类型复杂度**：必须检查重复 type/interface、类型链路过长、为少量数据引入过重泛型或条件类型。一个类型技巧如果没有明显提升安全性，必须优先建议简化、内联或就近定义。
- **过度设计**：必须检查单实现场景下的 adapter、factory、strategy、registry、状态机、插件化等结构。一个抽象只有一个实现，或一个配置层、工具层只是在转发参数或常量时，必须优先建议删除、合并、内联。
- **防御代码**：必须检查重复 fallback、重复校验，以及为极小概率情况保留的大量 silent fail 或 early return。一个 fallback 如果只是为了“以防万一”，不得默认保留；必须优先建议移除，只保留真实边界校验。
- **冗余代码**：必须检查废弃实现、临时兼容逻辑、相似代码散落、新旧实现并存。没有明确退场计划的兼容代码，必须优先建议删除或收敛。
- **拆分失衡**：必须检查只调用一次的函数、Hook、工具层、转发层。一个函数、Hook、类型只有一个使用方，且没有明显降低复杂度时，不得视为有效抽象；必须优先建议内联或合并。
- **注释失衡**：简单说明必须优先使用 `//` 单行注释，不得用长段注释解释简单逻辑。单文件的重要逻辑块、关键分支、边界处理，必须补 `//`。对外暴露函数、跨模块接口、复杂流程函数，必须使用 JSDoc。通用 `type/interface` 除了说明用途，关键字段也必须补充单行注释。
- **保留复杂度的例外**：仅当复杂度直接服务于安全边界、协议契约或核心业务约束，且删除后会明显降低正确性、可维护性或可测试性时，才允许保留。

## Execution Flow

1. 确定审查范围。
2. 先给总体判断：偏简单、基本合理，还是明显过度设计。
3. 按严重程度列问题，优先级使用“高 / 中 / 低”。
4. 每条问题必须写清：
   问题类型、文件位置、现象、影响、建议动作。
5. 建议动作必须具体，如：删除、内联、合并、改名、缩短类型链路、减少 fallback、移除旧实现。
6. 没有问题时，明确写“未发现明显可读性/复杂度问题”，并说明剩余风险或未覆盖范围。
7. 输出报告后等待用户决定改部分还是全部，再动手修改。

## Content Rules & Output Template

- 必须先列发现，再给简短总结。
- 不得只说“可以优化”或“建议重构”，必须明确指出该删什么、并什么、为什么。
- 问题本质是设计超标时，必须直接指出，不得因为代码能运行就忽略结构负担。

```md
总体判断：本次改动存在中度过度设计，主要问题是抽象层级偏多、单次使用封装过多，已经影响阅读速度。

| 编号 | 优先级 | 问题类型 | 文件位置 | 现象 | 影响 | 建议动作 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 高 | 过度设计 | `src/...:12` | 为单一实现引入 adapter + factory | 调用链变长，理解成本高 | 直接内联为顺序调用，删除 adapter/factory |
| 2 | 高 | 废弃代码 | `src/...:48` | 旧实现已无调用 | 增加维护噪音 | 删除旧实现及相关类型 |
| 3 | 中 | 防御代码过多 | `src/...:73` | 上下游重复空值兜底 | 分支增多，真实约束变模糊 | 保留一处边界校验，移除重复 fallback |

简短总结：
- 应优先删除无效抽象和旧代码，再决定是否需要局部重构。
- 如果你要我继续，我可以按编号执行“部分修改”或“全部修改”。
```
