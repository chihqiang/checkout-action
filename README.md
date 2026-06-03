# checkout-action

通过 HTTPS 或 SSH 克隆任意 Git 仓库（GitHub、GitLab、Gitee、Gitea 等）。

可作为 `actions/checkout` 的替代方案，支持跨平台仓库克隆。

## 功能特性

- 克隆 **任意 Git 仓库**，不限于 GitHub
- 支持 **HTTPS Token**、**用户名 + Token**、**SSH Key** 认证
- **浅克隆**（`fetch-depth`）或全量历史
- 自动从 `GITHUB_SERVER_URL` 识别服务器地址，支持 GitHub
  Enterprise、GitLab 自托管等
- **SSH 严格模式**，自动 keyscan 目标主机，支持 known hosts

## 输入参数

| 参数 | 说明 | 默认值 |
| --- | --- | --- |
| `repository` | 仓库名（格式：`owner/repo`） | `${{ github.repository }}` |
| `ref` | 分支、标签或 SHA | （默认分支） |
| `token` | 个人访问令牌 | `${{ github.token }}` |
| `ssh-key` | SSH 私钥 | - |
| `ssh-known-hosts` | 已知主机公钥（写入 `~/.ssh/known_hosts`） | - |
| `ssh-strict` | 是否开启 SSH 严格主机检查 | `true` |
| `ssh-user` | SSH 用户；指定完整 HTTPS URL 时作为 HTTP Basic Auth 用户名 | `git` |
| `persist-credentials` | 是否将凭证持久化到 git config | `true` |
| `path` | `$GITHUB_WORKSPACE` 下的子目录 | （工作区根目录） |
| `clean` | 是否在 fetch 前执行 `git clean -ffdx && git reset --hard HEAD` | `true` |
| `fetch-depth` | 获取的 commit 数量（`0`= 全量历史） | `1` |
| `fetch-tags` | 是否同时获取 tags | `false` |
| `show-progress` | 是否显示进度输出 | `true` |
| `set-safe-directory` | 是否将路径添加到 git 的 `safe.directory` | `true` |

## 使用示例

### 基础用法（GitHub）

```yaml
- uses: chihqiang/checkout-action@main
```

### 带 Token 克隆私有仓库

```yaml
- uses: chihqiang/checkout-action@main
  with:
    repository: my-org/private-repo
    token: ${{ secrets.GH_TOKEN }}
    ref: main
```

### 全量历史 + Tags

```yaml
- uses: chihqiang/checkout-action@main
  with:
    fetch-depth: 0
    fetch-tags: true
```

### 从 GitLab 克隆

```yaml
- uses: chihqiang/checkout-action@main
  with:
    repository: https://gitlab.com/my-group/my-project.git
    token: ${{ secrets.GITLAB_TOKEN }}
```

### 通过 SSH 克隆

```yaml
- uses: chihqiang/checkout-action@main
  with:
    repository: owner/private-repo
    ssh-key: ${{ secrets.SSH_PRIVATE_KEY }}
```

### 从 Gitee 克隆

```yaml
- uses: chihqiang/checkout-action@main
  with:
    repository: https://gitee.com/my-group/my-project.git
    ssh-user: your-username
    token: ${{ secrets.GITEE_TOKEN }}
```

### 通过 SSH 协议克隆

```yaml
- uses: chihqiang/checkout-action@main
  with:
    repository: ssh://git@git.example.com/project.git
    ssh-key: ${{ secrets.SSH_PRIVATE_KEY }}
```

### 指定子目录

```yaml
- uses: chihqiang/checkout-action@main
  with:
    path: subdir
```

## 输出

| 输出名 | 说明 |
| --- | --- |
| `path` | 仓库的绝对路径 |
| `ref` | 已检出的 ref |

## 认证方式

| 方式 | 对应参数 | 适用场景 |
| --- | --- | --- |
| Token | `token` | `owner/repo` 简写（GitHub 自动识别） |
| 用户名 + Token | `ssh-user` + `token` | 完整 HTTPS URL（如 Gitee、GitLab） |
| SSH Key | `ssh-key`、`ssh-known-hosts` | `git@...` 或 `ssh://...` URL |

启用 `persist-credentials`（默认开启）时，Token 会被写入 git 的
`http.extraheader` 配置，使得后续 git 命令可以复用该凭证。

## 获取 Token

| 平台 | Token 地址 |
| --- | --- |
| GitHub | <https://github.com/settings/tokens> |
| GitLab | <https://gitlab.com/-/profile/personal_access_tokens> |
| Gitee | <https://gitee.com/personal_access_tokens> |
| Gitea | `https://<your-domain>/user/settings/applications` |

请将 Token 保存为
[GitHub Secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
后在 workflow 中使用。
