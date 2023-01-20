# DataDAO Example - Deal Bounty Contract
**A FVM compatible deal bounty contract example that demonstrates one way of implementing a Data DAO on Filecoin.**

This repo contains a solidity contract template that lists data bounties to claim, and pays out the bounty upon the deal proven to be made with the builtin filecoin builtin market.

### Install

To build and test you will need to install [foundry](https://github.com/foundry-rs/foundry/blob/master/README.md) which depends on `cargo`.  After installing foundry simple run

```sh
make build
```

to compile the contracts.


### Build

If you build an extension to this MVP contract this repo hopes to be a good home for it.  Follow the [contribution guidelines](https://github.com/lotus-web3/client-contract/blob/main/CONTRIBUTING.md) to add your extended contracts back here where they can be shared with other developers.

## Introduction to Filecoin

[Filecoin](https://filecoin.io/) is an open-source cloud storage marketplace, protocol, and incentive layer. It allows a very flexible system for clients (wanting to store data) and Storage Providers (SPs) to negotiate the storage of data between them.

The Filecoin network is a massive decentralised storage network with over 16EB of committed storage capacity across over 4,000 Storage Providers (SPs) worldwide. The Filecoin blockchain is a L1 blockchain that is used to broadcast, negotiate, and store the "storage deals" between clients (entities wanting to store data), and SPs. The actual data storage itself is carried out off-chain for efficiency and scalability.

### The Storage Deal Flow

In this example smart contract, for simplicity, all deal making happens outside of the smart contact. The smart contract itself does not initiate the making of any deals itself, but incentivizes other parties to make those deals and supply the resultant deal ID back to the smart contract to verify.

### Storing Data and Making Deals on Filecoin

There are many ways you can store data on Filecoin, you can find more details [here](https://dataonboarding.filecoin.io). To better design a DataDAO or a data bounty operation, you'd benefit a lot from understanding the data onboarding flow with storage providers, see the tutorial [here](https://docs.filecoin.io/get-started/store-and-retrieve/introduction/) if you haven't already!

## Core Idea

A simple deal bounty contract consists a list of the data CIDs that it incentives to store on Filecoin. Once a storage deals is made for the listed data, the data bounty hunter can claim the data bounty by providing the deal ID. The contract will check with the Filecoin storage market to confirm whether the supplied deal ID is activated and stores the claimed data. Once validated, the deal bounty contract will pay the bounty hunter out. 

<img src="/img/dealmaking.png" width="50%">
<img src="/img/addbounty.png" width="50%">
<img src="/img/claimdatabounty.png" width="50%">


### Deal Bounty Contract Modular Breakdown

The deal bounty contract consists of four conceptual steps:

Step   |   Who   |    What is happening  |   Why 
--- | --- | --- | ---
Deploy | contract owner   | address that deployed contracts is the owner of the contract, and the individual that can call addCID  | create a contract and setting up rules to follow
AddCID | data pinners     | set up data cids that the contract will incentivize in deals      | add request for a deal in the filecoin network, "store data" function
Fund   | contract funders |  add FIL to the contract to later pay out deals        | ensure the deal actually gets stored by providing funds for bounty hunter and (indirect) storage provider
Claim  | bounty hunter    | claim the incentive to complete the cycle                    | pay back the bounty hunter for doing work for the contract

### Example variants in terms of building blocks
* A simple data DAO can be implemented with a client that adds the bounties through a voting mechanism
* Perpetual storage contracts can by implemented with clients that funds deals with defi mechanisms and recycle cids from expiring deals into their authorization sets
* Trustless third party data funding can be implemented with 1) public ability to list the bounty 2) a funding mechanism that associates payments with particular cids 


## Contact us
You can find us easily at the Filecoin Slack workspace(filecoin.io/slack) - [#fil-lotus-dev](https://filecoinproject.slack.com/archives/CP50PPW2X)

