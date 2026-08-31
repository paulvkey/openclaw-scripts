# Mac安装openclaw与配置--详细版

> [!WARNING]
> 本文是旧版人工安装记录，仅用于背景参考。部分流程仍有固定版本、整文件覆盖和已经变化的界面，不要在新 Mac 上逐行复制执行。当前推荐使用项目根目录 `install.command`，并先阅读 [《自动化安装 v1》](自动化安装-v1.md)。API key、管理员密码和代理订阅不要写入仓库。

## 说明

*   此文档是详细的安装文档，除了一些有配置更改的地方，其他均可以按照步骤操作
    
    *   配置更改包括：带用户名的路径、各种key、github设置等
        
*   **前置依赖**
    
    *   **科学上网：**[《科学上网》](https://alidocs.dingtalk.com/i/nodes/7dx2rn0JbYoDgbm7F2XMgRMNVMGjLRb3?utm_scene=person_space)
        
    *   **国内模型（选择一个即可，示例使用deepseek）：**
        
        *   **deepseek：**[https://api-docs.deepseek.com/zh-cn/](https://api-docs.deepseek.com/zh-cn/)
            
        *   **kimi：**[https://platform.kimi.com/](https://platform.kimi.com/)
            
    *   **4sapi（国外模型，claude和gpt）：**[https://4sapi.com/](https://4sapi.com/)
        
    *   **tavily（网络搜索）：**[https://www.tavily.com/](https://www.tavily.com/)
        

### 基础环境

*   下面脚本包含了brew、iTerm2、git、zsh、autojump、wget 、vim、tmux等
    

```json
# 国内因为网络问题可能导致安装异常所以需要配置代理（代理分为三部分：电脑、终端、openclaw，且统一使用7890这个端口）
# 先在机器上开启科学上网（一定要是非大陆和非香港），然后执行后面命令
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
export ALL_PROXY=socks5://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export all_proxy=socks5://127.0.0.1:7890

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
BREW_BIN="$(command -v brew || { [ "$(uname -m)" = arm64 ] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew; })"
grep -Fq "$BREW_BIN shellenv" "$HOME/.zprofile" 2>/dev/null || echo "eval \"\$($BREW_BIN shellenv)\"" >> "$HOME/.zprofile"
eval "$($BREW_BIN shellenv)"
brew --version

export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_PIP_INDEX_URL="https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple"

brew update
yes | brew install --cask iterm2
yes | brew install git tmux vim wget ripgrep
RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ] || git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
[ -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ] || git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
[ -d "$ZSH_CUSTOM_DIR/themes/powerlevel10k" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM_DIR/themes/powerlevel10k"

echo 'ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)
source ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
autoload -Uz compinit && compinit' >> ~/.zshrc

echo 'export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
export ALL_PROXY=socks5://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export all_proxy=socks5://127.0.0.1:7890' >> ~/.zshrc
echo '# 重置官方 cd "$(brew --repo)" && git remote set-url origin https://github.com/Homebrew/brew.git
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_PIP_INDEX_URL="https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple"' >> ~/.zshrc
source ~/.zshrc

```

### 基础依赖

*   基础依赖包含：nvm（管理node.js版本）、node.js 24版本、python 3.13、pnpm、java18
    

```json
brew install nvm
echo 'export NVM_DIR="$HOME/.nvm"
[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
[ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"' >> ~/.zshrc
source ~/.zshrc && nvm -v && nvm install 24.15.0 && nvm use 24.15.0 && nvm alias default 24.15.0 && node --version

brew install pnpm && pnpm config set registry https://registry.npmmirror.com && pnpm -v && source ~/.zshrc

V=18.0.2.1; J="/Library/Java/JavaVirtualMachines/jdk-$V.jdk/Contents/Home"; [ -x "$J/bin/java" ] || { W="$(mktemp -d "${TMPDIR:-/tmp}/jdk-install.XXXXXX")"; D="$W/jdk.dmg"; M="$W/mount"; curl -fsSL -o "$D" "https://download.oracle.com/java/${V%%.*}/archive/jdk-${V}_macos-aarch64_bin.dmg" && hdiutil verify "$D" && mkdir -p "$M" && hdiutil attach -readonly -nobrowse -quiet -mountpoint "$M" "$D" && sudo installer -pkg "$M/JDK $V.pkg" -target /; S=$?; hdiutil detach -quiet "$M" 2>/dev/null || true; rm -f -- "$D"; rmdir "$M" "$W" 2>/dev/null || true; [ "$S" -eq 0 ]; } && (grep -q "jdk-$V" ~/.zshrc || { echo "export JAVA_HOME=\"$J\"" >> ~/.zshrc; echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc; }) && source ~/.zshrc && java --version

V=3.13.15; P="/Library/Frameworks/Python.framework/Versions/${V%.*}"; [ "$($P/bin/python3 --version 2>/dev/null)" = "Python $V" ] || { W="$(mktemp -d "${TMPDIR:-/tmp}/python-install.XXXXXX")"; D="$W/python.pkg"; curl -fsSL -o "$D" "https://www.python.org/ftp/python/$V/python-$V-macos11.pkg" && echo "3b7eaf7f29825f796e8267024435540ddf1f17fc9a97ad58095daa7a75bfdcd3  $D" | shasum -a 256 -c - && sudo installer -pkg "$D" -target /; S=$?; rm -f -- "$D"; rmdir "$W" 2>/dev/null || true; [ "$S" -eq 0 ]; } && mkdir -p ~/.local/bin && export PATH="$HOME/.local/bin:$PATH" && ln -sfn "$P/bin/python3" ~/.local/bin/python && ln -sfn "$P/bin/pip3" ~/.local/bin/pip && (grep -q "$P/bin" ~/.zprofile || echo "PATH=\"$P/bin:\${PATH}\"" >> ~/.zprofile) && (grep -q UV_PYTHON_PREFERENCE ~/.zshrc || echo 'export UV_PYTHON_PREFERENCE="system"' >> ~/.zshrc) && source ~/.zprofile && python --version && pip --version && uv python find

[ -d "/Applications/Visual Studio Code.app" ] || { W="$(mktemp -d "${TMPDIR:-/tmp}/vscode-install.XXXXXX")"; D="$W/VSCode.dmg"; M="$W/mount"; curl -fSL -o "$D" "https://code.visualstudio.com/sha/download?build=stable&os=darwin-arm64-dmg" && hdiutil verify "$D" && mkdir -p "$M" && hdiutil attach -readonly -nobrowse -quiet -mountpoint "$M" "$D" && sudo ditto "$M/Visual Studio Code.app" "/Applications/Visual Studio Code.app"; S=$?; hdiutil detach -quiet "$M" 2>/dev/null || true; rm -f -- "$D"; rmdir "$M" "$W" 2>/dev/null || true; [ "$S" -eq 0 ]; }; [ -d "/Applications/Visual Studio Code.app" ] && echo "✅ VSCode 安装完成" || echo "❌ 安装失败,请检查上方输出"


```

*   如果jdk和python下载有问题，可以使用已经下载好的手动安装
    
    [请至钉钉文档查看附件《jdk-18.0.2.1\_macos-aarch64\_bin.dmg》。](https://alidocs.dingtalk.com/i/nodes/Amq4vjg8905mLXMpUmXNrb0lJ3kdP0wQ?doc_type=wiki_doc&iframeQuery=anchorId%3DX02mr2tubx7uicp4fl50w)
    
    [请至钉钉文档查看附件《python-3.13.15-macos11.pkg》。](https://alidocs.dingtalk.com/i/nodes/Amq4vjg8905mLXMpUmXNrb0lJ3kdP0wQ?doc_type=wiki_doc&iframeQuery=anchorId%3DX02msrbnjpltmsivu79v68)
    
*   vscode：[https://code.visualstudio.com/](https://code.visualstudio.com/)
    
    *   安装下面左侧三个插件来使用claude code或者codex（安装好之后重启生效），之后右上角就可以用了
        
        *   ![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/a2QnV4jGBx55DO4X/img/128a1b69-9398-4415-a8a4-85809c48a8ae.png)
            

### 平台

#### openclaw

*   下面命令包含安装openclaw、openclaw客户端、系统工具、openclaw plugins和skills，最后会有登录github的输入(可选)
    

```json
# 第一步选择yes，第二步选择yes -> more -> deepseek，第三步测试后可以直接退出(ctrl + c)
curl -fsSL https://openclaw.ai/install.sh | bash
# 如果想要重新配置相关内容，执行openclaw onboard --install-daemon

V=2026.7.1; [ -d "/Applications/OpenClaw.app" ] || { W="$(mktemp -d "${TMPDIR:-/tmp}/openclaw-install.XXXXXX")"; D="$W/OpenClaw-$V.dmg"; M="$W/mount"; curl -fSL -o "$D" "https://github.com/openclaw/openclaw/releases/download/v$V/OpenClaw-$V.dmg" && hdiutil verify "$D" && mkdir -p "$M" && hdiutil attach -readonly -nobrowse -quiet -mountpoint "$M" "$D" && sudo ditto "$M/OpenClaw.app" "/Applications/OpenClaw.app"; S=$?; hdiutil detach -quiet "$M" 2>/dev/null || true; rm -f -- "$D"; rmdir "$M" "$W" 2>/dev/null || true; [ "$S" -eq 0 ]; }; [ -d "/Applications/OpenClaw.app" ] && echo "✅ OpenClaw 安装完成" || echo "❌ 安装失败,请检查上方输出"

yes | brew install gh jq uv graphviz
yes | brew install pandoc
brew install pandoc-crossref
npm i -g clawhub
npm i -g acpx
npm i -g mcporter
npm i -g playwright
npm i -g @playwright/mcp
npm i -g @anthropic-ai/claude-code
npm i -g wavedrom-cli
npx playwright install chromium
pip install debugpy markitdown
pip install openpyxl pandas python-docx python-pptx

openclaw update
openclaw plugins install acpx
openclaw plugins install browser
openclaw plugins install tavily
openclaw skills install @eddygk/skill-vetting
openclaw skills install @ivangdavila/self-improving
openclaw skills install @hw10181913/claude-code
openclaw skills install @spiceman161/playwright-mcp
openclaw skills install @biostartechnology/humanizer
openclaw skills install @alex3alex/openclaw-backup
openclaw skills install @ivangdavila/excel-xlsx
openclaw skills install @ivangdavila/word-docx
openclaw skills install @ivangdavila/powerpoint-pptx
openclaw skills install @steipete/markdown-converter
openclaw skills install @oswalpalash/ontology

openclaw security audit
openclaw security audit --deep
# 先阅读上面两份报告；确认修复项不会覆盖现有配置后，再按需执行 openclaw security audit --fix

# Node 路径由前面的 nvm 配置管理，不写死具体 Node 安装目录
command -v openclaw && openclaw --version

gh auth login
```

*   如果openclaw的app下载异常(需要科学上网)可以使用已经下载好的手动安装
    
    [请至钉钉文档查看附件《OpenClaw-2026.7.1.dmg》。](https://alidocs.dingtalk.com/i/nodes/Amq4vjg8905mLXMpUmXNrb0lJ3kdP0wQ?doc_type=wiki_doc&iframeQuery=anchorId%3DX02mryeiqw8qmr59w3val)
    
*   **注意：openclaw客户端不要使用app的弹窗更新(会导致安装路径不一致后续无法使用)**
    
    *   关闭客户端更新：
        
        *   ![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/a2QnV4jGBx55DO4X/img/f69e5b49-e175-4c6d-b27f-043836ec620a.png)
            
    *   命令行更新：`openclaw update`
        
*   openclaw配置
    
    *   权限
        
        *   ![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/a2QnV4jGBx55DO4X/img/2fbf24d5-74e1-497a-8378-229af332ea8c.png)
            
        *   ![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/a2QnV4jGBx55DO4X/img/d6665ca7-ccce-4bee-91a6-3e6fa1da84a9.png)
            
    *   内置skills
        
        *   ![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/a2QnV4jGBx55DO4X/img/2bbbcf2f-2237-4613-bd31-2e2c3708814a.png)
            
        *   仅保留：`clawhub、coding-agent、diagram-maker、github、healthcheck、mcporter、meme-maker、nano-pdf、node-connect、node-inspect-debugger、python-debugpy、session-logs、skill-creator、spike、taskflow、taskflow-inbox-triage、tmux、browser-automation、canvas`
            
            *   可以让AI操作
                
*   同步远端github的workspace到openclaw本地（**创建git仓库需要项目名为workspace**）
    
    *   第一台电脑上传workspace到github的时候需要注意编写`.gitignore`文件，参考内容如下：
        

```python
# OpenClaw internal state
.openclaw/
state/

# Daily memory notes (contain conversation history)
memory/

# Dreams / internal agent state
DREAMS.md

# Python cache
__pycache__/
*.pyc

# Claude sub-project (separate repo)
claude/

# ClawHub cache
.clawhub/

.DS_Store
.learnings/
.openclaw-repair/
```

#### 第三方

1.  deepseek或者gpt
    
    1.  deepseesk-v4-pro 作为默认模型
        
        1.  deepseek在第一次安装openclaw选择模型的时候直接选择安装即可
            
        2.  如果安装的时候没有选择，后续配置参考 [https://docs.openclaw.ai/zh-CN/providers/deepseek](https://docs.openclaw.ai/zh-CN/providers/deepseek)
            
            1.  `openclaw onboard --auth-choice deepseek-api-key`
                
    2.  gpt参考后面的codex
        
2.  4sapi：[https://4sapi.com/console](https://4sapi.com/console)
    
    1.  提供国外claude、gpt等模型API访问
        
        1.  claude模型分组建议选择`claude-code企业级`，gpt模型分组建议选择`gpt综合分组`，多个模型需要多个不同key，其他的不用修改
            
        2.  ![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/a2QnV4jGBx55DO4X/img/00573212-428a-4cc3-aa6c-93b3fda99bf0.png)
            
3.  tavily：[https://app.tavily.com/home](https://app.tavily.com/home)
    
    1.  提供网络搜索，已经处理好相关网页的搜索结果（每个月免费1000次调用额度）
        
    2.  注册账号生成key，终端执行路径：`openclaw onboard --install-daemon` -> 保留现有模型配置 -> 暂时跳过 -> Tavily Search -> 输入key即可
        
4.  企业微信：[https://open.work.weixin.qq.com/help2/pc/21657](https://open.work.weixin.qq.com/help2/pc/21657)
    
5.  钉钉：[https://open.dingtalk.com/document/development/build-dingtalk-ai-employees](https://open.dingtalk.com/document/development/build-dingtalk-ai-employees)
    

#### claude code

*   说明：下面是主动选择4sapi时的旧版手工示例；自动安装v1不会为Claude Code CLI写入第三方provider或登录凭据，优先按当前官方登录方式配置
    
*   使用参考：
    
    *   目录结构：[https://code.claude.com/docs/zh-CN/claude-directory](https://code.claude.com/docs/zh-CN/claude-directory)
        
    *   命令：[https://code.claude.com/docs/zh-CN/commands](https://code.claude.com/docs/zh-CN/commands)
        
*   安装和配置
    

```shell
curl -fsSL https://claude.ai/install.sh | bash

mkdir -p ~/.claude
[ ! -f ~/.claude.json ] || cp -p ~/.claude.json ~/.claude.json.before-manual-edit
[ ! -f ~/.claude/settings.json ] || cp -p ~/.claude/settings.json ~/.claude/settings.json.before-manual-edit

echo '{
  "hasCompletedOnboarding": true
}' > ~/.claude.json

echo '{
  "env": {
    "ANTHROPIC_BASE_URL": "https://4sapi.com",
    "ANTHROPIC_MODEL": "claude-opus-4-8",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-opus-4-8",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-8",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-opus-4-8",
    "ANTHROPIC_REASONING_MODEL": "claude-opus-4-8"
  },
  "includeCoAuthoredBy": false,
  "permissions": {
    "allow": [],
    "deny": [],
    "defaultMode": "default"
  },
  "language": "Chinese",
  "theme": "auto"
}' > ~/.claude/settings.json

echo 'export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
export ANTHROPIC_BETA_FEATURES=""' >> ~/.zshrc && source ~/.zshrc

# 仅当已明确选择4sapi时输入；密钥只在当前终端会话生效，不写入仓库或shell配置
read -r -s -p "输入4sapi Claude key: " ANTHROPIC_AUTH_TOKEN; echo
export ANTHROPIC_AUTH_TOKEN

```

*   4sapi秘钥（key）
    
    *   ![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/a2QnV4jGBx55DO4X/img/7d09610d-21b9-471f-99a1-a816520e391c.png)
        

*   高级配置（按需配置）
    
    *   [CLAUDE.md](https://alidocs.dingtalk.com/i/nodes/nYMoO1rWxa6eNQBMHjXdlEOOV47Z3je9?utm_scene=person_space)（放在每个项目的根目录生效）（可选）
        

*   **Skills安装**
    

```python
cd ~/.openclaw && claude

# 下面的命令需要一行一行复制使用（多行会异常）
/plugin marketplace add https://github.com/affaan-m/ECC
/plugin marketplace add thedotmack/claude-mem
/plugin install ecc
/plugin install claude-mem
/plugin install code-simplifier
/plugin install skill-creator
```

#### codex配置

*   说明：下面是主动选择4sapi时的旧版手工示例；自动安装v1不会为Codex CLI写入第三方provider或登录凭据，默认可使用 `codex login --device-auth` 官方登录
    
*   使用参考：
    
    *   文档：[https://learn.chatgpt.com/docs/codex/cli](https://learn.chatgpt.com/docs/codex/cli)
        
    *   配置：[https://learn.chatgpt.com/docs/config-file/config-basic](https://learn.chatgpt.com/docs/config-file/config-basic)
        
*   安装和配置（配置好之后vscode和cli都可以使用）
    

```python
# 以下第三方provider示例只在公司策略允许并已确认隐私、费用和Responses API兼容性时使用
cd ~/.openclaw && curl -fsSL https://chatgpt.com/codex/install.sh | sh

mkdir -p ~/.codex
[ ! -f ~/.codex/config.toml ] || cp -p ~/.codex/config.toml ~/.codex/config.toml.before-manual-edit
CODEX_PROJECT_PATH="$HOME/.openclaw"

cat > ~/.codex/config.toml <<EOF
# 全局默认配置
model_provider = "4sapi"
# 调用的模型，请确保该模型 ID 在 4SAPI 控制台中存在
model = "gpt-5.6-sol"

# 4SAPI 模型供应商配置
[model_providers.4sapi]
name = "4SAPI"
base_url = "https://4sapi.com/v1"
# 请不要把4SAPI的key放到这里，不要修改这里
# 使用4sapi专用变量，避免把官方OpenAI key误发给第三方
env_key = "FOURSAPI_OPENAI_API_KEY"
wire_api = "responses"  
query_params = {}
request_max_retries = 3
stream_max_retries = 8

[projects."$CODEX_PROJECT_PATH"]
trust_level = "trusted"

[tui.model_availability_nux]
"gpt-5.6-sol" = 2
EOF

# 密钥只在当前终端会话生效；不要追加到 .bashrc、.zshrc 或仓库
read -r -s -p "输入4sapi GPT key: " FOURSAPI_OPENAI_API_KEY; echo
export FOURSAPI_OPENAI_API_KEY

```

*   4sapi秘钥（key）
    
    *   ![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/a2QnV4jGBx55DO4X/img/7d09610d-21b9-471f-99a1-a816520e391c.png)
        

### 其他

*   有些操作可以在openclaw里面和模型对话执行，参考示例：
    

```json
0. 我有一个github仓库git@github.com:user_name/workspace.git，帮我先备份本地同名冲突文件，再把workspace关联过去；只允许拉取最新数据，不要提交或推送。如果本地main分支已存在，仅用git branch --set-upstream-to=origin/main main设置跟踪关系

1. 帮我检查openclaw安装的所有skills和plugins，分析他们的安装是否正确以及是否有依赖异常，最终给出分析结果和建议，但是不要自己执行

```
