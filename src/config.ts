import * as core from '@actions/core';
import * as fs from 'fs';
import * as path from 'path';
import { spawnSync } from 'child_process';

export const DEFAULT_SERVER_URL = 'https://github.com';
export const OUTPUT_PATH = 'path';
export const OUTPUT_REF = 'ref';

function parseBool(value: string | boolean | undefined): boolean {
  if (typeof value === 'boolean') return value;
  if (!value) return false;
  return value.toLowerCase() === 'true' || value === '1';
}

export class Config {
  readonly repository: string;
  readonly ref: string;
  readonly token: string;
  readonly sshKey: string;
  readonly sshKnownHosts: string;
  readonly sshStrict: boolean;
  readonly sshUser: string;
  readonly persistCredentials: boolean;
  readonly path: string;
  readonly clean: boolean;
  readonly fetchDepth: number;
  readonly fetchTags: boolean;
  readonly showProgress: boolean;
  readonly setSafeDirectory: boolean;
  readonly workspace: string;

  constructor() {
    this.repository = core.getInput('repository') || process.env.GITHUB_REPOSITORY || '';
    this.ref = core.getInput('ref') || process.env.GITHUB_REF_NAME || process.env.GITHUB_REF || '';
    this.token = core.getInput('token') || process.env.GITHUB_TOKEN || '';
    this.sshKey = core.getInput('ssh-key') || '';
    this.sshKnownHosts = core.getInput('ssh-known-hosts') || '';
    this.sshStrict = parseBool(core.getInput('ssh-strict'));
    this.sshUser = core.getInput('ssh-user') || 'git';
    this.persistCredentials = parseBool(core.getInput('persist-credentials'));
    this.path = core.getInput('path') || '';
    this.clean = parseBool(core.getInput('clean'));
    this.fetchDepth = parseInt(core.getInput('fetch-depth') || '1', 10);
    this.fetchTags = parseBool(core.getInput('fetch-tags'));
    this.showProgress = parseBool(core.getInput('show-progress'));
    this.setSafeDirectory = parseBool(core.getInput('set-safe-directory'));
    this.workspace = process.env.GITHUB_WORKSPACE || process.cwd();
  }

  getCloneUrl(): string {
    if (this.repository.includes('://') || this.repository.includes('@')) {
      return this.repository;
    }
    const serverUrl = (process.env.GITHUB_SERVER_URL || DEFAULT_SERVER_URL).replace(/\/+$/, '');
    return `${serverUrl}/${this.repository}.git`;
  }

  setupSshKey(): string | null {
    if (!this.sshKey) return null;

    const home = process.env.HOME || '/root';
    const sshDir = path.join(home, '.ssh');
    fs.mkdirSync(sshDir, { recursive: true });

    const keyPath = path.join(sshDir, 'action_rsa');
    fs.writeFileSync(keyPath, this.sshKey, { mode: 0o600 });

    const knownHostsPath = path.join(sshDir, 'known_hosts');

    if (this.sshKnownHosts) {
      fs.appendFileSync(knownHostsPath, this.sshKnownHosts + '\n');
    }

    const host = this.sshHost();
    try {
      const hosts = spawnSync('ssh-keyscan', [host], { stdio: ['ignore', 'pipe', 'pipe'], timeout: 10000 });
      if (hosts.status === 0 && hosts.stdout) {
        fs.appendFileSync(knownHostsPath, hosts.stdout.toString());
      }
    } catch {
      core.warning(`Failed to fetch ${host} SSH host key`);
    }

    let sshCommand = `ssh -i ${keyPath}`;
    if (this.sshStrict) {
      sshCommand += ' -o StrictHostKeyChecking=yes -o CheckHostIP=no';
    } else {
      sshCommand += ' -o StrictHostKeyChecking=no';
    }
    process.env.GIT_SSH_COMMAND = sshCommand;

    core.info(`SSH key configured at ${keyPath}`);
    return keyPath;
  }

  private sshHost(): string {
    const url = this.getCloneUrl();
    if (url.includes('://')) {
      return new URL(url).hostname;
    }
    const atIdx = url.lastIndexOf('@');
    if (atIdx !== -1) {
      const afterAt = url.slice(atIdx + 1);
      return afterAt.split(':')[0];
    }
    return 'github.com';
  }

  cleanupSshKey(keyPath: string): void {
    try {
      fs.unlinkSync(keyPath);
    } catch {
      // ignore cleanup errors
    }
  }

  isHttpUrl(url: string): boolean {
    return url.startsWith('https://') || url.startsWith('http://');
  }

  getAuthUser(repoUrl: string): string {
    if (this.isHttpUrl(repoUrl) && this.sshUser !== 'git') {
      return this.sshUser;
    }
    return 'x-access-token';
  }
}
