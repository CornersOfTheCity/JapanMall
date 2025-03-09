import "@stdlib/deploy";

struct WinnerInfo{
    winner:Address;
    amount:Int;
}
struct Hunt {
    huntId: Int;
    type: Int as uint8;
    price: Int as coins;
    startTime: Int;
    endTime: Int;
    amount: Int;
    selld:Int;
    userBuy:map<Address, Int>;
    ownerships:map<Int, Address>;
}
message CreateHunt {
    createdData: Hunt;
}
message Buy {
    huntId: Int;
    amount: Int;
}

message BuyEmit {
    huntId: Int;
    userAddr:Address;
    amount: Int;
}

message Create {
    price: Int;
    type: Int as uint8;
    startTime: Int;
    endTime: Int;
    amount: Int
}

message UserClaim {
    huntId: Int;          
}

message LotteryDraw {
    huntId: Int;          
}

message ChangeAddress {
    walletAddress: Address;          
}

message OwnerClaim {
    amount: Int as coins;     
    toAddress: Address;       
}

message TransferToken {
    amount: Int as coins;     
    toAddress: Address;       
}

message(0xf8a7ea5) TokenTransfer {
    query_id: Int as uint64;
    amount: Int as coins;
    destination: Address;
    response_destination: Address?;
    custom_payload: Cell?;
    forward_ton_amount: Int as coins;
    forward_payload: Slice as remaining; 
}

message(0x7362d09c) TokenNotification {
    query_id: Int as uint64;
    amount: Int as coins;
    from: Address;
    forward_payload: Slice as remaining;
}

struct JettonWalletData {
    balance: Int as coins;
    ownerAddress: Address;
    jettonMasterAddress: Address;
    jettonWalletCode: Cell;
}

// message(0x178d4519) TransferNotification {
//     queryId: Int as uint64;
//     amount: Int as coins;
//     sender: Address;
//     forwardPayload: Slice?;
// }

// message(0x7362d09c) TokenTransfer {
//     queryId: Int as uint64;
//     amount: Int as coins;
//     destination: Address;
//     responseDestination: Address?;
//     customPayload: Cell?;
//     forwardTonAmount: Int as coins;
//     forwardPayload: Slice?;
// }

