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

info "Checking git version..."
if ! git_version=$(git --version 2>/dev/null); then
  error "Git is not installed or not found in PATH. Please install Git to continue."
  exit 1
fi
info "🐙 $git_version"
info "🚀 Git Clone Action Started"         # 打印启动信息
info "🔗 Repository : ${REPO:+******}"     # 打印仓库地址
info "📁 Target Dir : $DEST"               # 打印目标目录
info "🌿 Branch     : $BRANCH"                    # 打印分支名称

# 🛡️ 检查目标目录是否安全可用
if [[ "$DEST" == "." ]]; then
  # 如果目标目录是当前目录，判断是否为空（没有文件或子目录）
  if [[ -n "$(ls -A . 2>/dev/null)" ]]; then
    error "Current directory is not empty. Please run in an empty directory or set DEST to another path."
    exit 1
  fi
else
  # 如果目标目录不是当前目录，判断该目录是否已存在
  if [[ -e "$DEST" ]]; then
    error "Directory '$DEST' already exists. Please remove it or choose another directory."
    exit 1
  fi
fi

# 确保必要的环境变量都已设置，否则报错退出
if [[ -z "${REPO:-}" || -z "${BRANCH:-}" || -z "${DEST:-}" ]]; then
  error "REPO, BRANCH, or DEST is not set"
  return 1
fi

# HTTPS 克隆函数
clone_https() {
  info "🌐 Cloning via HTTPS..."  # 提示开始使用 HTTPS 克隆
  # 解析出域名和路径部分，用于后续构建认证 URL
  local domain path auth_repo
  domain=$(echo "$REPO" | awk -F/ '{print $3}')      # 获取域名部分，如 github.com
  path=$(echo "$REPO" | cut -d/ -f4-)                # 获取仓库路径部分，如 user/repo
  auth_repo="$REPO"                                  # 默认仓库地址为原始地址

  # 根据不同的认证方式处理 auth_repo
  if [[ -n "${TOKEN:-}" ]]; then
    info "🔐 Using HTTPS token for authentication"   # 使用 OAuth2 Token 认证
    auth_repo="https://oauth2:${TOKEN}@${domain}/${path}"  # 构建带 Token 的仓库地址
  elif [[ -n "${USERNAME:-}" && -n "${PASSWORD:-}" ]]; then
    info "🔐 Using HTTPS username/password for authentication"  # 使用用户名+密码认证
    auth_repo="https://${USERNAME}:${PASSWORD}@${domain}/${path}"  # 构建认证地址
  else
    info "🔍 Using public access (no token)"          # 无认证信息，走公开仓库克隆
  fi

  # 特殊处理：如果目标目录是当前目录（"."），则不直接 git clone，而是手动初始化
  if [[ "$DEST" == "." ]]; then
    info "📁 Cloning into current directory (manual init)..."  # 提示使用当前目录

    git config --global --add safe.directory . || {           # 将当前目录标记为安全
      error "Failed to mark current directory as safe"
      return 1
    }

    git init . || {                                            # 初始化 Git 仓库
      error "git init failed"
      return 1
    }

    git remote add origin "$auth_repo" || {                    # 添加远程 origin
      error "Failed to add remote origin"
      return 1
    }

    git config --local gc.auto 0 || {                          # 禁用自动垃圾回收
      error "Failed to disable Git auto GC"
      return 1
    }

    # 拉取远程分支，仅拉取指定分支、深度为1，加速拉取
    ERROR_MSG=$(git -c protocol.version=2 fetch --no-tags --prune --progress \
      --no-recurse-submodules --depth=1 origin "$BRANCH" 2>&1) || {
      print_error_details "$ERROR_MSG"                      # 如果失败调用错误处理函数
      return 1
    }

    # 检出远程分支为本地分支，命名为 $BRANCH，带错误处理
    git checkout -B "$BRANCH" "origin/$BRANCH" 2>&1 || {
      error "Failed to checkout branch '$BRANCH' from origin"
      return 1
    }

  else
    # 如果目标目录不是当前目录，则走标准 git clone 逻辑
    ERROR_MSG=$(git clone --quiet --branch "$BRANCH" --single-branch \
      --depth=1 "$auth_repo" "$DEST" 2>&1) || {
      print_error_details "$ERROR_MSG"                      # 克隆失败则处理错误
      return 1
    }
  fi

  success "✅ HTTPS clone successful"  # 克隆成功提示
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
    print_error_details "$ERROR_MSG"                      # 执行克隆失败则处理错误

  success "SSH clone successful"                          # 成功提示
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

  if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "CHECKOUT_ACTION_COMMIT_ID=$COMMIT_ID" >> "$GITHUB_ENV"
    echo "CHECKOUT_ACTION_PATH=$(pwd)" >> "$GITHUB_ENV"
    echo "CHECKOUT_ACTION_BRANCH=$BRANCH" >> "$GITHUB_ENV"
    echo "CHECKOUT_ACTION_REPO=$REPO" >> "$GITHUB_ENV"
  fi
)
