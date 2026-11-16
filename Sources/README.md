# Swift 核心（待实现）

计划入口：`MouseScrollToggle.swift`。仅使用 Foundation、CoreGraphics、ApplicationServices。将分类和增量变换提取为可单测纯函数；通过 CGEventTap 与 RunLoop 工作，不轮询、不模拟重复事件。实现权限检查、有界恢复、健康状态和信号退出。具体约束见 ../docs/requirements.md。