contract Mall with Deployable {
    owner: Address;
    number: Int;
    queryCounter:Int;
    seed: Int;
    tokenJettonMaster: Address;
    mallTokenBalance: Int;
    mallWalletAddress:Address;
    huntWinMap: map<Int, WinnerInfo>;
    huntsMap: map<Int, Hunt>;
    winnerMap: map<Address,Int>;
    walletCode: Cell;

    // const MAX_UINT256: Int = (1 << 256) - 1;

    init(owner: Address, jettonMaster: Address, walletCode: Cell){
        self.owner = owner;
        self.mallTokenBalance = 0;
        self.number = 0;
        self.queryCounter = 0;
        self.huntsMap = emptyMap();
        self.huntWinMap = emptyMap();
        self.winnerMap = emptyMap();
        self.tokenJettonMaster = jettonMaster;
        self.walletCode = walletCode;
        self.seed =abs(randomInt());

        self.mallWalletAddress = myAddress();
    }

    fun create(type:Int, price: Int, startTime: Int, endTime: Int, amount: Int) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Invalid sender");
        require(type == 0 || type == 1,"Wrong Type Number");
        require(price > 0 && startTime >= now() && startTime > 0 && amount > 0, "Negative numbers not allowed");
        self.number += 1;
        let newHunt = Hunt{type:type, huntId: self.number, price: price, startTime: startTime, endTime: endTime, amount: amount,selld:0,userBuy:emptyMap(),ownerships:emptyMap()};
        self.huntsMap.set(self.number, newHunt);
        emit(CreateHunt{createdData: newHunt}.toCell());
    }

    // fun buy(huntId: Int, amount: Int) {
    //     require(huntId>0&&amount>0,"Negative numbers not allowed");
    //     let ctx: Context = context();
    //     require(ctx.sender != self.owner, "Owner can not buy");
    //     let hunt:Hunt = self.huntsMap.get(huntId)!!;
    //     require(hunt.startTime<=now() &&hunt.endTime >= now(),"Time Out");
    //     let selld = hunt.selld;
    //     let totalAmount = hunt.amount;
    //     require(totalAmount-selld>=amount,"Not Enough");

    //     // update seed
    //     self.seed = self.calculateSeed(ctx.sender);
    //     dump(self.seed);
        
    //     self.queryCounter += 1;
    //     let userJettonWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster, ctx.sender);
    //     let mallWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster,myAddress());
    //     let forwardPayload: Cell = beginCell()
    //         .storeInt(0,8)
    //         .storeAddress(ctx.sender)
    //         .storeInt(huntId,256)
    //         .endCell();

    //     self.sendJettonTransfer(
    //         userJettonWalletAddress,
    //         ton("0.2"),

    //         self.queryCounter,
    //         amount*hunt.price,
    //         mallWalletAddress,
    //         myAddress(),
    //         ton("0.1"),
    //         forwardPayload
    //     );
        
    //     // send(SendParameters{
    //     //         to: userJettonWalletAddress,
    //     //         value: ton("0.1"), // 发送少量 TON 支付 gas
    //     //         body: TokenTransfer{
    //     //             queryId: self.queryCounter,
    //     //             amount: amount*hunt.price, // 用户指定的转账数量
    //     //             destination: myAddress(), // 转账目标为本合约
    //     //             responseDestination: myAddress(), // 剩余 TON 返回给用户
    //     //             customPayload: null,
    //     //             forwardTonAmount: ton("0.05"), // 前转少量 TON 给目标
    //     //             forwardPayload: forwardPayload.asSlice()
    //     //         }.toCell()
    //     //     }
    //     // );
    //     self.querysMap.set(self.queryCounter,forwardPayload);
    // }

    fun lotteryDraw(huntId: Int){
        let ctx: Context = context();
        let hunt:Hunt = self.huntsMap.get(huntId)!!;
        let range:Int = 0;
        if(hunt.type == 0){
            require(hunt.amount == hunt.selld,"Not sold out");
            range = hunt.amount;
        }else{
            require(hunt.endTime >= now(),"Not now");
            range = hunt.selld;
        }
        self.seed = self.calculateSeed(ctx.sender);
        let winNumber:Int = self.seed % range +1;
        dump(winNumber);
        let winnerInfo:WinnerInfo = self.getHuntWinner(huntId,winNumber);
        self.huntWinMap.set(huntId,winnerInfo);
        self.winnerMap.set(winnerInfo.winner,hunt.amount*hunt.price);
        self.huntsMap.del(huntId);
    }

    fun userClaimBack(huntId:Int){
        require(huntId>0,"Negative numbers not allowed");
       let ctx: Context = context();
       let claimer:Address = ctx.sender;
       let hunt:Hunt = self.huntsMap.get(huntId)!!;
       require(hunt.type == 0 && hunt.endTime<now() && hunt.selld < hunt.amount,"Condition Not Met");

       let userWinAmount:Int = hunt.userBuy.get(claimer)!!;

       let price:Int = hunt.price;

       dump(userWinAmount);

        // let mallWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster,myAddress());

        self.queryCounter += 1;
        // let userJettonWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster, claimer);
        // let forwardPayload: Cell = beginCell()
        //     .storeInt(2,8)
        //     .storeAddress(claimer)
        //     .endCell();

            self.sendJettonTransfer(
                self.mallWalletAddress,
                ton("0.1"),

                self.queryCounter,
                userWinAmount * price,
                claimer,
                myAddress(),
                ton("0.05"),
                emptySlice()
            );

        // 发送 TokenTransfer 消息
        // send(SendParameters{
        //     to: mallWalletAddress,
        //     value: ton("0.1"),  // 用于支付 gas
        //     body: TokenTransfer{
        //         queryId: self.queryCounter,  // 使用时间戳作为 queryId
        //         amount: userWinAmount,
        //         destination: claimer,  
        //         responseDestination: myAddress(),  // 剩余 TON 返回给合约
        //         customPayload: null,
        //         forwardTonAmount: ton("0.05"),  // 转发给目标地址的 TON
        //         forwardPayload: forwardPayload.asSlice()
        //     }.toCell()
        // });

        hunt.selld -= userWinAmount;
        hunt.userBuy.del(claimer);

        if(hunt.selld != 0){
            self.huntsMap.set(huntId,hunt);
        }else{
            self.huntsMap.del(huntId);
        }
        // self.querysMap.set(self.queryCounter,forwardPayload);
    }

    fun winnerClaim(){
        let ctx: Context = context();
        let claimer:Address = ctx.sender;
        let userWinAmount:Int = self.winnerMap.get(ctx.sender)!!;
        
        // let mallWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster,myAddress());

        // self.queryCounter += 1;
        // let userJettonWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster, claimer);
        // let forwardPayload: Cell = beginCell()
        //     .storeInt(3,8)
        //     .storeAddress(ctx.sender)
        //     .endCell();
        
        self.sendJettonTransfer(
                self.mallWalletAddress,
                ton("0.1"),

                self.queryCounter,
                userWinAmount,
                claimer,
                myAddress(),
                ton("0.05"),
                emptySlice()
            );

        // 发送 TokenTransfer 消息
        // send(SendParameters{
        //     to: mallWalletAddress,
        //     value: ton("0.1"),  // 用于支付 gas
        //     body: TokenTransfer{
        //         queryId: self.queryCounter,  // 使用时间戳作为 queryId
        //         amount: userWinAmount,
        //         destination: claimer,  
        //         responseDestination: myAddress(),  // 剩余 TON 返回给合约
        //         customPayload: null,
        //         forwardTonAmount: ton("0.05"),  // 转发给目标地址的 TON
        //         forwardPayload: forwardPayload.asSlice()
        //     }.toCell()
        // });
        
        self.winnerMap.del(claimer);

        // self.querysMap.set(self.queryCounter,forwardPayload);

    }

    fun winnerAbandon(){
        let ctx: Context = context();
        let claimer:Address = ctx.sender;
        let amount:Int = self.winnerMap.get(ctx.sender)!!;
        self.winnerMap.del(claimer);
    }

    fun ownerClaim(amount:Int,receiver:Address){
       let ctx: Context = context();
        require(ctx.sender == self.owner, "Only owner can withdraw");
        // require(amount <= self.mallTokenBalance, "Insufficient Token balance");
        // let mallWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster,myAddress());

        // self.queryCounter += 1;
        // let userJettonWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster, ctx.sender);
        // let forwardPayload: Cell = beginCell()
        //     .storeInt(4,8)
        //     .storeAddress(ctx.sender)
        //     .endCell();

        self.sendJettonTransfer(
                self.mallWalletAddress,
                ton("0.5"),

                self.queryCounter,
                amount,
                receiver,
                myAddress(),
                ton("0.2"),
                emptySlice()
            );

        // 发送 TokenTransfer 消息
        // send(SendParameters{
        //     to: mallWalletAddress,
        //     value: ton("0.1"),  // 用于支付 gas
        //     body: TokenTransfer{
        //         queryId: self.queryCounter,  // 使用时间戳作为 queryId
        //         amount: amount,
        //         destination: receiver,  // 转到管理员的钱包地址
        //         responseDestination: myAddress(),  // 剩余 TON 返回给合约
        //         customPayload: null,
        //         forwardTonAmount: ton("0.05"),  // 转发给目标地址的 TON
        //         forwardPayload: forwardPayload.asSlice()
        //     }.toCell()
        // });

        // self.querysMap.set(self.queryCounter,forwardPayload);
        self.mallTokenBalance -= amount;
    }

    fun getWalletAddress(jettonMaster: Address, userAddress: Address): Address {
        let walletData: Cell = beginCell().storeAddress(userAddress).storeAddress(jettonMaster).storeRef(self.walletCode).endCell();
        let walletInit: StateInit = StateInit{code: self.walletCode, data: walletData};
        return contractAddress(walletInit);
    }

    fun calculateJettonWalletAddress(ownerAddress: Address,jettonMasterAddress: Address,jettonWalletCode: Cell): Address {

    let initData = JettonWalletData{
        balance: 0,
        ownerAddress,
        jettonMasterAddress,
        jettonWalletCode,
    };

    return contractAddress(StateInit{
        code: jettonWalletCode,
        data: initData.toCell(),
    });
}

    fun calculateSeed(seedAddress:Address):Int{
        let senderHash = sha256(seedAddress.toString());
        dump(senderHash);
        // let absRandom = abs(randomInt());
        // dump(absRandom);
        dump(now());

        let combined = beginCell()
        .storeUint(senderHash, 256)    // 存储 256 位哈希
        // .storeUint(absRandom, 256)   // 存储随机值（257 位）
        .storeUint(self.seed, 256)     // 存储当前种子
        .storeUint(now(),256)
        .endCell();

        return sha256(combined.asSlice());
    }

    fun getHuntWinner(huntId:Int,checkNumber:Int):WinnerInfo{
        require(huntId>0&&checkNumber>0,"Negative numbers not allowed");
        let hunt:Hunt = self.huntsMap.get(huntId)!!;
        require(checkNumber<=hunt.selld,"Negative numbers not allowed");
        let userBuy:map<Address, Int> = hunt.userBuy;
        let ownerships:map<Int, Address> = hunt.ownerships;
        let curr:Int = checkNumber;
        let winnerAddr:Address = self.owner;
        let winnerAmount:Int = 0;
        while(true){
            let winner:Address? = ownerships.get(curr);
            if(winner != null){
                winnerAddr = ownerships.get(curr)!!;
                winnerAmount = userBuy.get(winnerAddr)!!;
                return WinnerInfo{winner: winnerAddr,amount: winnerAmount};
            }
            curr+=1;
        }
        return WinnerInfo{winner: winnerAddr,amount: winnerAmount};
    }


    //  query_id: Int as uint64;
    // amount: Int as coins;
    // sender: Address;
    // response_destination: Address?;
    // custom_payload: Cell?;
    // forward_ton_amount: Int as coins;
    // forward_payload: Slice as remaining; 

    fun sendJettonTransfer(
        to: Address,
        value: Int ,
    
        queryId: Int,
        amount: Int,
        destination: Address,
        responseDestination: Address,
        forwardTonAmount: Int,
        forwardPayload: Slice,
    ) {
        send(SendParameters{
            to: to,
            value: value,
            body: TokenTransfer{
                query_id: queryId,
                amount: amount,
                destination: destination,
                response_destination: responseDestination,
                custom_payload: null,
                forward_ton_amount: forwardTonAmount,
                forward_payload: forwardPayload
            }.toCell()
        });
    }

    fun setJettonAddress(walletAddress:Address){
        let ctx: Context = context();
        require(ctx.sender == self.owner,"Wrong Sender");
        self.mallWalletAddress = walletAddress;
    }

    // receive(msg:Buy){
    //     self.buy(msg.huntId,msg.amount);
    // }

    receive(msg:ChangeAddress){
        self.setJettonAddress(msg.walletAddress);
    }

    receive("WinnerClaim"){
        self.winnerClaim();
    }

    receive(msg:OwnerClaim){
        self.ownerClaim(msg.amount,msg.toAddress);
    }

    receive(msg:UserClaim){
        self.userClaimBack(msg.huntId);
    }

    receive(msg:LotteryDraw){
        self.lotteryDraw(msg.huntId);
    }

    receive("WinnerAbandon"){
        self.winnerAbandon();
    }

    receive(msg:Create){
        self.create(msg.type,msg.price,msg.startTime,msg.endTime,msg.amount);
    }

    // query_id: Int as uint64;
    // amount: Int as coins;
    // from: Address;
    // forward_payload: Slice as remaining;

    receive(msg: TokenNotification) {
        let ctx: Context = context();
        //  let master = contract<JettonMaster>(self.tokenJettonMaster);
        // let master = contract<JettonMaster>(self.tokenJettonMaster);
        // let mallWalletAddress: Address = self.getWalletAddress(myAddress(),self.tokenJettonMaster);
        // let mallWalletAddress2: Address = self.calculateJettonWalletAddress(myAddress(),self.tokenJettonMaster,self.walletCode);

        // dump(mallWalletAddress);
        // dump(ctx.sender);
        // dump(myAddress());
        // dump(mallWalletAddress2);

        // Buy
        // if(ctx.sender == mallWalletAddress){
        //     dump(userWalletAddress);
        //     let huntId: Int = msg.forward_payload.loadInt(256);
        //     dump(huntId);

        //     let hunt:Hunt = self.huntsMap.get(huntId)!!;
        //     // dump(hunt);

        //     let price:Int = hunt.price;
        //     let buyAmount:Int = msg.amount/price;

        //     dump(buyAmount);

        //     hunt.selld +=buyAmount;

        //     self.mallTokenBalance += msg.amount;

        //     let bought:Int? = hunt.userBuy.get(msg.from);
        //     if(bought == null){
        //         hunt.userBuy.set(msg.from,msg.amount);
        //     }else{
        //         let boughtInt:Int = hunt.userBuy.get(msg.from)!!;
        //         hunt.userBuy.set(msg.from,boughtInt+msg.amount);
        //     }
        //     hunt.ownerships.set(hunt.selld,msg.from);

        //     self.mallTokenBalance += msg.amount;
        //     emit(BuyEmit{huntId:huntId,userAddr: msg.from,amount:msg.amount}.toCell());
        // }
        require(ctx.sender == self.mallWalletAddress,"Wromng Sender");
        if(msg.forward_payload!= emptySlice()){
            let messageIndex:Int = msg.forward_payload.loadInt(8);
            let huntId: Int = msg.forward_payload.loadInt(256);
            dump(huntId);

            let hunt:Hunt = self.huntsMap.get(huntId)!!;
            // dump(hunt);

            let price:Int = hunt.price;
            let buyAmount:Int = msg.amount/price;

            dump(buyAmount);
            require(hunt.amount - hunt.selld >= buyAmount ,"Left Not Enough");
            hunt.selld += buyAmount;

            dump(hunt.selld);

            self.mallTokenBalance += msg.amount;

            let bought:Int? = hunt.userBuy.get(msg.from);
            if(bought == null){
                hunt.userBuy.set(msg.from,buyAmount);
            }else{
                let boughtInt:Int = hunt.userBuy.get(msg.from)!!;
                hunt.userBuy.set(msg.from,boughtInt+buyAmount);
                dump(hunt.userBuy.get(msg.from)!!);
            }
            hunt.ownerships.set(hunt.selld,msg.from);

            emit(BuyEmit{huntId:huntId,userAddr: msg.from,amount:msg.amount}.toCell());
            dump(self.mallTokenBalance);
            self.huntsMap.set(huntId,hunt);

            self.seed = self.calculateSeed(msg.from);
            dump(self.seed);
        }else{
            self.mallTokenBalance += msg.amount;
        }

       
        // else if(messageIndex == 4){
        //     dump(msg.query_id);
        //     let queryCell:Cell = self.querysMap.get(msg.query_id)!!;
        //     let querySlice: Slice = queryCell.asSlice();
        //     let payload: Slice = msg.forward_payload;
        //     require(querySlice==payload,"Wrong Slice");
        //     dump(messageIndex);

        //     self.querysMap.del(msg.query_id);
        // }

            

        // //claimback
        // else if(ctx.sender == userWalletAddress){

        // }
        // else{

        // }

        // if(msg.forward_payload!=null){
        //     let queryCell:Cell = self.querysMap.get(msg.query_id)!!;
        //     let querySlice: Slice = queryCell.asSlice();
        //     let payload: Slice = msg.forwardPayload!!;
        //     require(querySlice==payload,"Wrong Slice");
            
        //     let index: Int = payload.loadInt(8);
        //     dump(index);

        //     let userAddress: Address = payload.loadAddress();
        //     if(index == 0){
        //         let huntId: Int = payload.loadInt(256);
        //         dump(huntId);
        //         let hunt:Hunt = self.huntsMap.get(huntId)!!;
        //         hunt.selld += msg.amount;
        //         let bought:Int = hunt.userBuy.get(userAddress)!!;
        //         hunt.userBuy.set(userAddress,bought+msg.amount);
        //         hunt.ownerships.set(hunt.selld,userAddress);
        //         self.mallTokenBalance += msg.amount;
                
        //         emit(BuyEmit{huntId:huntId,userAddr: userAddress,amount:msg.amount}.toCell());
        //     }else{
        //         self.mallTokenBalance -= msg.amount;
        //     }
        //     self.querysMap.del(msg.query_id);
        // }else{
        //     self.mallTokenBalance += msg.amount;
        // }
    }

    get fun huntsMap(number:Int): Hunt {
        return self.huntsMap.get(number)!!;
    }

    get fun time(): Int {
        return now();
    }

    get fun balance(): Int {
        return self.mallTokenBalance;
    }

    get fun winnersMap(winner:Address): Int {
        return self.winnerMap.get(winner)!!;
    }

    get fun huntWinMap(huntId:Int): WinnerInfo{
        return self.huntWinMap.get(huntId)!!;
    }
}