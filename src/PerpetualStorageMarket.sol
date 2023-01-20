// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

///////////////////////////////////////////////////////////
// IMPORTS
//
// These Filecoin APIs are used to determine proper deal state
// to ensure that incentives can be properly paid out.
import { MarketAPI, MarketAPIOld } from "../lib/filecoin-solidity/contracts/v0.8/MarketAPI.sol";
import { MarketTypes } from "../lib/filecoin-solidity/contracts/v0.8/types/MarketTypes.sol";
import { HyperActor } from "../lib/filecoin-solidity/contracts/v0.8/utils/Actor.sol";
import { Misc } from "../lib/filecoin-solidity/contracts/v0.8/utils/Misc.sol";
///////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////
// PerpetualStorageMarket
//
// This contract acts as an on-chain marketplace for clients
// to create incentive opportunities for storage deals now,
// and in the future.
//
// It also facilitates the reward for SPs who fill the deals
// and claims the incentive. The incentive structure can vary,
// but this use case requires the deal be made after a particular
// block time for a specific period.
//
// For this proof of concept, the incentive is a fund that pays
// bounties for the successful storage of a CID over a period of time
// on any one provider. Only one provider can claim the incentive to
// store during an "incentive duration," but new incentives can
// continually claimed after the previous incentive duration expires.
// The incentive owner can manage the funds to extend or terminate
// the incentive for perpetual storage.
//
// TODO: I'm currently incorrectly using block.number because I cannot find
//       a clean way to get the current filecoin epoch in the form of a int64.
//       I think its exported from the built-in runtime actor (curr_epoch()),
//       but doesn't seem to be cleanly exposed in Zondax filecoin-solidity through
//       the hyper actor.
///////////////////////////////////////////////////////////
contract PerpetualStorageMarket {
    ///////////////////////////////////////////////////////
    // Events
    ///////////////////////////////////////////////////////

    /**
     * incentiveRegistered
     *
     * This event fires when an incentive is successfully
     * registered.
     *
     * @param operator      the message sender that registered the incentive and paid the bounty
     * @param incentiveId   the resulting ID of the registered incentive.
     * @param cid           the CID that the operator wants to incentivize perpetual storage for
     * @param cidSize       the size of the CID
     * @param incentive     the amount of FIL awarded to qualifying deals
     * @param claimInterval the number of epochs signifying how long a claim lasts before expiry
     * @param filFundAmount the amount of FIL that was added to the perpetual incentive fund
     */
    event incentiveRegistered(address operator, bytes32 incentiveId, bytes cid, uint256 cidSize,
        uint256 incentive, uint256 claimInterval, uint256 filFundAmount);

    /**
     * incentiveFunded
     *
     * This event fires when an incentive has its fund
     * added to.
     *
     * @param operator    the message sender that added FIL to the fund
     * @param incentiveId the resulting ID of the registered incentive
     * @param amount      the amount added to the fund
     * @param total       the final total amount in the fund after the operation
     */
    event incentiveFunded(address operator, bytes32 incentiveId, uint256 amount, uint256 total);

    /**
     * incentiveClaimed
     *
     * This event ires when an incentive is claimed.
     *
     * @param operator    the message sender that added FIL to the fund
     * @param incentiveId the resulting ID of the registered incentive
     * @param clientId    the deal client who is rewarded for making the deal.
     * @param dealId      the deal id that was used to claim the incentive
     * @param claimExpiry the epoch where this claim will expire
     */
    event incentiveClaimed(address operator, bytes32 incentiveId, uint64 clientId, 
        uint64 dealId, uint256 claimExpiry);

    ///////////////////////////////////////////////////////
    // Storage
    ///////////////////////////////////////////////////////
    // The Incentive models the data that needs to be stored,
    // as well as the incentive information attached to it.
    struct Incentive {
        // incentive identity information
        bool    isValid;    // used to guard against default values
        bytes32 id;         // incentives will have unique IDs
       
        // what is the data we want to store? 
        bytes   cid;        // the owner is incentivizing a particular CID
        uint256 cidSize;    // the size of the CID

        // who is incentivizing the deal, and how? 
        address owner;         // the owner of the incentive is a particular addresis
        uint256 incentive;     // FIL payout for meeting terms 
        uint256 claimInterval;   // the length of the claim period in epochs 

        // treasury 
        uint256 filFundAmount;
    }

    // The Claim models an SP/hunter's commitment to
    // storing the data, and the associated state.
    struct Claim {
        bool isValid;             // used to guard against default values
        bytes32 incentiveId;      // every claim is for a specific incentive
        
        address hunter;           // the owner of the claim
        uint64  clientId;         // the client actor that was rewarded
        uint64  dealId;           // the deal ID that satisifies the incentive
        uint256 claimEpochExpiry; // epoch where the claim will expire
    }

    // The registry of all the incentives posted
    // to the marketplace
    Incentive[] public incentiveRegistry;
    uint256 public incentiveCount;
    mapping(bytes32 => uint256) private incentiveIndex;

    // Indexing that enables finding incentives
    // both by owner address as well as CID.
    mapping(address => bytes32[]) private ownerIncentives;
    mapping(bytes => bytes32[]) private cidIncentives;
    
    // The registry of all the claims posted
    // to the marketplace for incentives.
    Claim[] public claimRegistry;
    uint256 public claimCount;

    // Indexing that enables finding claims both
    // by incentive and by the hunter/SP. 
    mapping(bytes32 => uint256[]) private incentiveClaims;
    mapping(uint64  => uint256[]) private dealClaims;

    // Actor Constants
    uint64 constant DEFAULT_FLAG = 0x00000000;
    uint64 constant METHOD_SEND = 0;

    ///////////////////////////////////////////////////////
    // constructor
    //
    // This contract doesn't need any initialization parameters
    // or contract ownership to function.
    ///////////////////////////////////////////////////////
    constructor() {}

    ///////////////////////////////////////////////////////
    // INCENTIVE MANAGEMENT
    ///////////////////////////////////////////////////////
    
    /**
     * createIncentive
     *
     * This method will create and fund an incentive to store
     * a specific CID with the funds provided.
     *
     * @param cid        the CID to incentivize storage of
     * @param cidSize    the size of the CID to store
     * @param incentive  the amount of FIL to reward for a qualifying deal
     * @param interval   the number of epochs a successful claim is for
     * @return the unique incentive ID.
     */
    function createIncentive(bytes memory cid, uint256 cidSize, uint256 incentive, uint256 interval) payable external returns (bytes32) {
        // create the incentive ID, based on the material information
        bytes32 incentiveId = keccak256(abi.encode(msg.sender, cid, incentive, interval));

        // make sure that incentive doesn't already exist
        require(!incentiveRegistry[incentiveIndex[incentiveId]].isValid, 'DUPLICATE_INCENTIVE');

        // double check the sanity of some of the inputs
        require(cidSize > 0, 'ZERO_CID_SIZE');
        require(incentive > 0, 'ZERO_INCENTIVE');
        require(interval > 0, 'ZERO_CLAIM_INTERVAL');

        // generate the incentive
        Incentive storage i = incentiveRegistry[incentiveCount];
        i.isValid = true;
        i.id = incentiveId;
        i.cid = cid;
        i.cidSize = cidSize;
        i.owner = msg.sender;
        i.incentive = incentive;
        i.claimInterval = interval;
        i.filFundAmount = msg.value;
    
        // build the index
        incentiveIndex[i.id] = incentiveCount;
        ownerIncentives[i.owner].push(i.id); 
        cidIncentives[i.cid].push(i.id);
        incentiveCount++;
    
        // emit an event for clarity and provenance
        emit incentiveRegistered(i.owner, i.id, i.cid, i.cidSize,
            i.incentive, i.claimInterval, i.filFundAmount);

        return i.id;
    }

    /**
     * fundIncentive
     *
     * Incentive owners will call this to pay more into their
     * fund.
     *
     * @param incentiveId the ID of the incentive they want to extend
     * @return the full incentive treasury amount
     */
    function fundIncentive(bytes32 incentiveId) payable external returns(uint256) {
        // The caller should be sending funds into the contract
        require(msg.value > 0, 'ZERO_FIL_ADDED');

        // try to look up the incentive ID
        Incentive storage i = incentiveRegistry[incentiveIndex[incentiveId]];
        require(i.isValid, 'INVALID_INCENTIVE_ID');

        // note: we are skipping checking that the message
        // sender is the owner to enable anyone to contribute

        // register the additional amount
        i.filFundAmount += msg.value;

        emit incentiveFunded(msg.sender, incentiveId, msg.value, i.filFundAmount);

        return i.filFundAmount;
    }

    /**
     * getIncentivesByOwner
     *
     * Get a list of incentiveIDs created by a specific address.
     *
     * @param owner address of the owner of incentives.
     * @return an array of incentiveIDs owned by that address
     */
    function getIncentivesByOwner(address owner) public view returns(bytes32[] memory) {
        return ownerIncentives[owner];
    }

    /**
     * getIncentivesByCID
     *
     * Important pieces of data could have multiple incentives
     * attached attached to it. Return a list of all active incentives
     * for a given piece of data (CID).
     *
     * @param cid the CID data you want incentives for 
     * @return an array of incentive IDs 
     */
    function getIncentivesByCID(bytes memory cid) public view returns(bytes32[] memory) {
        return cidIncentives[cid];
    }

    /**
     * getIncentive
     *
     * For a given incentive ID, return the serialized struct.
     *
     * @param incentiveId the id of the incentive
     * @return the serialized Incentive structure.
     */
    function getIncentive(bytes32 incentiveId) public view returns (Incentive memory) {
        return incentiveRegistry[incentiveIndex[incentiveId]];
    }
    
    ///////////////////////////////////////////////////////
    // CLAIMS MANAGEMENT 
    ///////////////////////////////////////////////////////
   
    /**
     * claimIncentive
     *
     * Agents will call this on behalf of the storage provider
     * to claim an incentive.
     *
     * This method will validate that:
     *      - the incentive is as valid one
     *      - there is enough funds in the incentive for a payout
     *      - there is not an active claim on the incentive
     *      - the provided deal is active
     *      - the provided deal contains the CID
     *      - the provided deal meets the incentive 
     *        deal length requirements
     *
     * The storage provider of a valid deal will be sent
     * the incentive and a claim raised.
     *
     * @param incentiveId the unique ID of the incentive to claim against
     * @param dealId      the filecoin deal ID to register a claim with
     * @return if successful, will return the claim ID.
     */
    function claimIncentive(bytes32 incentiveId, uint64 dealId) payable external returns (uint256) {
        // grab the incentive and ensure it is valid
        Incentive storage i = incentiveRegistry[incentiveIndex[incentiveId]];
        require(i.isValid, 'INVALID_INCENTIVE_ID');

        // ensure that there is enough funds in the incentive for a payout
        require(i.filFundAmount > i.incentive, 'INSUFFICIENT_INCENTIVE_FUNDS');

        // ensure that there is no valid or active claim on the incentive
        uint256[] storage claimIds = incentiveClaims[incentiveId]; 
        if (claimIds.length > 0) {
            Claim storage latestClaim = claimRegistry[claimIds[claimIds.length-1]];
            assert(latestClaim.isValid); // only valid claims should be here

            // ensure that the claim has properly expired
            require(latestClaim.claimEpochExpiry <= block.number, 'ACTIVE_CLAIM');
        }

        // get the deal metadata, and make sure it's the proper CID, and size.
        MarketTypes.GetDealDataCommitmentReturn memory commitmentRet = 
            MarketAPI.getDealDataCommitment(MarketTypes.GetDealDataCommitmentParams({id: dealId}));
        require(keccak256(abi.encode(commitmentRet.data)) == keccak256(abi.encode(i.cid)), 'DEAL_CID_MISMATCH');
        require(commitmentRet.size == i.cidSize, 'DEAL_SIZE_MISMATCH');

        // make sure the deal is active
        MarketTypes.GetDealActivationReturn memory dealActivation = 
            MarketAPIOld.getDealActivation(MarketTypes.GetDealActivationParams({id: dealId}));
        require(dealActivation.activated > 0, 'DEAL_NOT_ACTIVATED'); // must have activation time
        require(dealActivation.terminated < 0, 'DEAL_TERMINATED');   // need this to be -1

        // ensure the deal will meet the claim interval period
        MarketTypes.GetDealTermReturn memory dealTerm = 
            MarketAPIOld.getDealTerm(MarketTypes.GetDealTermParams({id: dealId}));
        // note: there looks like there's a disrepency between built-in
        //       actors and the zondax MarketOld API, both in what the structure means/is,
        //       as well as the formats between that and the epoch
        //       https://github.com/filecoin-project/builtin-actors/blob/e5e131803e3e026a919fa34c0015235548b96ba8/actors/market/src/types.rs#L175
        //       https://github.com/Zondax/filecoin-solidity/blob/master/contracts/v0.8/types/MarketTypes.sol#L75
        require(dealTerm.end >= int64(uint64(block.number)) + int64(uint64(i.claimInterval)),
            'INSUFFICIENT_DEAL_LENGTH');

        // grab the client's actor, who will get paid out on the claim.
        // the 'client' in this case is the person who is posting collateral
        // for the deal to the storage provider. In the most basic case,
        // this is ALSO the storage provider but doesn't have to be.
        MarketTypes.GetDealClientReturn memory clientRet = 
            MarketAPI.getDealClient(MarketTypes.GetDealClientParams({id: dealId}));

        // create a claim
        uint256 claimId = claimCount++;
        Claim storage newClaim = claimRegistry[claimId];
        newClaim.isValid = true;
        newClaim.incentiveId = i.id;
        newClaim.hunter = msg.sender;
        newClaim.clientId = clientRet.client;
        newClaim.dealId = dealId;
        newClaim.claimEpochExpiry = block.number + i.claimInterval;

        // index the claim
        incentiveClaims[i.id].push(claimId);
        dealClaims[newClaim.dealId].push(claimId);

        // subtract the funds from the incentive
        i.filFundAmount -= i.incentive;

        // send the claim amount to the deal provider
        // note: can this be done the "solidity" way by
        //       deriving an ethereum address and using send()?
        HyperActor.call_actor_id(METHOD_SEND, i.incentive, DEFAULT_FLAG, Misc.NONE_CODEC, 
            "", clientRet.client);

        // emit event and return the final claim ID
        emit incentiveClaimed(msg.sender, incentiveId, clientRet.client, 
            dealId, newClaim.claimEpochExpiry);

        return claimId;
    }

    /**
     * getIncentiveClaims
     *
     * @param incentiveId the incentive ID you wants the claims for.
     * @return array of claim IDs for that incentive.
     */
    function getIncentiveClaims(bytes32 incentiveId) public view returns (uint256[] memory) {
        return incentiveClaims[incentiveId];
    }

    /**
     * getDealClaims
     *
     * @param dealId the deal ID you want to see the claims for 
     * @return array of claim IDs for that deal.
     */
    function getDealClaims(uint64 dealId) public view returns (uint256[] memory) {
        return dealClaims[dealId];
    }
}
