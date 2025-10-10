import {
    FetchAddressTransactionsArgs,
    FetchAddressTransactionsResponse,
    Transaction,
    TransactionEvent
} from "./types"

export async function fetchAddressTransactions({
  address,
  offset = 0,
}: FetchAddressTransactionsArgs): Promise<FetchAddressTransactionsResponse> {
  // send request to Hiro explore url and fetch response
  const url = `https://api.hiro.so/extended/v2/addresses/${address}/transactions?limit=20&offset=${offset}`;
  const response = await fetch(url);

  // handle error from fetching transaction
  if (!response.ok) {
    throw new Error("Failed to fetch address transactions");
  }

  // parse api response; extract and return data
  const data = await response.json();
  return data as FetchAddressTransactionsResponse;
}