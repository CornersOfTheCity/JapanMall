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
    userBuy:map<Address, Int as uint256>;
    ownerships:map<Int as uint256, Address>;
}
message CreateHunt {
    createdData: Hunt;
}
message Buy {
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

message OwnerClaim {
    amount: Int as coins;     
    toAddress: Address;       
}

message TransferToken {
    amount: Int as coins;     
    toAddress: Address;       
}

message(0x178d4519) TransferNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    sender: Address;
    forwardPayload: Slice?;
}

message(0x7362d09c) JettonTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    responseDestination: Address?;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice?;
}

contract Mall with Deployable {
    owner: Address;
    number: Int as uint256;
    queryCounter:Int as uint256;
    seed: Int;
    tokenJettonMaster: Address;
    mallTokenBalance: Int as uint256;
    querysMap: map<Int as uint256, Cell>;
    huntsMap: map<Int as uint256, Hunt>;
    winnerMap: map<Address,Int as uint256>;
    walletCode: Cell;

    init(owner: Address, jettonMaster: Address, walletCode: Cell){
        self.owner = owner;
        self.mallTokenBalance = 0;
        self.number = 0;
        self.queryCounter = 0;
        self.huntsMap = emptyMap();
        self.querysMap = emptyMap();
        self.winnerMap = emptyMap();
        self.tokenJettonMaster = jettonMaster;
        self.walletCode = walletCode;
        self.seed =abs(randomInt());
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

    fun buy(huntId: Int, amount: Int) {
        require(huntId>0&&amount>0,"Negative numbers not allowed");
        let ctx: Context = context();
        require(ctx.sender != self.owner, "Owner can not buy");
        let hunt:Hunt = self.huntsMap.get(huntId)!!;
        require(hunt.endTime >= now(),"Time Out");
        let selld = hunt.selld;
        let totalAmount = hunt.amount;
        require(totalAmount-selld>=amount,"Not Enough");

        //update seed
        self.seed = self.calculateSeed(ctx.sender);
        
        self.queryCounter += 1;
        let userJettonWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster, ctx.sender);
        let forwardPayload: Cell = beginCell()
            .storeInt(0,8)
            .storeAddress(ctx.sender)
            .storeInt(huntId,256)
            .endCell();
        
        send(SendParameters{
                to: userJettonWalletAddress,
                value: ton("0.1"), // 发送少量 TON 支付 gas
                body: JettonTransfer{
                    queryId: self.queryCounter,
                    amount: amount*hunt.price, // 用户指定的转账数量
                    destination: myAddress(), // 转账目标为本合约
                    responseDestination: myAddress(), // 剩余 TON 返回给用户
                    customPayload: null,
                    forwardTonAmount: ton("0.05"), // 前转少量 TON 给目标
                    forwardPayload: forwardPayload.asSlice()
                }.toCell()
            }
        );
        self.querysMap.set(self.queryCounter,forwardPayload);
    }

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
        let winnerInfo:WinnerInfo = self.getHuntWinner(huntId,winNumber);
        self.winnerMap.set(winnerInfo.winner,winnerInfo.amount);
        self.huntsMap.del(huntId);
    }

    fun userClaimBack(huntId:Int){
        require(huntId>0,"Negative numbers not allowed");
       let ctx: Context = context();
       let claimer:Address = ctx.sender;
       let hunt:Hunt = self.huntsMap.get(huntId)!!;
       require(hunt.type == 0 && hunt.endTime<now() && hunt.selld < hunt.amount,"Condition Not Met");

       let userBuyAmount:Int = hunt.userBuy.get(claimer)!!;

        let mallWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster,myAddress());

        self.queryCounter += 1;
        let userJettonWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster, claimer);
        let forwardPayload: Cell = beginCell()
            .storeInt(1,8)
            .storeAddress(claimer)
            .endCell();

        // 发送 JettonTransfer 消息
        send(SendParameters{
            to: mallWalletAddress,
            value: ton("0.1"),  // 用于支付 gas
            body: JettonTransfer{
                queryId: self.queryCounter,  // 使用时间戳作为 queryId
                amount: userBuyAmount,
                destination: claimer,  
                responseDestination: myAddress(),  // 剩余 TON 返回给合约
                customPayload: null,
                forwardTonAmount: ton("0.05"),  // 转发给目标地址的 TON
                forwardPayload: forwardPayload.asSlice()
            }.toCell()
        });

        hunt.selld -= userBuyAmount;
        hunt.userBuy.del(claimer);

        self.querysMap.set(self.queryCounter,forwardPayload);
    }

    fun winnerClaim(){
        let ctx: Context = context();
        let claimer:Address = ctx.sender;
        let amount:Int = self.winnerMap.get(ctx.sender)!!;
        
        let mallWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster,myAddress());

        self.queryCounter += 1;
        let userJettonWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster, claimer);
        let forwardPayload: Cell = beginCell()
            .storeInt(2,8)
            .storeAddress(ctx.sender)
            .endCell();

        // 发送 JettonTransfer 消息
        send(SendParameters{
            to: mallWalletAddress,
            value: ton("0.1"),  // 用于支付 gas
            body: JettonTransfer{
                queryId: self.queryCounter,  // 使用时间戳作为 queryId
                amount: amount,
                destination: claimer,  
                responseDestination: myAddress(),  // 剩余 TON 返回给合约
                customPayload: null,
                forwardTonAmount: ton("0.05"),  // 转发给目标地址的 TON
                forwardPayload: forwardPayload.asSlice()
            }.toCell()
        });
        self.winnerMap.del(claimer);

         self.querysMap.set(self.queryCounter,forwardPayload);

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
        require(amount <= self.mallTokenBalance, "Insufficient Token balance");
        let mallWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster,myAddress());

        self.queryCounter += 1;
        let userJettonWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster, ctx.sender);
        let forwardPayload: Cell = beginCell()
            .storeInt(3,8)
            .storeAddress(ctx.sender)
            .endCell();

        // 发送 JettonTransfer 消息
        send(SendParameters{
            to: mallWalletAddress,
            value: ton("0.1"),  // 用于支付 gas
            body: JettonTransfer{
                queryId: self.queryCounter,  // 使用时间戳作为 queryId
                amount: amount,
                destination: receiver,  // 转到管理员的钱包地址
                responseDestination: myAddress(),  // 剩余 TON 返回给合约
                customPayload: null,
                forwardTonAmount: ton("0.05"),  // 转发给目标地址的 TON
                forwardPayload: forwardPayload.asSlice()
            }.toCell()
        });
        self.querysMap.set(self.queryCounter,forwardPayload);
    }

    fun getWalletAddress(jettonMaster: Address, userAddress: Address): Address {
        let walletData: Cell = beginCell().storeAddress(jettonMaster).storeAddress(userAddress).storeCoins(0).endCell();
        let walletInit: StateInit = StateInit{code: self.walletCode, data: walletData};
        return contractAddress(walletInit);
    }

    fun calculateSeed(seedAddress:Address):Int{
        let senderhash = abs(sha256(seedAddress.toString()));
        let absRandom = abs(randomInt());
        return abs(sha256((senderhash+absRandom+self.seed).toString()));
    }

    fun getHuntWinner(huntId:Int,checkNumber:Int):WinnerInfo{
        require(huntId>0&&checkNumber>0,"Negative numbers not allowed");
        let hunt:Hunt = self.huntsMap.get(huntId)!!;
        require(checkNumber<=hunt.selld,"Negative numbers not allowed");
        let userBuy:map<Address, Int as uint256> = hunt.userBuy;
        let ownerships:map<Int as uint256, Address> = hunt.ownerships;
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

    receive(msg:Buy){
        self.buy(msg.huntId,msg.amount);
    }

    receive("WinnerClaim"){
        self.winnerClaim();
    }

    receive(msg:OwnerClaim){
        self.ownerClaim(msg.amount,msg.toAddress);
    }

    receive("WinnerAbandon"){
        self.winnerAbandon();
    }

    receive(msg:Create){
        self.create(msg.type,msg.price,msg.startTime,msg.endTime,msg.amount);
    }

    receive(msg: TransferNotification) {
        let ctx: Context = context();
        let mallWalletAddress: Address = self.getWalletAddress(self.tokenJettonMaster,myAddress());
        require(ctx.sender == mallWalletAddress, "Invalid sender");
        if(msg.forwardPayload !=null){
            let queryCell:Cell = self.querysMap.get(msg.queryId)!!;
            let querySlice: Slice = queryCell.asSlice();
            let payload: Slice = msg.forwardPayload!!;
            require(querySlice==payload,"Wrong Slice");

            let index: Int = payload.loadInt(8);
            let userAddress: Address = payload.loadAddress();
            if(index == 0){
                let huntId: Int = payload.loadInt(256);
                let hunt:Hunt = self.huntsMap.get(huntId)!!;
                hunt.selld += msg.amount;
                let bought:Int = hunt.userBuy.get(userAddress)!!;
                hunt.userBuy.set(userAddress,bought+msg.amount);
                hunt.ownerships.set(hunt.selld,userAddress);
                self.mallTokenBalance += msg.amount;
                self.querysMap.del(msg.queryId);
                emit(Buy{huntId:huntId,userAddr: userAddress,amount:msg.amount}.toCell());
            }else{
                self.mallTokenBalance -= msg.amount;
                self.querysMap.del(msg.queryId);
            }
        }else{
            self.mallTokenBalance += msg.amount;
        }
    }
}