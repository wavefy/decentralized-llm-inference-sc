# Decentralized LLM Inferencing SC PoC

A Proof of Concept Smartcontract on the Aptos Blockchain for the Decentralized LLM Inferencing Project.

## Prerequisites
https://github.com/wavefy/decentralized-llm-inference-runner

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
- The individual servers, after completing the generation can now claim from the Session `claim_tokens`, with their generated token count in one the parameters.

## Existing problems
Due to this being purely a PoC to showcase the main function, the following problems are currently not dealt with:
- Coin Transaction / Top-up Balance
- Reentrancy Attacks
- Server can forge their own false tickets to claim more than its reward.
- User can forge their own false token_count.

## Deploy information
Currently deployed on `devnet`.

Address:
- Devnet: `0xdcec456d7101b016c09f4f49dd6e642e68c8d04ca028282df74abe37d2417fc8`
- Testnet: `0x9123e2561d81ba5f77473b8dc664fa75179c841061d12264508894610b9d0b7a`

### Log:
#### Devnet
```
Transaction submitted: https://explorer.aptoslabs.com/txn/0xc5cb87df1a05890beb4b2c963ac0fcb51ed19c10647973d941fe7ff086a51a0e?network=devnet
{
  "Result": {
    "transaction_hash": "0xc5cb87df1a05890beb4b2c963ac0fcb51ed19c10647973d941fe7ff086a51a0e",
    "gas_used": 2915,
    "gas_unit_price": 100,
    "sender": "dcec456d7101b016c09f4f49dd6e642e68c8d04ca028282df74abe37d2417fc8",
    "sequence_number": 0,
    "success": true,
    "timestamp_us": 1726473751042814,
    "version": 67435255,
    "vm_status": "Executed successfully"
  }
}
```
#### Testnet
```
Transaction submitted: https://explorer.aptoslabs.com/txn/0xe686cff96d2f29bc33241d961573328ac545aca8dbf9b1410fa4323730325689?network=testnet
{
  "Result": {
    "transaction_hash": "0xe686cff96d2f29bc33241d961573328ac545aca8dbf9b1410fa4323730325689",
    "gas_used": 2916,
    "gas_unit_price": 100,
    "sender": "9123e2561d81ba5f77473b8dc664fa75179c841061d12264508894610b9d0b7a",
    "sequence_number": 0,
    "success": true,
    "timestamp_us": 1726645043478338,
    "version": 6002973433,
    "vm_status": "Executed successfully"
  }
}

```
