# Decentralized LLM Inferencing SC PoC

A Proof of Concept Smartcontract on the Aptos Blockchain for the Decentralized LLM Inferencing Project.

## Prerequisites
https://github.com/wavefy/decentralized-llm-inference-runner

## Actors
- User: The one initialized the server chain
- Server

## Concept
For every Chat there exists a Session on the contract.
Each session will contain information about:
- The price per tokens generated
- The addresses for each of the server in the selected servers chain
- The owner of the session
- The maximum number of tokens: This will act as a way for the user to topup their balance before requesting for action
- The addresses participated in the session.
- The layers of each of the addresses.

After each session, the participated server can claim their reward by submiting a signed ticket to the contract.

## Deploy information
Currently deployed on `Testnet`.

Address:
- Testnet: `0xf4289dca4fe79c4e61fe1255d7f47556c38f512b5cf9ddf727f0e44a5c6a6b00`

### Log:
#### Testnet
```
Transaction submitted: https://explorer.aptoslabs.com/txn/0x95b396b11467b094df2a7f4f10a97ed3a7937f93b61fbf43e8397265d8215345?network=testnet
Code was successfully deployed to object address 0xf4289dca4fe79c4e61fe1255d7f47556c38f512b5cf9ddf727f0e44a5c6a6b00
{
  "Result": "Success"
}
```
