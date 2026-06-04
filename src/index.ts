import * as core from '@actions/core';
import { Config } from './config';
import { CheckoutService } from './checkout';
import { info, error } from './log';

function main(): void {
  try {
    const config = new Config();
    const checkout = new CheckoutService();

    core.startGroup('Checkout info');
    info(`${config.repository} | ${config.ref || '(default)'} | ${config.path || 'workspace root'}`);
    if (config.token) info('auth: token');
    if (config.sshKey) info('auth: ssh-key');
    core.endGroup();

    checkout.run(config);
  } catch (err) {
    const message = (err as Error)?.message ?? err;
    error(message as string);
    core.setFailed(message as string);
  }
}

main();
