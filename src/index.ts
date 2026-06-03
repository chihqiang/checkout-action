import * as core from '@actions/core';
import { Config } from './config';
import { CheckoutService } from './checkout';
import { info, error, success } from './log';

function main(): void {
  try {
    const config = new Config();
    const checkout = new CheckoutService();

    info(`Repository: ${config.repository}`);
    info(`Ref: ${config.ref || '(default branch)'}`);
    info(`Path: ${config.path || '(workspace root)'}`);

    if (config.token) info('Authentication: token');
    if (config.sshKey) info('Authentication: SSH key');

    checkout.run(config);

    success('Checkout completed successfully');
  } catch (err) {
    const message = (err as Error)?.message ?? err;
    error(message as string);
    core.setFailed(message as string);
  }
}

main();
