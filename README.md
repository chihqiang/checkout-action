# checkout-action
Clone any Git repo (Gitee, GitHub, GitLab, etc.) via HTTPS or SSH
## ✨ Features

- ✅ Clone **public or private repositories**
- 🔐 Support for **HTTPS Token**, **Username/Password**, or **SSH Key**
- 🌿 Specify a target **branch**
- 📁 Custom destination directory
- 🧩 Composite action – works anywhere in your workflows

---

## 📥 Inputs

| Name       | Description                                        | Required | Default |
| ---------- | -------------------------------------------------- | -------- | ------- |
| `repo`     | Git repository URL (HTTPS or SSH)                  | ✅ Yes    | –       |
| `branch`   | Branch to clone                                    | ❌ No     | `main`  |
| `token`    | Token for HTTPS authentication (optional)          | ❌ No     | –       |
| `username` | Username for HTTPS basic authentication (optional) | ❌ No     | –       |
| `password` | Password for HTTPS basic authentication (optional) | ❌ No     | –       |
| `ssh_key`  | SSH private key for SSH clone (optional)           | ❌ No     | –       |
| `dest`     | Destination directory                              | ❌ No     | `repo`  |

## 🚀 Usage Examples

### 🔐 Clone via HTTPS

```yaml
- name: Clone public repo via HTTPS
  uses: chihqiang/checkout-action@main
  with:
    repo: https://github.com/owner/public-repo.git
    branch: main
```


### 🔐 Clone via HTTPS (with token)

```yaml
- name: Clone private repo via HTTPS
  uses: chihqiang/checkout-action@main
  with:
    repo: https://github.com/owner/private-repo.git
    token: ${{ secrets.GH_TOKEN }}
    branch: main
```

### 🔐 Clone via HTTPS (with username/password)

```yml
- name: Clone private repo via HTTPS with username/password
  uses: chihqiang/checkout-action@main
  with:
    repo: https://github.com/owner/private-repo.git
    username: ${{ secrets.GIT_USERNAME }}
    password: ${{ secrets.GIT_PASSWORD }}
    branch: main
```

### 🔐 Clone via SSH

~~~yml
- name: Clone via SSH
  uses: chihqiang/checkout-action@main
  with:
    repo: git@github.com:owner/private-repo.git
    ssh_key: ${{ secrets.SSH_PRIVATE_KEY }}
    branch: develop
~~~

## 🗂 Output

The repository will be cloned into the specified `dest` directory (`repo` by default).
 Additionally, the following environment variables will be set (if running in GitHub Actions):

| Name                        | Description            |
| --------------------------- | ---------------------- |
| `CHECKOUT_ACTION_REPO`      | The original repo URL  |
| `CHECKOUT_ACTION_BRANCH`    | The branch checked out |
| `CHECKOUT_ACTION_COMMIT_ID` | The latest commit ID   |
| `CHECKOUT_ACTION_PATH`      | Full path to clone dir |

## 🛠 Where to Get Access Tokens

| Platform   | Token Generation URL                                     |
| ---------- | -------------------------------------------------------- |
| **GitHub** | https://github.com/settings/tokens                       |
| **Gitee**  | https://gitee.com/personal_access_tokens                 |
| **GitLab** | https://gitlab.com/-/profile/personal_access_tokens      |
| **Gitea**  | `https://<your-gitea-domain>/user/settings/applications` |

> 🔐 Once generated, store your token in **GitHub Secrets** (e.g., `GH_TOKEN`, `GIT_USERNAME`, `GIT_PASSWORD`) for safe use in workflows.
