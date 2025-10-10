// Input to our function
export interface FetchAddressTransactionsArgs {
  address: string;
  offset?: number;
}

// Output from our function
export interface FetchAddressTransactionsResponse {
  limit: number;
  offset: number;
  total: number;
  results: Array<{
    tx: Transaction;
    stx_sent: string;
    stx_received: string;
    events: {
      stx: TransactionEvent;
      ft: TransactionEvent;
      nft: TransactionEvent;
    };
  }>;
}

// Intermediary types of transactions we get from Hiro's APIs
interface BaseTransaction {
  tx_id: string;
  nonce: number;
  sender_address: string;
  block_hash: string;
  parent_block_hash: string;
  block_height: number;
  block_time: number;
  tx_status: string;
  tx_type:
    | "coinbase"
    | "token_transfer"
    | "smart_contract"
    | "contract_call"
    | "poison_microblock";
}

interface CoinbaseTransaction extends BaseTransaction {
  tx_type: "coinbase";
}

interface TokenTransferTransaction extends BaseTransaction {
  tx_type: "token_transfer";
  token_transfer: {
    recipient_address: string;
    amount: string;
  };
}

interface SmartContractTransaction extends BaseTransaction {
  tx_type: "smart_contract";
  smart_contract: {
    clarity_version: number;
    contract_id: string;
  };
}

interface ContractCallTransaction extends BaseTransaction {
  tx_type: "contract_call";
  contract_call: {
    contract_id: string;
    function_name: string;
  };
}

interface PoisonMicroblockTransaction extends BaseTransaction {
  tx_type: "poison_microblock";
}

export type Transaction =
  | CoinbaseTransaction
  | TokenTransferTransaction
  | SmartContractTransaction
  | ContractCallTransaction
  | PoisonMicroblockTransaction;

export interface TransactionEvent {
  transfer: number;
  mint: number;
  burn: number;
}