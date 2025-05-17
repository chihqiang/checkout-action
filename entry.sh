#!/bin/bash
set -euo pipefail  # 出现错误立即退出，未定义变量报错，管道失败时返回失败状态

# === 日志函数 ===
color_echo() {
  local color_code=$1; shift                   # 读取第一个参数作为颜色代码，剩余参数作为消息内容
  echo -e "\033[${color_code}m[$(date +'%H:%M:%S')] $@\033[0m"  # 打印带颜色的时间戳和消息
}
info()    { color_echo "1;34" "ℹ️  $@"; }       # 蓝色信息提示
success() { color_echo "1;32" "✅ $@"; }       # 绿色成功提示
warning() { color_echo "1;33" "⚠️  $@"; }       # 黄色警告提示
error()   { color_echo "1;31" "❌ $@"; }       # 红色错误提示
step()    { color_echo "1;36" "🚀 $@"; }       # 青色步骤提示
divider() { echo -e "\033[1;30m--------------------------------------------------\033[0m"; }  # 灰色分割线

# 打印多行错误信息，方便颜色显示
print_error_details() {
  local msg="$1"                               # 接收多行错误信息字符串
  while IFS= read -r line; do                  # 逐行读取字符串
    error "$line"                              # 每行用红色错误格式打印
  done <<< "$msg"
}

# === 环境变量校验 ===
if [[ -z "${REPO:-}" ]]; then                    # 判断 REPO 是否为空或未定义
  error "REPO is not set"                        # 提示错误信息
  exit 1                                         # 退出脚本
fi

BRANCH="${BRANCH:-main}"                         # 如果 BRANCH 未设置，默认使用 main 分支
DEST="${DEST:-repo}"                             # 如果 DEST 未设置，默认目标目录为 repo

info "🚀 Git Clone Action Started"               # 打印启动信息
info "🔗 Repository : $REPO"                      # 打印仓库地址
info "📁 Target Dir : $DEST"                      # 打印目标目录
info "🌿 Branch     : $BRANCH"                    # 打印分支名称

if [[ -e "$DEST" ]]; then                         # 判断目标目录是否存在
  error "Directory '$DEST' already exists. Please remove or choose another directory."  # 报错提示
  exit 1                                          # 退出脚本
fi

# 处理 git clone 出错的错误信息，打印提示并退出
handle_git_clone_error() {
  local error_msg="$1"                            # 传入错误信息
  if echo "$error_msg" | grep -qi "permission denied"; then
    error "SSH authentication failed"            # SSH 认证失败错误提示
  elif echo "$error_msg" | grep -qi "repository not found\|not found"; then
    error "Repository or branch not found"       # 仓库或分支未找到错误提示
  elif echo "$error_msg" | grep -qi "authentication\|403\|access denied"; then
    error "Authentication failed (invalid token?)"  # 认证失败提示，可能 token 无效
  else
    error "Unknown git error"                     # 其他未知错误提示
  fi
  print_error_details "$error_msg"                # 打印详细错误内容
  exit 1                                          # 退出脚本
}

# HTTPS 克隆函数
clone_https() {
  info "🌐 Cloning via HTTPS..."                    # 打印使用 HTTPS 克隆信息

  local auth_repo="$REPO"                          # 默认使用原始 REPO 地址
  if [[ -n "${TOKEN:-}" ]]; then                   # 如果存在 TOKEN
    info "🔐 Using HTTPS token for authentication"  # 打印使用 Token 认证
    local domain=$(echo "$REPO" | awk -F/ '{print $3}')   # 解析出域名部分
    local path=$(echo "$REPO" | cut -d/ -f4-)             # 解析出路径部分
    auth_repo="https://oauth2:${TOKEN}@${domain}/${path}" # 构造带 Token 的认证 URL
  else
    info "🔍 Using public access (no token)"             # 无 Token 使用公开访问
  fi

  ERROR_MSG=$(git clone --quiet --branch "$BRANCH" --single-branch --depth=1 "$auth_repo" "$DEST" 2>&1) || \
    handle_git_clone_error "$ERROR_MSG"                    # 尝试克隆，失败则调用错误处理

  success "✅ HTTPS clone successful"                       # 成功提示
}

# SSH 克隆函数
clone_ssh() {
  info "🔐 Detected SSH repo"                                # 打印检测到 SSH 协议仓库

  if [[ -z "${SSH_KEY:-}" ]]; then                           # 判断是否有 SSH_KEY
    error "SSH_KEY not provided"                             # 无 SSH_KEY 报错
    exit 1
  fi

  mkdir -p ~/.ssh                                            # 创建 ~/.ssh 目录
  chmod 700 ~/.ssh                                           # 设置权限为 700
  echo "$SSH_KEY" > ~/.ssh/id_ed25519                        # 将私钥写入文件
  chmod 600 ~/.ssh/id_ed25519                                # 设置私钥权限为 600

  SSH_HOST=$(echo "$REPO" | awk -F'[@:]' '{print $2}')      # 解析 SSH 主机地址
  ssh-keyscan -H "$SSH_HOST" >> ~/.ssh/known_hosts 2>/dev/null  # 添加主机公钥到 known_hosts，避免交互提示

  ERROR_MSG=$(git clone --quiet --branch "$BRANCH" --single-branch --depth=1 "$REPO" "$DEST" 2>&1) || \
    handle_git_clone_error "$ERROR_MSG"                      # 执行克隆失败则处理错误

  success "✅ SSH clone successful"                          # 成功提示
}

# 根据 REPO 协议选择克隆方式
if [[ "$REPO" == http://* || "$REPO" == https://* ]]; then
  clone_https                                               # 如果是 HTTP 或 HTTPS，则调用 HTTPS 克隆
elif [[ "$REPO" == git@*:* ]]; then
  clone_ssh                                                # 如果是 SSH 协议，则调用 SSH 克隆
else
  error "Unsupported repo URL format: $REPO"              # 不支持的仓库格式报错
  exit 1
fi

# 进入目标目录打印最新提交的 commit id
(
  cd "$DEST"
  COMMIT_ID=$(git rev-parse HEAD)                          # 获取当前 HEAD 的 commit ID
  info "🆔 Latest commit ID: $COMMIT_ID"                   # 打印 commit ID 信息
)
