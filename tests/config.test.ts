import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Config } from '../src/config';

vi.mock('@actions/core', () => ({
  getInput: vi.fn(),
  getBooleanInput: vi.fn(),
  setFailed: vi.fn(),
  info: vi.fn(),
  warning: vi.fn(),
  error: vi.fn(),
  setOutput: vi.fn(),
}));

import * as core from '@actions/core';

const mockGetInput = vi.mocked(core.getInput);

beforeEach(() => {
  vi.clearAllMocks();
  delete process.env.GITHUB_REPOSITORY;
  delete process.env.GITHUB_REF;
  delete process.env.GITHUB_REF_NAME;
  delete process.env.GITHUB_TOKEN;
  delete process.env.GITHUB_SERVER_URL;
});

describe('Config', () => {
  it('should read inputs with defaults', () => {
    mockGetInput.mockImplementation((name) => {
      const defaults: Record<string, string> = {
        repository: 'owner/repo',
        ref: '',
        token: 'ghp_token',
        'ssh-key': '',
        'ssh-known-hosts': '',
        'ssh-strict': 'true',
        'ssh-user': 'git',
        'persist-credentials': 'true',
        path: '',
        clean: 'true',
        'fetch-depth': '1',
        'fetch-tags': 'false',
        'show-progress': 'true',
        'set-safe-directory': 'true',
      };
      return defaults[name] ?? '';
    });

    const config = new Config();
    expect(config.repository).toBe('owner/repo');
    expect(config.ref).toBe('');
    expect(config.token).toBe('ghp_token');
    expect(config.sshKey).toBe('');
    expect(config.sshStrict).toBe(true);
    expect(config.sshUser).toBe('git');
    expect(config.persistCredentials).toBe(true);
    expect(config.path).toBe('');
    expect(config.clean).toBe(true);
    expect(config.fetchDepth).toBe(1);
    expect(config.fetchTags).toBe(false);
    expect(config.showProgress).toBe(true);
    expect(config.setSafeDirectory).toBe(true);
    expect(typeof config.workspace).toBe('string');
  });

  it('should parse boolean strings', () => {
    mockGetInput.mockImplementation((name) => {
      const map: Record<string, string> = {
        repository: 'a/b',
        'ssh-strict': 'false',
        'persist-credentials': 'false',
        clean: 'false',
        'fetch-tags': 'true',
        'show-progress': 'false',
        'set-safe-directory': 'false',
      };
      return map[name] ?? '';
    });

    const config = new Config();
    expect(config.sshStrict).toBe(false);
    expect(config.persistCredentials).toBe(false);
    expect(config.clean).toBe(false);
    expect(config.fetchTags).toBe(true);
    expect(config.showProgress).toBe(false);
    expect(config.setSafeDirectory).toBe(false);
  });

  it('should fallback to environment variables when inputs are empty', () => {
    mockGetInput.mockReturnValue('');
    process.env.GITHUB_REPOSITORY = 'env-owner/env-repo';
    process.env.GITHUB_REF_NAME = 'env-branch';
    process.env.GITHUB_TOKEN = 'env-token';
    process.env.GITHUB_SERVER_URL = 'https://env.example.com';

    const config = new Config();
    expect(config.repository).toBe('env-owner/env-repo');
    expect(config.ref).toBe('env-branch');
    expect(config.token).toBe('env-token');
  });

  it('should parse fetch-depth 0 as full history', () => {
    mockGetInput.mockImplementation((name) => {
      if (name === 'repository') return 'a/b';
      if (name === 'fetch-depth') return '0';
      return '';
    });

    const config = new Config();
    expect(config.fetchDepth).toBe(0);
  });
});
