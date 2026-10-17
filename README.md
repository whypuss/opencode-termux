# OpenCode for Termux 🚀

[![Termux](https://img.shields.io/badge/Platform-Termux%20(Android)-171b20.svg?logo=android&logoColor=white)](https://termux.dev/)
[![Arch](https://img.shields.io/badge/Arch-aarch64%20%7C%20x86__64-blue.svg)](https://github.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

一键在 **Android / Termux** 环境中原生安装并流畅运行 [OpenCode AI](https://opencode.ai/) 终端智能编程助手！无需 Root 权限，无需安装体积庞大且损耗性能的 PRoot / Ubuntu 完整容器，轻量原生秒级启动。

---

## 💡 为什么需要本项目？

官方的 OpenCode 安装脚本（`curl -fsSL https://opencode.ai/v2/install | bash`）直接在 Termux 中执行时会遇到以下问题：

1. **动态链接器不匹配（C库不兼容）**：OpenCode CLI 基于 Bun 运行时编译，依赖标准 Linux glibc，而 Android 底层使用的是 Bionic libc，直接运行会提示 `No such file or directory` 或 `bad ELF interpreter`。
2. **后台守护进程（Daemon）崩溃**：OpenCode CLI 依赖后台服务（`opencode serve --service`）管理多会话与状态，Bun 自带的进程分离和 `child_process` 在 Termux 中直接衍生子进程会被终端断开或因权限退出。

### 🛠️ 本项目的解决方案

- **极速轻量**：通过 Termux 官方维护的 `glibc-runner` (`grun`) 直接加载 OpenCode 原生 glibc 二进制文件，保留极致性能，内存占用低。
- **智能托管包装器**：提供完善的 `opencode` 启动脚本，自动通过 `setsid` 守护和管理后台 `serve` 服务，无缝转发所有 CLI 命令与参数。
- **双通道网络加速**：内置官方 npm 与国内高速 npmmirror 镜像测速与回退，国内手机也能秒级下载完成。
- **一键全局可用**：自动创建软链接到 `$PREFIX/bin/opencode` 并追加 PATH，安装完成后终端任意路径直接输入 `opencode` 即可使用。

---

## ⚡ 一键安装 (One-Click Install)

在 Termux 终端中复制并运行以下命令：

```bash
curl -fsSL https://raw.githubusercontent.com/whypuss/opencode-termux/main/install.sh | bash
```

> 🇨🇳 **国内用户加速通道**（如果无法直接访问 GitHub Raw）：
> ```bash
> curl -fsSL https://ghproxy.net/https://raw.githubusercontent.com/whypuss/opencode-termux/main/install.sh | bash
> ```

---

## 📦 手动 / 克隆安装 (Manual Install)

如果你希望克隆仓库后在本地安装：

```bash
# 1. 克隆本仓库
git clone https://github.com/whypuss/opencode-termux.git
cd opencode-termux

# 2. 赋予执行权限并运行安装脚本
chmod +x install.sh
bash install.sh
```

### 高级安装参数

```bash
# 指定安装特定版本 (如 v2.0.32)
bash install.sh --version 2.0.32

# 强制使用国内 npmmirror 镜像源
bash install.sh --mirror npmmirror

# 强制使用官方 npm 源
bash install.sh --mirror npm
```

---

## 🎮 使用指南 (Usage)

安装成功后，你可以直接使用 `opencode` 命令：

```bash
# 1. 启动交互式 TUI 编程界面
opencode

# 2. 查看支持的 AI 模型列表
opencode models

# 3. 查看 Token 使用统计
opencode stats

# 4. 查看当前后台服务状态
opencode service status

# 5. 手动停止/启动/重启后台守护进程
opencode service stop
opencode service start
opencode service restart

# 6. 查看帮助与版本
opencode --version
opencode --help
```

---

## 🔋 手机保活与注意事项

1. **防止后台被杀**：在进行长时间任务或让 OpenCode 处理大型项目前，建议在 Termux 终端中运行：
   ```bash
   termux-wake-lock
   ```
   这可以防止 Android 系统进入睡眠模式挂起 CPU。
2. **电池优化设置**：建议在 Android 系统设置中将 Termux 应用的电池策略设为“无限制”或“允许后台运行”。
3. **架构支持**：支持 `aarch64` (ARM64, 大多数现代 Android 手机) 与 `x86_64` (模拟器或 PC)。32位架构（如 armv7l）由于官方未提供二进制包，暂不支持。

---

## 🗑️ 卸载 (Uninstall)

如需卸载 OpenCode：

```bash
# 使用本地卸载脚本
bash uninstall.sh

# 或者彻底清除所有用户配置、缓存与日志
bash uninstall.sh --purge
```

---

## 📂 项目结构 (Repository Structure)

```
opencode-termux/
├── bin/
│   └── opencode         # Termux 启动包装器脚本 (Supervisor & Runner)
├── install.sh           # 一键全自动安装脚本
├── uninstall.sh         # 一键卸载脚本
├── LICENSE              # MIT 开源协议
└── README.md            # 项目使用说明文档
```

---

## 📄 License

本项目基于 [MIT License](LICENSE) 开源发布。OpenCode 及其相关商标归原作者所有。
