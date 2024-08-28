# Decentralized LLM Inferencing SC PoC

A Proof of concept Smartcontract on the Aptos Blockchain for the Decentralized LLM Inferencing Project.

## Actors
- User: The one initialized the server chain
- Server

## Concept
For every conversation there exists a Session on the contract.
Each session will contain information about:
- The price per tokens generated
- The addresses for each of the server in the selected servers chain
- The owner of the session
- The maximum number of tokens: This will act as a way for the user to topup their balance before requesting for action
- The current token count: an indication of how many of the output token that the user have received from the server chain multiplied by the number of servers in the server chain.

The session can only be claimed from its topped-up balance when:
- The user submit a completion notice by calling `update_token_count`
- The individual servers, after completing the generation can now claim from the Session `claim_tokens`

## Existing problems
Due to this being purely a PoC to showcase the main function, the following problems are currently not dealt with:
- Coin Transaction / Top-up Balance
- Reentrancy Attacks
- Server can forge their own false tickets to claim more than its reward.
- User can forge their own false token_count.

## Deploy information
Currently deployed on `devnet`.

Address: `0xdaa36db121c34bb7aa2b095b4c1d7938e44cd0863a354ed0c8f9b42ee270de66`

### Log:
```
Transaction submitted: https://explorer.aptoslabs.com/txn/0xb5042aa58ad2f547c8650418c9d9d3cac4cd7086e8f78bd14a97a4eacdd52daa?network=devnet
{
  "Result": {
    "transaction_hash": "0xb5042aa58ad2f547c8650418c9d9d3cac4cd7086e8f78bd14a97a4eacdd52daa",
    "gas_used": 2805,
    "gas_unit_price": 100,
    "sender": "daa36db121c34bb7aa2b095b4c1d7938e44cd0863a354ed0c8f9b42ee270de66",
    "sequence_number": 0,
    "success": true,
    "timestamp_us": 1724835494747928,
    "version": 621947,
    "vm_status": "Executed successfully"
  }
}
```