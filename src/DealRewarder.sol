// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { MarketAPI } from "../lib/filecoin-solidity/contracts/v0.8/MarketAPI.sol";
import { CommonTypes } from "../lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import { MarketTypes } from "../lib/filecoin-solidity/contracts/v0.8/types/MarketTypes.sol";
import { Actor } from "../lib/filecoin-solidity/contracts/v0.8/utils/Actor.sol";
import { Misc } from "../lib/filecoin-solidity/contracts/v0.8/utils/Misc.sol";

contract DealRewarder {
    mapping(bytes => bool) public cidSet;
    mapping(bytes => uint) public cidSizes;
    mapping(bytes => mapping(uint64 => bool)) public cidProviders;

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function fund() public payable {}

    function addCID(bytes calldata cidraw, uint size) public {
       require(msg.sender == owner);
       cidSet[cidraw] = true;
       cidSizes[cidraw] = size;
    }

    function policyOK(bytes memory cidraw, uint64 provider) internal view returns (bool) {
        bool alreadyStoring = cidProviders[cidraw][provider];
        return !alreadyStoring;
    }

    function authorizeData(bytes memory cidraw, uint64 provider, uint size) public {
        require(cidSet[cidraw], "cid must be added before authorizing");
        require(cidSizes[cidraw] == size, "data size must match expected");
        require(policyOK(cidraw, provider), "deal failed policy check: has provider already claimed this cid?");

        cidProviders[cidraw][provider] = true;
    }

    function claim_bounty(uint64 deal_id) public {
        MarketTypes.GetDealDataCommitmentReturn memory commitmentRet = MarketAPI.getDealDataCommitment(MarketTypes.GetDealDataCommitmentParams({id: deal_id}));
        MarketTypes.GetDealProviderReturn memory providerRet = MarketAPI.getDealProvider(MarketTypes.GetDealProviderParams({id: deal_id}));

        // authorize data 
        authorizeData(commitmentRet.data, providerRet.provider, commitmentRet.size);

        // get deal client
        MarketTypes.GetDealClientReturn memory clientRet = MarketAPI.getDealClient(MarketTypes.GetDealClientParams({id: deal_id}));

        // send reward to client 
        send(clientRet.client);
    }

    function concat(bytes32 b1, bytes32 b2) pure external returns (bytes memory)
    {
        bytes memory result = new bytes(64);
        assembly {
            mstore(add(result, 32), b1)
            mstore(add(result, 64), b2)
        }
        return result;
}

    function toBytes64(uint64 x) internal pure returns (bytes memory b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }

    // send 1 FIL to the filecoin actor at actor_id
    function send(uint64 actor_id) public payable {
        uint METHOD_SEND = 0;
        bytes memory emptyParams = "";
        delete emptyParams;
        bytes memory sendAddr = hex"0001";

        uint oneFIL = 10000;
        Actor.call_inner(METHOD_SEND, sendAddr, emptyParams, Misc.NONE_CODEC, oneFIL);

        // handle ethereum transfers too?
    }


    function slice_uint8(bytes memory bs, uint start) pure internal returns (uint8) {
        require(bs.length >= start + 1, "slicing out of range");
        uint8 x;
        assembly {
            x := mload(add(bs, add(0x01, start)))
        }
        return x;
    }

/*
func PutUvarint(buf []byte, x uint64) int {
	i := 0
	for x >= 0x80 {
		buf[i] = byte(x) | 0x80
		x >>= 7
		i++
	}
	buf[i] = byte(x)
	return i + 1
}
*/

// actor id => valid id address bytes
// make a deal and see if we can actually claim bounty
}

