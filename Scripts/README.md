# Zsh 脚本

build.sh 编译到 build/；install.sh 安装；control.sh 控制；uninstall.sh 卸载；common.sh 共享锁、状态及生命周期。所有脚本使用 Zsh，不依赖 Homebrew。

完整协议、路径与退出码见 [安装指南](../docs/installation.md)。测试专用 MST_TEST_MODE、MST_TEST_CTL、MST_TEST_BUILD、MST_TEST_LABEL 仅用于隔离适配层；正常运行不要设置。MST_VERSION 可指定版本文本。
