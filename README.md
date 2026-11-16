# MouseScrollToggle

macOS 普通鼠标滚轮反转工具，使用 Swift + Zsh，由一条 macOS 快捷指令手动切换，触摸板继续保持自然滚动。

**当前状态：Phase 1 核心已实现并通过编译及最小自动化测试，真实设备未验证。** 目标版本为 v1.0.0，支持 Apple Silicon / Intel；实际系统版本和设备兼容性待验证。当前可手动编译运行核心，安装与快捷指令留待后续阶段。

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

`Sources/` 保存 Swift 核心；`Scripts/` 保存 Zsh 控制脚本；`Shortcuts/` 保存自包含载荷与操作说明；`Tests/` 保存自动化用例；`docs/` 保存需求、设计和验收记录。已提供 Swift 核心、编译脚本与最小测试；安装和启停脚本尚未实现。

执行 `make help` 查看当前入口。功能开发后必须尝试编译和自动化测试，真实硬件测试单独记录，不能用模拟事件代替。

不修改全局自然滚动、不使用 sudo、不安装登录启动项、不依赖 Homebrew 或第三方 Swift 包。许可证尚未选定，当前不声明开源授权。

## Phase 1 本机开发

```sh
make build
make test
./build/mousescrolltoggle --check-permission
./build/mousescrolltoggle
# 可选逐事件诊断（仅调试时开启）
./build/mousescrolltoggle --verbose
```

首次运行可能需要在系统设置 → 隐私与安全性 → 辅助功能中手动授权后重试。前台运行，Ctrl-C 停止；本阶段不安装服务、不自动启动。请仅运行一个实例（跨进程防重复由 Phase 2 实现）。普通模式只输出启动/错误状态，不输出每次滚动；详细模式输出到 stderr，不自动保存日志。

退出码：0 正常结束；2 未授权；3 Event Tap/RunLoop 初始化失败；4 运行中恢复失败；64 参数错误。`--check-permission` 不弹授权请求。READY 仅表示初始化时 Tap 已启用，不是 Phase 2 持续健康协议。
