import { spawnSync } from 'child_process';
import { warning } from './log';

export class GitClient {
  private static readonly TIMEOUT = 300_000;

  run(args: string[], options?: { cwd?: string }): string {
    const result = spawnSync('git', args, {
      cwd: options?.cwd,
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: GitClient.TIMEOUT,
      env: { ...process.env, GIT_TERMINAL_PROMPT: '0' },
    });

    if (result.error) {
      throw new Error(`git ${args.join(' ')} error: ${result.error.message}`);
    }

    const stderr = result.stderr?.toString() || '';
    const stdout = result.stdout?.toString() || '';

    if (result.status !== 0 && result.status !== null) {
      throw new Error(`git ${args.join(' ')} failed: ${stderr || stdout}`);
    }

    return stdout;
  }

  config(name: string, value: string, options?: { cwd?: string; global?: boolean }): void {
    const args = ['config'];
    if (options?.global) args.push('--global');
    args.push('--add', name, value);
    this.run(args, { cwd: options?.cwd });
  }

  configUnset(name: string, options?: { cwd?: string; global?: boolean }): void {
    try {
      const args = ['config', '--unset-all', name];
      if (options?.global) args.splice(1, 0, '--global');
      this.run(args, { cwd: options?.cwd });
    } catch {
      warning(`Failed to unset git config: ${name}`);
    }
  }

  clone(repoUrl: string, targetDir: string, options?: {
    branch?: string;
    depth?: number;
    progress?: boolean;
  }): void {
    const args = ['clone'];

    if (options?.depth && options.depth > 0) {
      args.push('--depth', String(options.depth));
    }

    if (options?.branch) {
      args.push('--branch', options.branch);
    }

    if (options?.progress) {
      args.push('--progress');
    }

    args.push(repoUrl, targetDir);
    this.run(args);
  }

  fetch(remote: string, options?: {
    ref?: string;
    depth?: number;
    tags?: boolean;
    progress?: boolean;
    cwd?: string;
  }): void {
    const args = ['fetch'];

    if (options?.tags) {
      args.push('--tags');
    } else {
      args.push('--no-tags');
    }

    if (options?.depth && options.depth > 0) {
      args.push('--depth', String(options.depth));
    }

    if (options?.progress) {
      args.push('--progress');
    }

    args.push(remote);

    if (options?.ref) {
      args.push(options.ref);
    }

    this.run(args, { cwd: options?.cwd });
  }

  checkout(ref: string, options?: { progress?: boolean; cwd?: string }): void {
    const args = ['checkout'];
    if (options?.progress) args.push('--progress');
    args.push(ref);
    this.run(args, { cwd: options?.cwd });
  }

  clean(options?: { cwd?: string }): void {
    this.run(['clean', '-ffdx'], { cwd: options?.cwd });
    this.run(['reset', '--hard', 'HEAD'], { cwd: options?.cwd });
  }

  setRemoteUrl(url: string, options?: { cwd?: string }): void {
    this.run(['remote', 'set-url', 'origin', url], { cwd: options?.cwd });
  }

  revParse(ref: string, options?: { cwd?: string }): string {
    return this.run(['rev-parse', '--abbrev-ref', ref], { cwd: options?.cwd }).trim();
  }
}
