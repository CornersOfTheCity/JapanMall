import { toNano } from '@ton/core';
import { Mall } from '../wrappers/Mall';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const mall = provider.open(await Mall.fromInit());

    await mall.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(mall.address);

    // run methods on `mall`
}
