import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { toNano } from '@ton/core';
import { EmitLogs } from '../wrappers/EmitLogs';
import {Cell, Address, TonClient, beginCell, fromNano } from '@ton/ton';
import '@ton/test-utils';
import { loadStakeEvent } from '../build/EmitLogs/tact_EmitLogs';

describe('EmitLogs', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let emitLogs: SandboxContract<EmitLogs>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        emitLogs = blockchain.openContract(await EmitLogs.fromInit());

        deployer = await blockchain.treasury('deployer');

        const deployResult = await emitLogs.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: emitLogs.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and emitLogs are ready to use
    });

    it('Test: should stake successfully', async () => {
        const stakeResult = await emitLogs.send(deployer.getSender(), { value: toNano("0.05") }, "stake");
        expect(stakeResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: emitLogs.address,
            success: true,
        });
        console.log("stakeResult:", stakeResult.externals[0].body.asSlice());
        let loadEvent = loadStakeEvent(stakeResult.externals[0].body.asSlice());
        console.log("loadEvent amount:",loadEvent.amount);
        console.log("loadEvent staker:",loadEvent.staker.toString());
    })

    it("Test: Should decode successfully", async () => {
        let boc = "b5ee9c7201010101002b00005142bf1ee636acfc08014d391b7c94f9cb655abbb5ea483bd44215868035036c6bbbe00b27c830e9dfd7";
        const buffer = Buffer.from(boc, 'hex');
        const cell = Cell.fromBoc(buffer)[0];
        const slice = cell.beginParse();
        let loadEvent = loadStakeEvent(slice);
        console.log("decode amount:",loadEvent.amount);
        console.log("decode staker:",loadEvent.staker.toString());
    });



});
