# OpenClaw Mac 自动安装

这个项目用于在一台全新的 Mac 上安装 OpenClaw 及常用工作依赖，并安全合并自定义 workspace 和 skills。v1 面向零基础用户：有一个总入口，过程有日志，已安装内容尽量跳过，原配置发生冲突时先备份。

详细说明见 [docs/自动化安装-v1.md](docs/自动化安装-v1.md)。原始安装笔记保留作背景参考，不建议再逐行复制其中命令。

## 最简单的使用方法

1. 把整个项目复制到新 Mac，并确保放在本机可写目录中。
2. 双击根目录的 `install.command`。
3. macOS 如果提示无法打开：右键 `install.command`，选择“打开”，再确认一次。
4. 按终端提示输入本机管理员密码。密码只交给 macOS，不会保存到项目或日志。
5. OpenClaw 引导出现后，按需选择模型并输入自己的 API key。
6. 安装结束后，根据终端列出的“仍需人工完成”逐项操作。

管理员密码、API key、订阅链接都不要发给别人，也不要写进本项目。

## 命令行入口

先打开“终端”，把项目文件夹拖到终端窗口取得路径，然后执行：

```bash
cd /你的项目路径/openclaw-scripts
./scripts/install.sh
```

第一次安装建议先预览：

```bash
./scripts/install.sh --dry-run
```

常用模式：

```bash
# 正常交互安装
./scripts/install.sh

# 不打开模型登录引导，安装后再配置账号
./scripts/install.sh --non-interactive

# 禁止下载，只使用已经安装的内容和 bin 中的离线附件
./scripts/install.sh --offline

# 从中断的模块继续
./scripts/install.sh --from 40-work-tools

# 只重新合并 workspace 和 OpenClaw 配置
./scripts/install.sh --only 50-workspace,70-openclaw-config

# 只做验收，不安装
./scripts/install.sh --verify-only
```

`--offline` 不是“全套离线安装”：Homebrew、Node、npm 包、VS Code 扩展和部分 OpenClaw 组件没有离线缓存。全新 Mac 首次安装仍建议联网。

## 自动化范围

安装器分为以下模块：

| 模块 | 内容 |
| --- | --- |
| `00-preflight` | 检查 macOS、CPU、磁盘和 Apple Command Line Tools |
| `05-proxy-client` | 校验并安装 FlClash App，订阅和系统授权仍由用户完成 |
| `10-network` | 自动探测 `127.0.0.1:7890`，添加 `proxy_on` / `proxy_off` |
| `20-base` | Homebrew、基础命令、iTerm2、VS Code、Codex/Claude Code CLI |
| `25-shell` | Oh My Zsh、两个提示插件和 Powerlevel10k |
| `30-runtimes` | Node 24、Python 3.13、可选 Java 18 |
| `40-work-tools` | npm/Python 工具、Playwright、VS Code 扩展 |
| `50-workspace` | 合并 workspace 和自定义 skills，冲突前备份 |
| `60-openclaw` | OpenClaw CLI/App 和首次初始化 |
| `70-openclaw-config` | 备份、合并并校验 OpenClaw 配置，安装插件/skills |
| `90-verify` | 最终验收 |

仍需人工完成的主要是 macOS 隐私/VPN 授权、代理订阅、模型/API key、GitHub 登录，以及 Codex/Claude 的账号配置。脚本不能也不应绕过这些系统或账号确认。默认工作工具模式会安装 Codex 与 Claude Code CLI；关闭工作工具时，验收只会提醒它们缺失。Codex/Claude CLI 的登录和第三方 provider 始终由用户配置；OpenClaw 自身的可选模型目录由 `INSTALL_MODEL_CATALOG` 单独控制。

## 修改默认选项

常用开关在 `config/install.conf`：代理模式、是否安装工作工具、FlClash/Rosetta、OpenClaw App、VS Code 扩展、模型目录、默认模型、执行策略和 workspace Git 地址。`INSTALL_MODEL_CATALOG=false` 可完全跳过参考电脑的 DeepSeek/4SAPI 模型目录。

软件及扩展清单在 `config/packages.conf`，第三方 skills 在 `config/openclaw/third-party-skills.conf`。修改后先运行：

```bash
./scripts/install.sh --dry-run
```

v1 不猜测默认模型，`OPENCLAW_DEFAULT_MODEL` 默认留空；执行策略默认 `keep`，不会静默改成完全放行。

## 安装后

```bash
./scripts/verify.sh
openclaw config validate
openclaw doctor --lint
openclaw skills check
```

日志默认保存在：

```text
~/Library/Logs/openclaw-bootstrap/
```

日志会尝试隐藏常见密钥格式，但分享日志前仍应人工检查。
