import * as fs from 'fs';
import * as path from 'path';
import * as core from '@actions/core';
import { Config, OUTPUT_PATH, OUTPUT_REF } from './config';
import { GitClient } from './git';
import { info, success, step } from './log';

export class CheckoutService {
  private readonly git: GitClient;

  constructor() {
    this.git = new GitClient();
  }

  run(config: Config): void {
    const targetDir = config.path ? path.join(config.workspace, config.path) : config.workspace;
    const repoUrl = config.getCloneUrl();
    const ref = config.ref;
    const isFullHistory = config.fetchDepth === 0;

    step(`${repoUrl}`);
    if (ref) info(`ref: ${ref}`);

    const sshKeyPath = config.setupSshKey();

    try {
      fs.mkdirSync(config.workspace, { recursive: true });

      if (config.token && config.isHttpUrl(repoUrl)) {
        this.persistToken(repoUrl, config.token, config.getAuthUser(repoUrl));
      }

      this.checkoutRepository(config, repoUrl, targetDir, ref, isFullHistory);

      if (config.setSafeDirectory) {
        this.git.config('safe.directory', targetDir, { global: true });
      }

      const resolvedRef = ref || this.git.revParse('HEAD', { cwd: targetDir });
      core.setOutput(OUTPUT_PATH, targetDir);
      core.setOutput(OUTPUT_REF, resolvedRef);

      success(`checked out to ${targetDir}`);
    } finally {
      if (config.token && !config.persistCredentials && config.isHttpUrl(repoUrl)) {
        this.removePersistedToken(repoUrl);
      }
      if (sshKeyPath && !config.persistCredentials) {
        config.cleanupSshKey(sshKeyPath);
      }
    }
  }

  private persistToken(repoUrl: string, token: string, username: string): void {
    const b64 = Buffer.from(`${username}:${token}`).toString('base64');
    const configKey = `http.${this.authHost(repoUrl)}.extraheader`;
    this.git.run(['config', '--global', configKey, `AUTHORIZATION: basic ${b64}`]);
  }

  private removePersistedToken(repoUrl: string): void {
    const configKey = `http.${this.authHost(repoUrl)}.extraheader`;
    this.git.configUnset(configKey, { global: true });
  }

  private authHost(repoUrl: string): string {
    try {
      const u = new URL(repoUrl);
      return `${u.protocol}//${u.host}/`;
    } catch {
      return repoUrl;
    }
  }

  private checkoutRepository(
    config: Config,
    repoUrl: string,
    targetDir: string,
    ref: string,
    isFullHistory: boolean,
  ): void {
    const hasExistingRepo = fs.existsSync(path.join(targetDir, '.git'));

    if (hasExistingRepo && config.clean) {
      step('Cleaning repository');
      this.git.clean({ cwd: targetDir });
    }

    const progress = config.showProgress;

    if (hasExistingRepo) {
      step('Updating existing repository');
      this.git.setRemoteUrl(repoUrl, { cwd: targetDir });

      this.git.fetch('origin', {
        ref: ref || undefined,
        depth: isFullHistory ? undefined : config.fetchDepth,
        progress,
        cwd: targetDir,
      });

      if (ref) {
        this.git.checkout(ref, { progress, cwd: targetDir });
      }

      if (config.fetchTags) {
        this.git.fetch('origin', { tags: true, progress, cwd: targetDir });
      }
    } else {
      step('Cloning repository');
      this.git.clone(repoUrl, targetDir, {
        branch: ref || undefined,
        depth: isFullHistory ? undefined : config.fetchDepth,
        progress,
      });
    }
  }
}
