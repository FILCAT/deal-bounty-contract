// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { MarketAPI } from "../lib/filecoin-solidity/contracts/v0.8/MarketAPI.sol";
import { CommonTypes } from "../lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import { MarketTypes } from "../lib/filecoin-solidity/contracts/v0.8/types/MarketTypes.sol";

contract DealRewarder {
    mapping(bytes => bool) public cidSet;
    mapping(bytes => uint) public cidSizes;
    mapping(bytes => mapping(bytes => bool)) public cidProviders;

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function addCID(bytes calldata cidraw, uint size) public {
       require(msg.sender == owner);
       cidSet[cidraw] = true;
       cidSizes[cidraw] = size;
    }

    function policyOK(bytes calldata cidraw, bytes calldata provider) internal view returns (bool) {
        bool alreadyStoring = cidProviders[cidraw][provider];
        return !alreadyStoring;
    }

    function authorizeData(bytes calldata cidraw, bytes calldata provider, uint size) public {
        require(cidSet[cidraw], "cid must be added before authorizing");
        require(cidSizes[cidraw] == size, "data size must match expected");
        require(policyOK(cidraw, provider), "deal failed policy check: has provider already claimed this cid?");

        cidProviders[cidraw][provider] = true;
    }

    function claim_bounty(uint deal_id) public {
        // get deal commitment
        commitmentRet = MarketAPI.getDealDataCommitment(params);

        // get deal provider

        // authorize data 

        // get deal client

        // send reward to client 

    }
}

