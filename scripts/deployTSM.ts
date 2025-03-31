import { toNano,Address, } from '@ton/core';
import { beginCell, contractAddress, TonClient4, WalletContractV4, internal, fromNano, WalletContractV5R1, WalletContractV3R2 } from "@ton/ton";
import { mnemonicToPrivateKey } from "ton-crypto";
import { NetworkProvider } from '@ton/blueprint';
import { TSM, Mint, buildOnchainMetadata, TokenTransfer } from '../wrappers/TSM';
import { WalletV4Contract } from 'ton-contracts';
// import { Address } from 'ton-core';

export async function run(provider: NetworkProvider) {
    const jettonParams = {
        name: "TSM",
        description: "This is description of Test tact jetton",
        symbol: "TSM",
        image: "https://play-lh.googleusercontent.com/ahJtMe0vfOlAu1XJVQ6rcaGrQBgtrEZQefHy7SXB7jpijKhu1Kkox90XDuH8RmcBOXNn",
    };
    let content = buildOnchainMetadata(jettonParams);
    let owner_mint = toNano(100_000);
    let max_supply = toNano(100_000_000);

    let mnemonics = (process.env.WALLET_MNEMONIC || "").toString(); // 🔴 Change to your own, by creating .env file!
    let keyPair = await mnemonicToPrivateKey(mnemonics.split(" "));
    let secretKey = keyPair.secretKey;
    let workchain = 0; //we are working in basechain.
    let deployer_wallet = WalletContractV5R1.create({ workchain, publicKey: keyPair.publicKey });
    // console.log("deployer_wallet_Address:",deployer_wallet.address);
    let ownerAddress = Address.parse('EQA9wsXXU-9oguvXqUTzw4CsFFjBanfLN5xtQvl3rz228MjO');
    const tSM = provider.open(await TSM.fromInit(ownerAddress, content, max_supply));

    await tSM.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Mint',
            amount: owner_mint,
            receiver: deployer_wallet.address
        }
    );

    await provider.waitForDeploy(tSM.address);

    // const counter = provider.open(
    //     TSM.createFromConfig(
    //         {
    //             id: Math.floor(Math.random() * 10000),
    //             counter: 0,
    //         },
    //         await compile('Counter')
    //     )
    // );

    // await counter.sendDeploy(provider.sender(), toNano('0.05'));

    // await provider.waitForDeploy(counter.address);

    // console.log('ID', await counter.getID());

    // run methods on `tSM`
}

// import * as fs from 'fs';
// import * as path from 'path';
// import { Address, contractAddress } from "ton";
// import { SampleTactContract } from "./output/sample_SampleTactContract";
// import { prepareTactDeployment } from "@tact-lang/deployer";

// // Parameters
// let testnet = true;                                 // Flag for testnet or mainnet
// let packageName = 'sample_SampleTactContract.pkg';  // Name of your package to deploy
// let outputPath = path.resolve(__dirname, 'output'); // Path to output directory
// let owner = Address.parse('<put_address_here>');    // Our sample contract has an owner
// let init = await SampleTactContract.init(owner);    // Create initial data for our contract

// // Calculations
// let address = contractAddress(0, init);     // Calculate contract address. MUST match with the address in the verifier
// let data = init.data.toBoc();               // Create init data
// let pkg = fs.readFileSync(                  // Read package file
//     path.resolve(outputPath, packageName)
// );

// // Prepare deploy
// let link = await prepareTactDeployment({ pkg, data, testnet });

// // Present a deployment link and contract address
// console.log('Address: ' + address.toString({ testOnly: testnet }));
// console.log('Deploy link: ' + link);
