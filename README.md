# Deal Bounty Contract
**A FVM compatible deal bounty contract example that empowers Filecoin Data DAOs uses cases.**

This repo contains 
1. [A solidity contract template]() that lists data bounties to claim, and pays out the bounty upon the deal proven to be activated on Filecoin.
2. [A tiny mock market]() contract for prototyping against a realistic filecoin market
3. [Low level solidity CBOR parsing functions](https://github.com/lotus-web3/client-contract/blob/main/src/CBORParse.sol#L129) of general use reading filecoin native data
4. A home for the contracts you invent on top of these 

### Install

To build and test you will need to install [foundry](https://github.com/foundry-rs/foundry/blob/master/README.md) which depends on `cargo`.  After installing foundry simple run

```sh
make build
```

to compile the contracts.


### Build

If you build an extension to this MVP contract this repo hopes to be a good home for it.  Follow the [contribution guidelines](https://github.com/lotus-web3/client-contract/blob/main/CONTRIBUTING.md) to add your extended contracts back here where they can be shared with other developers.


## Core Idea

A simple deal bounty contract consists a list of the data CIDs that it incentives to store on Filecoin. Once a storage deals is made for the listed data, the data bounty hunter can claims the data bounty by providing the deal ID. The contract will check with the Filecoin storage market to confirm whether the supplied deal ID is activated and stores the claimed data. Once validated, the deal bounty contract will pay the bounty hunter out. 

![dealmaking](/img/dealmaking.png)
![addbounty](/img/addbounty.png)
![claim](/img/claimdatabounty.png)


### Deal Bounty Contract Modular Breakdown

The deal bounty contract consists of three conceptual building blocks
<TODO>

### Example variants in terms of building blocks
* A simple data DAO can be implemented with a client that adds the bounties through a voting mechanism
* Perpetual storage contracts can by implemented with clients that funds deals with defi mechanisms and recycle cids from expiring deals into their authorization sets
* Trustless third party data funding can be implemented with 1) public ability to list the bounty 2) a funding mechanism that associates payments with particular cids 


### Deal Making on Filecoin

There are many ways you can store data on Filecoin, you can find more details [here](https://dataonboarding.filecoin.io). To better design a DataDao or a data bounty operation, you'd benefit a lot from understanding the data onboarding flow with storage providers, see the tutorial [here](https://docs.filecoin.io/get-started/store-and-retrieve/introduction/) if you haven't already!

## Contact us
You can find us easily at the Filecoin Slack workspace(filecoin.io/slack) - [#fil-lotus-dev](https://filecoinproject.slack.com/archives/CP50PPW2X)

