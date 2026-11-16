# MouseScrollToggle

macOS 普通鼠标滚轮反转工具，使用 Swift + Zsh，由一条 macOS 快捷指令手动切换，触摸板继续保持自然滚动。

**当前状态：项目初始化，尚未实现可运行功能。** 目标版本为 v1.0.0，支持 Apple Silicon / Intel；实际系统版本和设备兼容性待验证。当前不能安装或导入快捷指令。

## 文档导航

- [完整需求与原始开发规划](docs/requirements.md)：原文完整保留，作为需求基线。
- [架构与实现约束](docs/architecture.md)
- [开发阶段与任务清单](docs/development-plan.md)
- [验收测试规范](docs/acceptance-tests.md)
- [测试报告](docs/test-report.md)
- [安装与卸载设计](docs/installation.md)
- [权限说明](docs/permissions.md)
- [故障排查设计](docs/troubleshooting.md)
- [快捷指令集成](Shortcuts/README.md)
- [已知限制与待决策项](docs/known-limitations.md)

## 仓库布局

`Sources/` 保存 Swift 核心；`Scripts/` 保存 Zsh 控制脚本；`Shortcuts/` 保存自包含载荷与操作说明；`Tests/` 保存自动化用例；`docs/` 保存需求、设计和验收记录。各目录当前只有说明文件，计划中的程序和脚本尚未创建。

执行 `make help` 查看当前入口。功能开发后必须尝试编译和自动化测试，真实硬件测试单独记录，不能用模拟事件代替。

不修改全局自然滚动、不使用 sudo、不安装登录启动项、不依赖 Homebrew 或第三方 Swift 包。许可证尚未选定，当前不声明开源授权。
