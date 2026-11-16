# Zsh 脚本

build.sh 编译到 build/；install.sh 安装；control.sh 控制；uninstall.sh 卸载；common.sh 共享锁、状态及生命周期。所有脚本使用 Zsh，不依赖 Homebrew。

完整协议、路径与退出码见 [安装指南](../docs/installation.md)。测试专用 MST_TEST_MODE、MST_TEST_CTL、MST_TEST_BUILD、MST_TEST_LABEL 仅用于隔离适配层；正常运行不要设置。MST_VERSION 只供直接安装的测试/调试指定版本文本；快捷指令正常使用 VERSION，不应设置此变量。

Phase 3：generate-shortcut.sh 从 manifest.sh 的固定文件集合生成纯文本载荷；click.sh 持有一次控制锁并调用内部 installer.sh 的 install_main，复用控制函数。install_main 在子 Shell 中隔离 EXIT trap，不再次获取控制锁；所有准备步骤保留 errexit，事务替换步骤显式检查失败。独立 install.sh 也使用同一个安装器。manifest.sh 记录 bundle 摘要，VERSION 是唯一产品版本来源；核心 --version 返回 core-protocol=1（协议标识，避免仅版本文本变化导致重编译）。测试适配层设置 MST_TEST_MODE=1 并提供独立服务名；MST_TEST_BUILD 可选，未提供时仍使用真实编译器。

Phase 4：doctor.sh 独立读取系统/安装信息；runtime.sh 只定义共用函数，common.sh 负责正常入口的目录初始化与锁。医生诊断在未安装时不创建配置目录；存在控制锁时等待最多10秒，健康检查只允许短暂 service.txt/request/response 写入及服务级 SIGUSR1，不创建 Tap、不提示授权、不启停、不恢复。报告是快照，权限是当前调用上下文的权限，服务仍需独立挑战。默认路径以 ~ 脱敏；`--full-paths` 输出实际日志/可执行恢复命令。退出0表示报告完成，不表示健康；忙碌75，参数64。普通输出不含窗口、按键或点击内容。

共用安装器在未加载服务时，先取得核心锁再准备事务，前台占锁拒绝不会产生无意义未完成事务。common.sh 在 chmod 之前拒绝配置目录符号链接，避免改变外部目录权限。

核心协议/权限及编译器版本探测各有约2秒上限，挂起则报告 UNKNOWN；诊断临时输出文件使用私有目录并在退出清理。工具链探测先检查开发目录，不执行 xcode-select --install。
