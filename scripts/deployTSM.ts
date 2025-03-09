import { toNano } from '@ton/core';
import { TSM } from '../wrappers/TSM';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const tSM = provider.open(await TSM.fromInit());

    await tSM.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(tSM.address);

    // run methods on `tSM`
}
