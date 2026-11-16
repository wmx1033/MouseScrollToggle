# Zsh 脚本

build.sh 编译到 build/；install.sh 安装；control.sh 控制；uninstall.sh 卸载；common.sh 共享锁、状态及生命周期。所有脚本使用 Zsh，不依赖 Homebrew。

完整协议、路径与退出码见 [安装指南](../docs/installation.md)。测试专用 MST_TEST_MODE、MST_TEST_CTL、MST_TEST_BUILD、MST_TEST_LABEL 仅用于隔离适配层；正常运行不要设置。MST_VERSION 只供直接安装的测试/调试指定版本文本；快捷指令正常使用 VERSION，不应设置此变量。

Phase 3：generate-shortcut.sh 从 manifest.sh 的固定文件集合生成纯文本载荷；click.sh 持有一次控制锁并调用内部 installer.sh 的 install_main，复用控制函数。install_main 在子 Shell 中隔离 EXIT trap，不再次获取控制锁；所有准备步骤保留 errexit，事务替换步骤显式检查失败。独立 install.sh 也使用同一个安装器。manifest.sh 记录 bundle 摘要，VERSION 是唯一产品版本来源；核心 --version 返回 core-protocol=1（协议标识，避免仅版本文本变化导致重编译）。测试适配层设置 MST_TEST_MODE=1 并提供独立服务名；MST_TEST_BUILD 可选，未提供时仍使用真实编译器。
