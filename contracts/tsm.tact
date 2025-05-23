import "./jetton";

message Mint {
    amount: Int;
    receiver: Address;
}

contract TSM with Jetton {
    total_supply: Int;
    owner: Address;
    content: Cell;
    mintable: Bool;

    max_supply: Int; // Extract parameter we set here. The Jetton Standards doesn't have this parameter.

    init(owner: Address, content: Cell, max_supply: Int) {
        self.total_supply = 0;
        self.owner = owner;
        self.mintable = true;
        self.content = content;
        self.max_supply = max_supply;
    }

    receive(msg: Mint) { // 0xfc708bd2
        let ctx: Context = context();
        // require(ctx.sender == self.owner, "Not owner");
        require(self.mintable, "Not mintable");
        require(self.total_supply + msg.amount <= self.max_supply, "Max supply exceeded");
        self.mint(msg.receiver, msg.amount, self.owner); // (to, amount, response_destination)
    }

    receive("Mint: 100") { // Public Minting
        let ctx: Context = context();
        require(self.mintable, "Not mintable");
        require(self.total_supply + 100_000_000_000 <= self.max_supply, "Max supply exceeded");
        self.mint(ctx.sender, 100_000_000_000, self.owner); // 🔴 
    }

    receive("Owner: MintClose") {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not owner");
        self.mintable = false;
    }
} 