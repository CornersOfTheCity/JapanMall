import "@stdlib/deploy";

struct WinnerInfo{
    winner:Address;
    award:Int;
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

message Create {
    price: Int;
    type: Int as uint8;
    startTime: Int;
    endTime: Int;
    amount: Int
}

message CreateHuntEmit {
    huntId: Int;
    type: Int as uint8;
    price: Int as coins;
    startTime: Int;
    endTime: Int;
    amount: Int;
    selld:Int;
}

message BuyEmit {
    huntId: Int;
    userAddr:Address;
    amount: Int;
    startIndex:Int;
    endIndex:Int;
    timeasmp:Int;
}

message UserClaim {
    huntId: Int;          
}

message UserClaimBackEmit {
    huntId: Int;
    claimer:Address;
    claimAmount:Int;
    timeStamp:Int;    
}

message LotteryDraw {
    huntId: Int;          
}

message LotteryDrawEmit {
    huntId: Int; 
    drawer:Address; 
    luckyNumber:Int;
    winner: Address;
    winAmount: Int; 
    timeStamp:Int;              
}

message WinnerClaim {
    huntId: Int;          
}

message WinnerClaimEmit {
    huntId: Int;
    claimer:Address;
    claimAmount:Int;
    timeStamp:Int;    
}

message WinnerAbondon {
    huntId: Int;          
}

message WinnerAbondonEmit {
    huntId: Int;
    winner:Address;
    abondon: Bool; 
    timeStamp:Int;            
}

message SetWalletAddress {
    walletAddress: Address;          
}

message SetPrecent {
    precent: Int;          
}

message OwnerClaim {
    amount: Int as coins;     
    receiver: Address;       
}

message TransferToken {
    amount: Int as coins;     
    toAddress: Address;       
}

message(0xf8a7ea5) JettonTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    responseDestination: Address?;
    customPayload: Cell? = null;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

message(0x7362d09c) JettonNotification {
    query_id: Int as uint64;
    amount: Int as coins;
    from: Address;
    forward_payload: Slice as remaining;
}

contract Mall with Deployable {
    owner: Address;
    precent: Int;
    number: Int;
    queryCounter:Int;
    seed: Int;
    jettonTransferGas: Int;
    tokenJettonMaster: Address;
    mallTokenBalance: Int;
    mallWalletAddress:Address;
    huntWinMap: map<Int, WinnerInfo>;
    huntsMap: map<Int, Hunt>;

    init(owner: Address, jettonMaster: Address){
        self.owner = owner;
        self.precent = 80;
        self.mallTokenBalance = 0;
        self.number = 0;
        self.queryCounter = 0;
        self.huntsMap = emptyMap();
        self.huntWinMap = emptyMap();
        self.tokenJettonMaster = jettonMaster;
        self.seed =abs(randomInt());
        self.jettonTransferGas = ton("0.05");

        self.mallWalletAddress = myAddress();
    }

    fun create(type:Int, price: Int, startTime: Int, endTime: Int, amount: Int) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Invalid sender");
        require(type == 0 || type == 1,"Wrong Type Number");
        require(price > 0 && startTime > 0 && endTime > now() && startTime < endTime && amount > 0, "Negative numbers not allowed");
        self.number += 1;
        let newHunt = Hunt{type:type, huntId: self.number, price: price, startTime: startTime, endTime: endTime, amount: amount,selld:0,userBuy:emptyMap(),ownerships:emptyMap()};
        self.huntsMap.set(self.number, newHunt);
        emit(CreateHuntEmit{huntId: newHunt.huntId,type: newHunt.type,price: newHunt.price,startTime: newHunt.startTime, endTime: newHunt.endTime,amount: newHunt.amount,selld:newHunt.selld}.toCell());
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
        self.huntWinMap.set(huntId,winnerInfo);
        let winAmount:Int = hunt.amount*hunt.price;
        self.huntsMap.del(huntId);             

        emit(LotteryDrawEmit{huntId:huntId,drawer:ctx.sender,luckyNumber:winNumber, winner:winnerInfo.winner,winAmount:winAmount,timeStamp:now()}.toCell());
    }

