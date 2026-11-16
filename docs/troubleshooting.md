# 故障排查

已提供 Scripts/doctor.sh（核心二进制本身不实现 --doctor），报告 macOS、架构、Swift 编译器、安装版本、二进制存在性、辅助功能权限、launchctl 服务、进程与 Event Tap 状态。

| 现象 | 诊断与预期处理 |
|---|---|
| 无法编译 | 显示编译器输出与工具链检查结果，保留旧安装 |
| 启动失败 | 检查权限、服务域和 Event Tap，明确原因 |
| 服务在但没有反转 | 检查核心健康和实际 continuous 分类，不能仅查 PID |
| 平滑鼠标无变化 | 连续事件按设计放行，说明兼容性限制 |
| 休眠后失效 | 检查禁用事件与恢复上限，超限报告 ERROR |
| 升级后授权失效 | 引导重新授权；不得隐藏失败或无限重启 |
| 重复点击异常 | 检查控制操作串行化和重复实例保护 |

详细模式只记录 continuous、classification、action 等必要滚动诊断，普通模式不逐事件输出。不记录键盘、点击内容、窗口标题。日志必须控制大小。使用 control.sh status 查询当前健康；查看 ~/Library/Logs/MouseScrollToggle/stderr.log。配置冲突时先备份并移走 agent.plist。doctor.sh 已实现，使用方式见下文。

前台核心占用：status 显示 ERROR；先在前台 Ctrl-C，重试 stop。不要删除 core.lock；陈旧 PID 文件不会触发停止信号。

更新或恢复失败：按 stderr 给出的备份路径和 `/bin/zsh …/recover.sh` 命令恢复；先解决 bootout、辅助功能授权或目录写权限问题。恢复脚本会再次确认服务与核心均停止，再复制旧快照；恢复失败仍保留备份。完整说明见 installation.md。

快捷指令：成功结果只来自最终健康检查；Shell 动作失败时查看其错误详情，不要继续显示成功。提示旧载荷拒绝降级时替换最新完整载荷；提示未完成事务时先运行给出的恢复脚本。若缺少 swiftc，手动安装 Xcode Command Line Tools。同步仅复制快捷指令文本，第二台 Mac 仍需独立编译和授权。创建、脚本许可与 iCloud 设置见 Shortcuts/README.md。

Phase 4 诊断：`./Scripts/doctor.sh` 或 `/bin/zsh Shortcuts/shortcut-payload.sh --doctor`。报告完成的退出0不表示程序健康，必须读取 TAP/SERVICE/PROCESS 等字段。UNKNOWN 是缺少可靠信息；DENIED 是该调用上下文明确未授权；NOT_LOADED/NOT_RUNNING 是未加载/未运行；服务存在但挑战失败为 ERROR。PERMISSION=AUTHORIZED 与 TAP=ERROR 可同时出现，说明不能据该宿主权限推断 launchd 健康。默认报告隐藏个人路径，分享前仍检查版本文本/自定义配置；需要复制人工恢复命令时使用仓库 doctor.sh --full-paths。

前台 `--verbose` 必须先停止服务，否则单实例锁拒绝第二个 Tap。它只记录 continuous/classification/action，不识别物理 HID 来源；测试后 Ctrl-C，再按需恢复服务。不要把连续设备放行当作反转失效，也不要为了测试禁用 SIP 或全局自然滚动。
