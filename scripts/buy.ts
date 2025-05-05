import TonWeb from 'tonweb';
import * as TonWebMnemonic from 'tonweb-mnemonic';
import { Address, Cell, beginCell  } from '@ton/core';

// 配置参数
const JETTON_TRANSFER_OPCODE = 0xf8a7ea5; // Jetton 转账的操作码
const JETTON_AMOUNT = BigInt(TonWeb.utils.toNano('10').toString()); // 发送 1 个 Jetton，转为 bigint
const TON_AMOUNT = BigInt(TonWeb.utils.toNano('0.15').toString()); // 附带的 TON 数量，转为 bigint
const FORWARD_TON_AMOUNT = BigInt(TonWeb.utils.toNano('0.1').toString()); // 附带的 TON 数量，转为 bigint

// 初始化 TonWeb
const tonweb = new TonWeb(new TonWeb.HttpProvider('https://testnet.toncenter.com/api/v2/jsonRPC')); // 主网 RPC

async function sendJettonTransaction(
  wallet: any, // 你的钱包实例
  jettonWalletAddress: string, // 发送者的 Jetton 钱包地址
  recipientAddress: string, // 接收者地址
  privateKey: Uint8Array, // 你的私钥
) {
  try {
    // 构造转账消息
    const transferBody = beginCell()
      .storeUint(JETTON_TRANSFER_OPCODE, 32) // 操作码
      .storeUint(0, 64) // query_id
      .storeCoins(JETTON_AMOUNT) // Jetton 数量
      .storeAddress(recipientAddress as any)
      .storeAddress(recipientAddress as any) 
      .storeBit(0) // 无自定义 payload
      .storeCoins(FORWARD_TON_AMOUNT) // 附带 TON 数量用于通知
      .storeBit(1) // 表示有 forward_payload
      .storeRef(beginCell().storeUint(1, 256).endCell()) // 添加 forward_payload 作为引用
      .endCell();

    // 创建交易
    const transaction = {
      to: new TonWeb.Address(jettonWalletAddress),
      value: TON_AMOUNT,
      data: transferBody,
      dataType: 'boc'
    };

    // 签名并发送
    const sendResult = await wallet.methods
      .transfer({
        secretKey: privateKey,
        toAddress: transaction.to,
        amount: transaction.value,
        seqno: await wallet.methods.seqno().call(),
        payload: transaction.data,
        sendMode: 3 // 支付 Gas 并忽略错误
      })
      .send();

    console.log('交易发送成功:', sendResult);
    return sendResult;
  } catch (error) {
    console.error('发送 Jetton 交易失败:', error);
    throw error;
  }
}

// 创建 forward_payload 示例（例如一个简单的文本消息）
function createForwardPayload(message: string): Cell {
  return beginCell()
    .storeUint(0, 32) // 通常以 0 开头表示文本数据
    .storeStringTail(message) // 存储文本内容
    .endCell();
}

// 使用示例
async function main() {
  // 假设你已经有钱包实例和私钥
  const mnemonic = 'crunch blame street donor slight cousin bleak bunker festival own elite spend picnic rhythm oxygen used horse lecture shadow earth bench common session athlete'.split(' ');
  const keyPair = await TonWebMnemonic.mnemonicToKeyPair(mnemonic); 
  const wallet = tonweb.wallet.create({ publicKey: keyPair.publicKey });

  const jettonWalletAddress = 'kQCo3keh-FK5PrOEi0jTye-y7K0DjYsWr9aw6fwz9zFk-srT'; // 你的 Jetton 钱包地址
  const RECIPIENT_CONTRACT_ADDRESS = 'kQCLOeFqL88m9Dq8sb5HAKJVlybCBn8vU0GF0-rFArD5ymQa'; // 接收者地址

  // 创建 forward_payload
//   const forwardPayload = createForwardPayload('Hello, this is a Jetton transfer!');

  await sendJettonTransaction(
    wallet,
    jettonWalletAddress,
    RECIPIENT_CONTRACT_ADDRESS,
    keyPair.secretKey
  );
}

main().catch(console.error);