    fun userClaimBack(huntId:Int){
        require(huntId>0,"Negative numbers not allowed");
       let ctx: Context = context();
       let claimer:Address = ctx.sender;
       let hunt:Hunt = self.huntsMap.get(huntId)!!;
        //    require(hunt.type == 0 && hunt.endTime<now() && hunt.selld < hunt.amount,"Condition Not Met");
        require(hunt.type == 0,"Condition Not Met");

       let userBuyAmount:Int = hunt.userBuy.get(claimer)!!;

       let price:Int = hunt.price;

       dump(userBuyAmount);

       let userClaimAmount:Int = userBuyAmount * price;

        self.queryCounter += 1;

            self.sendJettonTransfer(
                userClaimAmount,
                claimer,
            );

        hunt.selld -= userBuyAmount;
        hunt.userBuy.del(claimer);

        self.huntsMap.set(huntId,hunt);
        // if(hunt.selld != 0){
        //     self.huntsMap.set(huntId,hunt);
        // }else{
        //     self.huntsMap.del(huntId);
        // }
        emit(UserClaimBackEmit{huntId:huntId,claimer:ctx.sender,claimAmount:userClaimAmount,timeStamp:now()}.toCell());
    }

    fun winnerClaim(huntId:Int){
        let ctx: Context = context();
        let claimer:Address = ctx.sender;
        let winnerInfo:WinnerInfo = self.huntWinMap.get(huntId)!!;
        require(winnerInfo.winner == claimer,"Not Winner");

        let claimAmount:Int = winnerInfo.award * self.precent / 100;
        
        self.sendJettonTransfer(
                claimAmount,
                claimer,
            );
        // self.mallTokenBalance -= claimAmount;
        self.huntWinMap.del(huntId);
        emit(WinnerClaimEmit{huntId:huntId,claimer:claimer,claimAmount:claimAmount,timeStamp:now()}.toCell());
    }

    fun winnerAbandon(huntId:Int){
        let ctx: Context = context();
        let claimer:Address = ctx.sender;
        let winnerInfo:WinnerInfo = self.huntWinMap.get(huntId)!!;
        require(winnerInfo.winner == claimer,"Not Winner");

        self.huntWinMap.del(huntId);

        emit(WinnerAbondonEmit{huntId:huntId,winner:claimer,abondon:true,timeStamp:now()}.toCell());
    }

    fun ownerClaim(claimAmount:Int,receiver:Address){
       let ctx: Context = context();
        require(ctx.sender == self.owner, "Only owner can withdraw");

       self.sendJettonTransfer(
                claimAmount,
                receiver,
            );

        // self.mallTokenBalance -= claimAmount;
    }

    fun calculateSeed(seedAddress:Address):Int{
        let senderHash = sha256(seedAddress.toString());
        dump(senderHash);
        nativeRandomizeLt(); 
        let absRandom:Int = abs(randomInt());
        dump(absRandom);
        dump(now());

        let combined = beginCell()
        .storeUint(senderHash, 256)    // 存储 256 位哈希
        .storeUint(absRandom, 256)   // 存储随机值（257 位）
        .storeUint(self.seed, 256)     // 存储当前种子
        .storeUint(now(),64)
        .endCell();

        return sha256(combined.asSlice());
    }

    fun getHuntWinner(huntId:Int,checkNumber:Int):WinnerInfo{
        require(huntId>0&&checkNumber>0,"Negative numbers not allowed");
        let hunt:Hunt = self.huntsMap.get(huntId)!!;
        require(checkNumber<=hunt.selld,"Negative numbers not allowed");
        let userBuy:map<Address, Int> = hunt.userBuy;
        let ownerships:map<Int, Address> = hunt.ownerships;
        let price = hunt.price;
        let selld = hunt.selld;
        let curr:Int = checkNumber;
        let winnerAddr:Address = self.owner;
        let awardAmount:Int = price*selld;
        while(true){
            let winner:Address? = ownerships.get(curr);
            if(winner != null){
                winnerAddr = ownerships.get(curr)!!;
                // winnerAmount = userBuy.get(winnerAddr)!!;
                return WinnerInfo{winner: winnerAddr,award: awardAmount};
            }
            curr+=1;
        }
        return WinnerInfo{winner: winnerAddr,award: awardAmount};
    }

