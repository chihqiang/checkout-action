import * as core from '@actions/core';

export const info = core.info;
export const warning = core.warning;
export const error = core.error;
export const success = (message: string) => core.info(`✅ ${message}`);
export const step = (message: string) => core.info(`🚀 ${message}`);
