#!/bin/bash
set -euo pipefail  # 遇到错误立即退出；使用未定义变量时报错；管道中任意命令失败则返回失败

# === 日志输出函数 ===
color_echo() {
  local color_code=$1; shift
  echo -e "\033[${color_code}m[$(date +'%H:%M:%S')] $@\033[0m"
}
info()    { color_echo "1;34" "ℹ️  $@"; }
success() { color_echo "1;32" "✅ $@"; }
warning() { color_echo "1;33" "⚠️  $@"; }
error()   { color_echo "1;31" "❌ $@"; }
step()    { color_echo "1;36" "🚀 $@"; }
divider() { echo -e "\033[1;30m--------------------------------------------------\033[0m"; }

# === 环境变量校验 ===
if [[ -z "${REPO:-}" ]]; then
  error "REPO is not set"
  exit 1
fi

BRANCH="${BRANCH:-main}"
DEST="${DEST:-repo}"

START_TIME=$(date +%s)

# 检查 Git 是否安装
if ! git_version=$(git --version 2>/dev/null); then
  error "Git is not installed or not found in PATH. Please install Git first."
  exit 1
fi
info "🐙 Git Version: $git_version"
info "🚀 Git Clone Action Started"
info "🔗 Repository : ${REPO:+******}"
info "📁 Target Dir : $DEST"
info "🌿 Branch     : $BRANCH"

# 检查目录
if [[ "$DEST" == "." ]]; then
  if [[ -n "$(ls -A . 2>/dev/null)" ]]; then
    error "Current directory is not empty. Please run in an empty directory or set DEST to another path."
    exit 1
  fi
else
  if [[ -e "$DEST" ]]; then
    error "Directory '$DEST' already exists. Please remove it or choose another directory."
    exit 1
  fi
fi

# === 使用 HTTPS 克隆仓库 ===
clone_https() {
  info "🌐 Cloning via HTTPS..."

  local domain path auth_repo
  domain=$(echo "$REPO" | awk -F/ '{print $3}')
  path=$(echo "$REPO" | cut -d/ -f4-)
  auth_repo="$REPO"

  if [[ -n "${TOKEN:-}" ]]; then
    info "🔐 Using HTTPS token"
    auth_repo="https://oauth2:${TOKEN}@${domain}/${path}"
  elif [[ -n "${USERNAME:-}" && -n "${PASSWORD:-}" ]]; then
    info "🔐 Using HTTPS username/password"
    auth_repo="https://${USERNAME}:${PASSWORD}@${domain}/${path}"
  else
    info "🔓 Using public access"
  fi

  if [[ "$DEST" == "." ]]; then
    info "📁 Cloning into current directory..."

    git config --global --add safe.directory . || {
      error "Failed to mark current directory as safe"
      exit 1
    }

    git init . || { error "git init failed"; exit 1; }

    git remote add origin "$auth_repo" || {
      error "Failed to add remote origin"
      exit 1
    }

    git config --local gc.auto 0 || {
      error "Failed to disable Git auto GC"
      exit 1
    }

    if ! ERROR_MSG=$(git -c protocol.version=2 fetch --no-tags --prune --progress \
        --no-recurse-submodules --depth=1 origin "$BRANCH" 2>&1); then
      error "❌ Git fetch failed:"
      echo "$ERROR_MSG" >&2
      exit 1
    fi

    git checkout -B "$BRANCH" "origin/$BRANCH" 2>/dev/null || {
      error "Failed to checkout branch '$BRANCH'"
      exit 1
    }

  else
    if ! ERROR_MSG=$(git clone --quiet --branch "$BRANCH" --single-branch --depth=1 "$auth_repo" "$DEST" 2>&1); then
      error "HTTP Git clone failed:"
      echo "$ERROR_MSG" >&2
      exit 1
    fi
  fi

  success "✅ HTTPS clone successful"
}


cleanup_ssh_key() {
  [[ -f ~/.ssh/id_ed25519 ]] && {
    shred -u ~/.ssh/id_ed25519
    info "🧹 SSH key cleaned up"
  }
}
# === 使用 SSH 克隆仓库 ===
clone_ssh() {
  info "🔐 Detected SSH repo"

  if [[ -z "${SSH_KEY:-}" ]]; then
    error "SSH_KEY not provided"
    exit 1
  fi

  trap cleanup_ssh_key EXIT 
  
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  echo "$SSH_KEY" > ~/.ssh/id_ed25519
  chmod 600 ~/.ssh/id_ed25519
  SSH_HOST=$(echo "$REPO" | awk -F'[@:]' '{print $2}')
  ssh-keyscan -H "$SSH_HOST" >> ~/.ssh/known_hosts 2>/dev/null

  if ! ERROR_MSG=$(git clone --quiet --branch "$BRANCH" --single-branch --depth=1 "$REPO" "$DEST" 2>&1); then
    error "SSH Git clone failed:"
    echo "$ERROR_MSG" >&2
    exit 1
  fi

  success "✅ SSH clone successful"
}

# === 判断使用哪种协议 ===
if [[ "$REPO" == http://* || "$REPO" == https://* ]]; then
  clone_https
elif [[ "$REPO" == git@*:* ]]; then
  clone_ssh
else
  error "Unsupported repo URL format: $REPO"
  exit 1
fi

# === 打印最新 commit 信息 ===
(
  cd "$DEST"
  COMMIT_ID=$(git rev-parse HEAD)
  info "🆔 Latest commit ID: $COMMIT_ID"

  if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "CHECKOUT_ACTION_COMMIT_ID=$COMMIT_ID" >> "$GITHUB_ENV"
    echo "CHECKOUT_ACTION_PATH=$(pwd)" >> "$GITHUB_ENV"
    echo "CHECKOUT_ACTION_BRANCH=$BRANCH" >> "$GITHUB_ENV"
    echo "CHECKOUT_ACTION_REPO=$REPO" >> "$GITHUB_ENV"
  fi
)

END_TIME=$(date +%s)
CLONE_DURATION=$((END_TIME - START_TIME))
info "⏱️ Clone duration: ${CLONE_DURATION}s"