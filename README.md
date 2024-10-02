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
Currently deployed on `Testnet`.

Address:
- Testnet: `0x61f5b2922640ee625c6ef99c5a3713820941874e96be6b1215ee80e8a59e2cc1`

### Log:
#### Testnet
```
Transaction submitted: https://explorer.aptoslabs.com/txn/0x6df4bbf32e70cb8471a41e578e4b2d75c2114cddd8a9483a80a28508d120f61a?network=testnet
Code was successfully deployed to object address {}. 0x61f5b2922640ee625c6ef99c5a3713820941874e96be6b1215ee80e8a59e2cc1
{
  "Result": "Success"
}

```
