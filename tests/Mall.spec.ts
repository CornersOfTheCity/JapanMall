import { compile } from '@ton/blueprint';
import { Blockchain, SandboxContract, TreasuryContract, internal, BlockchainSnapshot } from '@ton/sandbox';
import { Cell, toNano, beginCell, Address } from '@ton/core';
import { JettonDefaultWallet } from '../wrappers/Jetton';
import { TSM, Mint, buildOnchainMetadata, TokenTransfer } from '../wrappers/TSM';
import { Mall, Create, OwnerClaim, UserClaim, LotteryDraw, SetWalletAddress, WinnerClaim, WinnerAbondon } from '../wrappers/Mall';
import '@ton/test-utils';


describe('Mall', () => {
    const jettonParams = {
        name: "TSM",
        description: "This is description of Test tact jetton",
        symbol: "TSM",
        image: "https://play-lh.googleusercontent.com/ahJtMe0vfOlAu1XJVQ6rcaGrQBgtrEZQefHy7SXB7jpijKhu1Kkox90XDuH8RmcBOXNn",
    };

    let oneToken = toNano(1)
    let twoToken = toNano(2)
    let tenToken = toNano(10)
    let twentyToken = toNano(20)
    let oneHundredToken = toNano(100)
    let content = buildOnchainMetadata(jettonParams);
    let max_supply = toNano(100_000_000);

    let blockchain: Blockchain;
    let tsm: SandboxContract<TSM>;
    let mall: SandboxContract<Mall>;
    let mallJettonWallet: SandboxContract<JettonDefaultWallet>;
    let ownerJettonWallet: SandboxContract<JettonDefaultWallet>;
    let playerOneJettonWallet: SandboxContract<JettonDefaultWallet>;
    let playerTwoJettonWallet: SandboxContract<JettonDefaultWallet>;
    let playerThreeJettonWallet: SandboxContract<JettonDefaultWallet>;
    let deployer: SandboxContract<TreasuryContract>;
    let playerOne: SandboxContract<TreasuryContract>;
    let playerTwo: SandboxContract<TreasuryContract>;
    let playerThree: SandboxContract<TreasuryContract>;

    // beforeEach(async () => {
    beforeAll(async () => {
        blockchain = await Blockchain.create();

        deployer = await blockchain.treasury("deployer");
        playerOne = await blockchain.treasury("playerOne");
        playerTwo = await blockchain.treasury("playerTwo");
        playerThree = await blockchain.treasury("playerThree");

        tsm = blockchain.openContract(await TSM.fromInit(deployer.address, content, max_supply));

        const tsmDeployResult = await tsm.send(
            deployer.getSender(),
            {
                value: toNano("10"),
            },
            "Mint: 100"
        );

        //set block timestamp
        blockchain.now = tsmDeployResult.transactions[1].now;

        expect(tsmDeployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: tsm.address,
            deploy: true,
            success: true,
        });

        const ownerWallet = await tsm.getGetWalletAddress(deployer.address);
        ownerJettonWallet = blockchain.openContract(await JettonDefaultWallet.fromAddress(ownerWallet));

        const playerOneWallet = await tsm.getGetWalletAddress(playerOne.address);
        playerOneJettonWallet = blockchain.openContract(await JettonDefaultWallet.fromAddress(playerOneWallet));

        const playerTwoWallet = await tsm.getGetWalletAddress(playerTwo.address);
        playerTwoJettonWallet = blockchain.openContract(await JettonDefaultWallet.fromAddress(playerTwoWallet));

        const playerThreeWallet = await tsm.getGetWalletAddress(playerThree.address);
        playerThreeJettonWallet = blockchain.openContract(await JettonDefaultWallet.fromAddress(playerThreeWallet));

        let walletCode = (await tsm.getGetJettonData()).wallet_code;
        mall = blockchain.openContract(await Mall.fromInit(deployer.address, tsm.address));
        const mallDeployResult = await mall.send(deployer.getSender(), { value: toNano("1") }, { $$type: "Deploy", queryId: 0n });
        expect(mallDeployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: mall.address,
            deploy: true,
            success: true,
        });

        const mallWallet = await tsm.getGetWalletAddress(mall.address);
        mallJettonWallet = blockchain.openContract(await JettonDefaultWallet.fromAddress(mallWallet));

        //set mallWallet address
        const ChangeAddress: SetWalletAddress = {
            $$type: "SetWalletAddress",
            walletAddress: mallJettonWallet.address,
        };
        const changeResult = await mall.send(deployer.getSender(), { value: toNano("1") }, ChangeAddress);
        expect(changeResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: mall.address,
            success: true,
        });

    });

    it("Test: Should Mint successfully", async () => {
        const totalSupplyBefore = (await tsm.getGetJettonData()).total_supply;
        const mintAmount = oneHundredToken;
        const mintOne: Mint = {
            $$type: "Mint",
            amount: mintAmount,
            receiver: playerOne.address,
        };

        const playerOneMintResult = await tsm.send(deployer.getSender(), { value: toNano("10") }, mintOne);
        expect(playerOneMintResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: tsm.address,
            success: true,
        });

        const playerOneWalletData = await playerOneJettonWallet.getGetWalletData()
        var totalSupplyAfter = (await tsm.getGetJettonData()).total_supply;
        expect(totalSupplyBefore + mintAmount).toEqual(totalSupplyAfter);
        expect(playerOneWalletData.owner).toEqualAddress(playerOne.address);
        expect(playerOneWalletData.balance).toBeGreaterThanOrEqual(mintAmount);

        const mintTwo: Mint = {
            $$type: "Mint",
            amount: mintAmount,
            receiver: playerTwo.address,
        };

        const playerTwoMintResult = await tsm.send(deployer.getSender(), { value: toNano("10") }, mintTwo);
        expect(playerTwoMintResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: tsm.address,
            success: true,
        });

        const playerTwoWalletData = await playerTwoJettonWallet.getGetWalletData()
        expect(playerTwoWalletData.balance).toBeGreaterThanOrEqual(mintAmount);


        const mallMint: Mint = {
            $$type: "Mint",
            amount: twoToken,
            receiver: mall.address,
        };
        const mallMintResult = await tsm.send(deployer.getSender(), { value: toNano("1") }, mallMint);
        expect(mallMintResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: tsm.address,
            success: true,
        });

        var mallWalletData = await mallJettonWallet.getGetWalletData();
        expect(mallWalletData.balance).toBeGreaterThanOrEqual(twoToken);

    });

    it('Test: Should Create successfully', async () => {
        const Create: Create = {
            $$type: "Create",
            price: oneToken,
            type: BigInt(0),
            startTime: BigInt(blockchain.now ?? 0),
            endTime: BigInt((blockchain.now ?? 0) + 10000),
            amount: BigInt(100)
        };

        const ownerCreateResult = await mall.send(deployer.getSender(), { value: toNano("0.05") }, Create);
        expect(ownerCreateResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: mall.address,
            success: true,
        });

        //set block timestamp
        blockchain.now = ownerCreateResult.transactions[1].now + 10;
    });

    it('Test: Should Buy successfully', async () => {

        let msg: TokenTransfer = {
            $$type: "TokenTransfer",
            query_id: 0n,
            amount: tenToken,
            destination: mall.address,
            response_destination: mall.address,
            custom_payload: null,
            forward_ton_amount: toNano(0.1),
            forward_payload: beginCell().storeUint(1, 256).endCell().asSlice(),
        };

        const transferResult = await playerOneJettonWallet.send(playerOne.getSender(), { value: toNano("0.15") }, msg);
        expect(transferResult.transactions).toHaveTransaction({
            from: playerOneJettonWallet.address,
            to: mallJettonWallet.address,
            success: true,
        });

        var mallWallet = await mallJettonWallet.getGetWalletData();

        console.log("recoed mallBalance:", await mall.getBalance());

        console.log("mallWallet balance:", mallWallet.balance);

        blockchain.now = transferResult.transactions[1].now;
        // console.log(await mall.getHuntsMap(BigInt(1)));

    });

    it('Test: User Should Claim back successfully', async () => {

        blockchain.now = (blockchain.now ?? 0) + 10000;

        var playerOneWallet = await playerOneJettonWallet.getGetWalletData();
        var mallWallet = await mallJettonWallet.getGetWalletData();
        var beforePlayerOnebalance = await playerOneWallet.balance;
        var beforeMallbalance = await mallWallet.balance;
        console.log("before claimerBalance:", beforePlayerOnebalance);
        console.log("before mallBalance:", beforeMallbalance);

        let hunt = await mall.getHuntsMap(BigInt(1));

        console.log("hunt = 1:", hunt);

        const userClaim: UserClaim = {
            $$type: "UserClaim",
            huntId: BigInt(1)
        };

        const userClaimResult = await mall.send(playerOne.getSender(), { value: toNano("0.1") }, userClaim);
        expect(userClaimResult.transactions).toHaveTransaction({
            from: playerOne.address,
            to: mall.address,
            success: true,
        });

        var playerOneWallet = await playerOneJettonWallet.getGetWalletData();
        var mallWallet = await mallJettonWallet.getGetWalletData();
        var afterPlayerOnebalance = await playerOneWallet.balance;
        var afterMallbalance = await mallWallet.balance;

        console.log("after claimBalance:", afterPlayerOnebalance);
        console.log("after mallBalance:", afterMallbalance);

    })

    it('Test: Lottery should draw successfully', async () => {
        //Create
        const Create: Create = {
            $$type: "Create",
            price: oneToken,
            type: BigInt(0),
            startTime: BigInt(blockchain.now ?? 0),
            endTime: BigInt((blockchain.now ?? 0) + 10000),
            amount: BigInt(50)
        };

        const ownerCreateResult = await mall.send(deployer.getSender(), { value: toNano("0.05") }, Create);
        expect(ownerCreateResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: mall.address,
            success: true,
        });

        //owner buy
        let ownerBuyMsg: TokenTransfer = {
            $$type: "TokenTransfer",
            query_id: 0n,
            amount: twentyToken,
            destination: mall.address,
            response_destination: mall.address,
            custom_payload: null,
            forward_ton_amount: toNano(0.1),
            forward_payload: beginCell().storeUint(2, 256).endCell().asSlice(),
        };

        const ownerBuyResult = await ownerJettonWallet.send(deployer.getSender(), { value: toNano("0.15") }, ownerBuyMsg);
        expect(ownerBuyResult.transactions).toHaveTransaction({
            from: ownerJettonWallet.address,
            to: mallJettonWallet.address,
            success: true,
        });

        blockchain.now = ownerBuyResult.transactions[1].now + 1;


        let buyerOneMsg: TokenTransfer = {
            $$type: "TokenTransfer",
            query_id: 0n,
            amount: twentyToken,
            destination: mall.address,
            response_destination: mall.address,
            custom_payload: null,
            forward_ton_amount: toNano(0.1),
            forward_payload: beginCell().storeUint(2, 256).endCell().asSlice(),
        };

        const buyerOneResult = await playerOneJettonWallet.send(playerOne.getSender(), { value: toNano("0.15") }, buyerOneMsg);
        expect(buyerOneResult.transactions).toHaveTransaction({
            from: playerOneJettonWallet.address,
            to: mallJettonWallet.address,
            success: true,
        });

        blockchain.now = buyerOneResult.transactions[1].now + 1;

        let buyerTwoMsg: TokenTransfer = {
            $$type: "TokenTransfer",
            query_id: 0n,
            amount: tenToken,
            destination: mall.address,
            response_destination: mall.address,
            custom_payload: null,
            forward_ton_amount: toNano(0.1),
            forward_payload: beginCell().storeUint(2, 256).endCell().asSlice(),
        };

        const buyerTwoResult = await playerTwoJettonWallet.send(playerTwo.getSender(), { value: toNano("0.15") }, buyerTwoMsg);
        expect(buyerTwoResult.transactions).toHaveTransaction({
            from: playerTwoJettonWallet.address,
            to: mallJettonWallet.address,
            success: true,
        });
        blockchain.now = buyerTwoResult.transactions[1].now + 2;
        console.log(await mall.getHuntsMap(BigInt(2)));

        console.log(blockchain.now);
        const lotteryDraw: LotteryDraw = {
            $$type: "LotteryDraw",
            huntId: BigInt(2)
        };
        const lotteryDrawResult = await mall.send(deployer.getSender(), { value: toNano("0.1") }, lotteryDraw);
        expect(lotteryDrawResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: mall.address,
            success: true,
        });

        let huntWin = await mall.getHuntWinMap(BigInt(2));
        console.log(huntWin);
    })

    it('Test: Winner should claim successfully', async () => {
        var mallWallet = await mallJettonWallet.getGetWalletData();
        var beforeMallbalance = await mallWallet.balance;
        console.log("before mallBalance:", beforeMallbalance);

        let huntWin = await mall.getHuntWinMap(BigInt(2));
        let winner = playerThree;
        let winAmount = huntWin.award;
        let winnerJettonWallet = playerThreeJettonWallet;
        switch (huntWin.winner.toString()) {
            case deployer.address.toString():
                winner = deployer;
                winnerJettonWallet = ownerJettonWallet;
                break;
            case playerOne.address.toString():
                winner = playerOne;
                winnerJettonWallet = playerOneJettonWallet;
                break;
            case playerTwo.address.toString():
                winner = playerTwo;
                winnerJettonWallet = playerTwoJettonWallet;
                break;
            default:
                break;
        }
        var winnerWallet = await winnerJettonWallet.getGetWalletData();
        var beforeWinner = await winnerWallet.balance;
        console.log("beforeWinner Balance:", beforeWinner);

        const winnerClaim: WinnerClaim = {
            $$type: "WinnerClaim",
            huntId: BigInt(2)
        };
        const winnerClaimResult = await mall.send(winner.getSender(), { value: toNano("0.05") }, winnerClaim);
        expect(winnerClaimResult.transactions).toHaveTransaction({
            from: winner.address,
            to: mall.address,
            success: true,
        });

        mallWallet = await mallJettonWallet.getGetWalletData();
        var afterMallbalance = await mallWallet.balance;
        console.log("after mallBalance:", afterMallbalance);

        winnerWallet = await winnerJettonWallet.getGetWalletData();
        var aftereWinner = await winnerWallet.balance;
        console.log("aftereWinner Balance:", aftereWinner);

        expect(afterMallbalance).toEqual(beforeMallbalance - winAmount * 80n /100n);
        expect(aftereWinner).toEqual(beforeWinner + winAmount * 80n /100n);

    })

    // it('Test: Winner should abondon successfully', async () => {
    //     // var mallWallet = await mallJettonWallet.getGetWalletData();
    //     // var beforeMallbalance = await mallWallet.balance;
    //     // console.log("before mallBalance:", beforeMallbalance);

    //     let huntWin = await mall.getHuntWinMap(BigInt(2));
    //     let winner = playerThree;
    //     let winnerJettonWallet = playerThreeJettonWallet;
    //     switch (huntWin.winner.toString()) {
    //         case deployer.address.toString():
    //             winner = deployer;
    //             winnerJettonWallet = ownerJettonWallet;
    //             break;
    //         case playerOne.address.toString():
    //             winner = playerOne;
    //             winnerJettonWallet = playerOneJettonWallet;
    //             break;
    //         case playerTwo.address.toString():
    //             winner = playerTwo;
    //             winnerJettonWallet = playerTwoJettonWallet;
    //             break;
    //         default:
    //             break;
    //     }
    //     // let winAmount = await mall.getWinnersMap(huntWin.winner);
    //     // var winnerWallet = await winnerJettonWallet.getGetWalletData();
    //     // var beforeWinner = await winnerWallet.balance;
    //     // console.log("beforeWinner Balance:", beforeWinner);


    //     const winnerAbondonResult = await mall.send(winner.getSender(), { value: toNano("1") }, "WinnerAbandon");
    //     expect(winnerAbondonResult.transactions).toHaveTransaction({
    //         from: winner.address,
    //         to: mall.address,
    //         success: true,
    //     });

    // })

    it('Test: Owner Should Claim successfully', async () => {
        var ownerWallet = await ownerJettonWallet.getGetWalletData();
        var mallWallet = await mallJettonWallet.getGetWalletData();
        var beforeOwnerbalance = await ownerWallet.balance;
        var beforeMallbalance = await mallWallet.balance;
        // console.log("before ownerbalance:", beforeOwnerbalance);
        // console.log("before mallBalance:", beforeMallbalance);

        const ownerClaim: OwnerClaim = {
            $$type: "OwnerClaim",
            amount: beforeMallbalance - BigInt(1),
            receiver: deployer.address
        };

        const ownerClaimResult = await mall.send(deployer.getSender(), { value: toNano("0.05") }, ownerClaim);
        expect(ownerClaimResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: mall.address,
            success: true,
        });

        blockchain.now = ownerClaimResult.transactions[1].now;

        ownerWallet = await ownerJettonWallet.getGetWalletData();
        mallWallet = await mallJettonWallet.getGetWalletData();
        var afterOwnerbalance = await ownerWallet.balance;
        var afterMallbalance = await mallWallet.balance;
        // console.log("after ownerbalance:", afterOwnerbalance);
        // console.log("after mallBalance:", afterMallbalance);
        expect(afterMallbalance).toEqual(BigInt(1));
        expect(afterOwnerbalance).toEqual(beforeOwnerbalance + beforeMallbalance - BigInt(1));
    })


});
