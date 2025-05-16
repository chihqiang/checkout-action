#!/bin/bash
set -euo pipefail  # 出现错误立即退出，未定义变量报错，管道失败时返回失败状态

echo "🚀 Git Clone Action Started"  # 打印脚本开始提示

# === 日志函数 ===
color_echo() {
  local color_code=$1; shift   # 获取第一个参数为颜色代码，shift后参数列表向左移动
  echo -e "\033[${color_code}m[$(date +'%H:%M:%S')] $@\033[0m"  # 带颜色打印时间和日志内容
}
info()    { color_echo "1;34" "ℹ️  $@"; }     # 信息蓝色日志
success() { color_echo "1;32" "✅ $@"; }     # 成功绿色日志
warning() { color_echo "1;33" "⚠️  $@"; }     # 警告黄色日志
error()   { color_echo "1;31" "❌ $@"; }     # 错误红色日志
step()    { color_echo "1;36" "🚀 $@"; }     # 过程青色日志
divider() { echo -e "\033[1;30m--------------------------------------------------\033[0m"; }  # 分隔线

# 打印多行错误信息函数，逐行用 error() 打印，方便颜色显示
print_error_details() {
  local msg="$1"                  # 接收错误字符串参数
  while IFS= read -r line; do    # 循环逐行读取字符串
    error "$line"                # 打印每一行错误信息
  done <<< "$msg"                # 从参数字符串中读取行
}

# === 环境变量校验 ===
if [[ -z "${REPO:-}" ]]; then    # 如果 REPO 变量未定义或为空
  error "REPO is not set"       # 打印错误提示
  exit 1                        # 退出脚本
fi

BRANCH="${BRANCH:-main}"         # 设置分支，默认为 main
DEST="${DEST:-repo}"             # 设置目标目录，默认为 repo

info "🔗 Repository : $REPO"    # 打印仓库地址
info "📁 Target Dir : $DEST"    # 打印目标目录
info "🌿 Branch     : $BRANCH"  # 打印分支名称

if [[ -e "$DEST" ]]; then       # 如果目标路径（文件或目录）已存在
  error "Directory '$DEST' already exists. Please remove or choose another directory."  # 报错并提示
  exit 1                        # 退出脚本，防止覆盖
fi

# === HTTPS Clone Logic ===
clone_https() {
  info "🌐 Detected HTTPS repo"     # 提示检测到 HTTPS 仓库
  info "🔍 Trying public clone..."  # 尝试公有克隆

  # 尝试无 TOKEN 公有克隆，失败不退出直接进入后续逻辑
  if git clone --branch "$BRANCH" --single-branch --depth=1 "$REPO" "$DEST" 2>&1; then
    success "Public clone successful"   # 公有克隆成功提示
    return                             # 返回退出函数
  fi

  if [[ -n "${TOKEN:-}" ]]; then        # 如果 TOKEN 变量非空
    info "🔐 Retrying with HTTPS token..."   # 使用 TOKEN 重试
    REPO_DOMAIN=$(echo "$REPO" | awk -F/ '{print $3}')  # 提取仓库域名
    REPO_PATH=$(echo "$REPO" | cut -d/ -f4-)            # 提取仓库路径
    AUTH_REPO="https://oauth2:${TOKEN}@${REPO_DOMAIN}/${REPO_PATH}"  # 拼接带 TOKEN 的 URL

    # 使用 TOKEN 克隆，捕获错误信息赋值给 ERROR_MSG
    ERROR_MSG=$(git clone --branch "$BRANCH" --single-branch --depth=1 "$AUTH_REPO" "$DEST" 2>&1) || {
      # 根据错误内容判断错误类型，打印对应提示
      if echo "$ERROR_MSG" | grep -qi "repository not found\|not found"; then
        error "Repository or branch not found"
      elif echo "$ERROR_MSG" | grep -qi "authentication\|403\|access denied"; then
        error "Authentication failed (invalid token?)"
      else
        error "Unknown git error"
      fi
      print_error_details "$ERROR_MSG"  # 打印详细错误信息
      exit 1                           # 退出脚本
    }

    success "Authenticated clone successful"  # TOKEN 克隆成功提示
  else
    error "Clone failed and no TOKEN provided"  # 无 TOKEN 并克隆失败报错
    exit 1
  fi
}

# === SSH Clone Logic ===
clone_ssh() {
  info "🔐 Detected SSH repo"    # 提示检测到 SSH 仓库

  if [[ -z "${SSH_KEY:-}" ]]; then   # 如果 SSH_KEY 未定义或为空
    error "SSH_KEY not provided"     # 报错提示
    exit 1
  fi

  mkdir -p ~/.ssh             # 创建 ~/.ssh 目录
  chmod 700 ~/.ssh            # 设置目录权限为 700
  echo "$SSH_KEY" > ~/.ssh/id_ed25519    # 写入私钥文件
  chmod 600 ~/.ssh/id_ed25519            # 设置私钥权限为 600

  SSH_HOST=$(echo "$REPO" | awk -F'[@:]' '{print $2}')  # 解析 SSH 域名或 IP
  ssh-keyscan -H "$SSH_HOST" >> ~/.ssh/known_hosts 2>/dev/null  # 自动添加主机到 known_hosts 避免交互

  # 使用 SSH 克隆，错误信息赋值给 ERROR_MSG
  ERROR_MSG=$(git clone --branch "$BRANCH" --single-branch --depth=1 "$REPO" "$DEST" 2>&1) || {
    # 判断错误类型，打印对应错误提示
    if echo "$ERROR_MSG" | grep -qi "permission denied"; then
      error "SSH authentication failed"
    elif echo "$ERROR_MSG" | grep -qi "repository not found\|not found"; then
      error "Repository or branch not found"
    else
      error "Unknown git error"
    fi
    print_error_details "$ERROR_MSG"  # 打印详细错误
    exit 1
  }

  success "SSH clone successful"   # SSH 克隆成功提示
}

# === Dispatch based on protocol ===
if [[ "$REPO" == http://* || "$REPO" == https://* ]]; then  # 判断是否 HTTPS 协议
  clone_https              # 调用 HTTPS 克隆函数
elif [[ "$REPO" == git@*:* ]]; then                       # 判断是否 SSH 协议
  clone_ssh               # 调用 SSH 克隆函数
else
  error "Unsupported repo URL format: $REPO"   # 不支持的仓库格式
  exit 1
fi