    fun sendJettonTransfer(
        transferAmount: Int,
        receiver: Address,
    ) {
        send(SendParameters{
            to: self.mallWalletAddress,
            value: self.jettonTransferGas,
            body: JettonTransfer{
                // To prevent replay attacks
                queryId: 42,
                // Jetton amount to transfer
                amount: transferAmount,
                // Where to transfer Jettons:
                // this is an address of the Jetton wallet
                // owner and not the Jetton wallet itself
                destination:receiver,
                // Where to send a confirmation notice of a successful transfer
                // and the rest of the incoming message value
                responseDestination: sender(),
                // Can be used for custom logic of Jettons themselves,
                // and without such can be set to null
                customPayload: null,
                // Amount to transfer with JettonTransferNotification,
                // which is needed for the execution of custom logic
                forwardTonAmount: 1, // if its 0, the notification won't be sent!
                // Compile-time way of expressing:
                //     beginCell().storeUint(0xF, 4).endCell().beginParse()
                // For more complicated transfers, adjust accordingly
                forwardPayload: rawSlice("F")
            }.toCell()
        });
    }

    fun setJettonAddress(walletAddress:Address){
        let ctx: Context = context();
        require(ctx.sender == self.owner,"Wrong Sender");
        self.mallWalletAddress = walletAddress;
    }

    fun setPrecent(newPrecent:Int){
        let ctx: Context = context();
        require(ctx.sender == self.owner,"Wrong Sender");
        require(newPrecent >= 0 && newPrecent <= 100,"Wrong Precent");
        self.precent = newPrecent;
    }

    receive(msg:SetWalletAddress){
        self.setJettonAddress(msg.walletAddress);
    }

    receive(msg:SetPrecent){
        self.setPrecent(msg.precent);
    }

    receive(msg:WinnerClaim){
        self.winnerClaim(msg.huntId);
    }

    receive(msg:OwnerClaim){
         self.ownerClaim(msg.amount,msg.receiver);
    }

    receive(msg:UserClaim){
        self.userClaimBack(msg.huntId);
    }

    receive(msg:LotteryDraw){
        self.lotteryDraw(msg.huntId);
    }

    receive(msg:WinnerAbondon){
        self.winnerAbandon(msg.huntId);
    }

    receive(msg:Create){
        self.create(msg.type,msg.price,msg.startTime,msg.endTime,msg.amount);
    }

    receive(msg: JettonNotification) {
        let ctx: Context = context();
        require(ctx.sender == self.mallWalletAddress,"Wromng Sender");
        if(msg.forward_payload!= emptySlice()){
            let huntId: Int = msg.forward_payload.loadInt(256);
            let hunt:Hunt = self.huntsMap.get(huntId)!!;
            let price:Int = hunt.price;
            let buyAmount:Int = msg.amount/price;
            require(hunt.amount - hunt.selld >= buyAmount ,"Left Not Enough");
            let startIndex:Int = hunt.selld + 1;
            let endIndex:Int = hunt.selld + buyAmount;
            hunt.selld += buyAmount;

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
            self.huntsMap.set(huntId,hunt);
            self.seed = self.calculateSeed(msg.from);
            emit(BuyEmit{huntId:huntId,userAddr: msg.from,amount:msg.amount,startIndex:startIndex,endIndex:endIndex,timeasmp:now()}.toCell());
        }else{
            self.mallTokenBalance += msg.amount;
        }
    }

    receive() { cashback(sender()) } 

    get fun huntsMap(number:Int): Hunt {
        return self.huntsMap.get(number)!!;
    }

    get fun balance(): Int {
        return self.mallTokenBalance;
    }

    get fun huntWinMap(huntId:Int): WinnerInfo{
        return self.huntWinMap.get(huntId)!!;
    }
}