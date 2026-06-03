import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';
import * as core from '@actions/core';
import { Config } from '../src/config';

vi.mock('@actions/core', () => ({
  getInput: vi.fn(),
  setFailed: vi.fn(),
  info: vi.fn(),
  warning: vi.fn(),
  error: vi.fn(),
  setOutput: vi.fn(),
}));

vi.mock('child_process', () => ({
  spawnSync: vi.fn(() => ({
    status: 0,
    stdout: Buffer.from(''),
    stderr: Buffer.from(''),
    pid: 0,
    output: [],
    signal: null,
    stdin: null,
  })),
}));

const mockGetInput = vi.mocked(core.getInput);

function createConfig(overrides: Record<string, string> = {}): Config {
  mockGetInput.mockImplementation((name: string) => {
    const defaults: Record<string, string> = {
      repository: 'owner/repo',
      'ssh-key': '',
      'ssh-strict': 'true',
      'ssh-known-hosts': '',
      'ssh-user': 'git',
      'persist-credentials': 'true',
      clean: 'true',
      'fetch-depth': '1',
      'fetch-tags': 'false',
      'show-progress': 'true',
      'set-safe-directory': 'true',
    };
    return overrides[name] ?? defaults[name] ?? '';
  });
  return new Config();
}

describe('Config', () => {
  describe('getCloneUrl', () => {
    beforeEach(() => {
      delete process.env.GITHUB_SERVER_URL;
    });

    it('should use full URL as-is', () => {
      const config = createConfig({ repository: 'https://github.com/owner/repo.git' });
      expect(config.getCloneUrl()).toBe('https://github.com/owner/repo.git');
    });

    it('should use SSH URL as-is', () => {
      const config = createConfig({ repository: 'git@github.com:owner/repo.git' });
      expect(config.getCloneUrl()).toBe('git@github.com:owner/repo.git');
    });

    it('should construct URL from owner/repo', () => {
      process.env.GITHUB_SERVER_URL = 'https://github.com';
      const config = createConfig({ repository: 'owner/repo' });
      expect(config.getCloneUrl()).toBe('https://github.com/owner/repo.git');
    });

    it('should default to github.com when GITHUB_SERVER_URL is not set', () => {
      const config = createConfig({ repository: 'owner/repo' });
      expect(config.getCloneUrl()).toBe('https://github.com/owner/repo.git');
    });
  });

  describe('setupSshKey', () => {
    const originalHome = process.env.HOME;
    const testSshDir = path.join('/tmp', 'test-auth-ssh-' + Date.now());

    beforeEach(() => {
      process.env.HOME = testSshDir;
    });

    afterEach(() => {
      process.env.HOME = originalHome;
      try {
        fs.rmSync(testSshDir, { recursive: true, force: true });
      } catch {
        // ignore
      }
      delete process.env.GIT_SSH_COMMAND;
    });

    it('should return null without sshKey', () => {
      const config = createConfig({ 'ssh-key': '' });
      expect(config.setupSshKey()).toBeNull();
    });

    it('should write SSH key and configure GIT_SSH_COMMAND', () => {
      const config = createConfig({
        'ssh-key': '-----BEGIN KEY-----\ntest\n-----END KEY-----',
        'ssh-strict': 'true',
      });
      const result = config.setupSshKey();
      expect(result).not.toBeNull();
      expect(fs.existsSync(result!)).toBe(true);
      expect(process.env.GIT_SSH_COMMAND).toContain('ssh -i');
      expect(process.env.GIT_SSH_COMMAND).toContain('StrictHostKeyChecking=yes');
    });

    it('should disable strict checking when sshStrict is false', () => {
      const config = createConfig({
        'ssh-key': 'key',
        'ssh-strict': 'false',
      });
      config.setupSshKey();
      expect(process.env.GIT_SSH_COMMAND).toContain('StrictHostKeyChecking=no');
    });
  });
});
