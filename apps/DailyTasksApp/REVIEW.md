# Code Review for `DailyTasksApp.swift`

以下是对当前代码（按需求原样使用）给出的 review 建议，未直接改动主文件逻辑：

1. `NavigationView` 与 `presentationMode` 在新版本 SwiftUI 中可迁移到 `NavigationStack` + `dismiss`。
2. `TaskManager` 的 `tasksKey`/持久化方法可考虑 `private`，降低外部误用风险。
3. 删除任务时在 View 层通过 `firstIndex` 反查后构造 `IndexSet`，可在 `TaskManager` 增加 `deleteTask(id:)` 简化。
4. 统计页对完成率做了两次同公式计算，可提炼为计算属性，提升可读性。
5. `AddTaskView` 只 `trim` 空格，若输入换行也应视为空，可考虑 `whitespacesAndNewlines`。

> 当前仓库中的 `DailyTasksApp.swift` 保持与用户提供代码一致，以上仅为 review 建议。
