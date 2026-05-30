// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AbstractCallback} from "reactive-lib/base/AbstractCallback.sol";
import {IPayable} from "reactive-lib/interfaces/IPayable.sol";

contract DriftRegistry is AbstractCallback {

    struct ILRecord {
         int16  ilBps;
         uint64 lastUpdated;
    }

    uint64 public constant STALE_AFTER = 5 minutes;
    
    mapping(uint256 => ILRecord) private _records;

    event ILUpdated(
        uint256 indexed tokenId,
        int16 ilBps,
        uint64 timestamp
    );

     error TokenNotRegistered();

    // callbackProxy_ = Reactive's callback proxy address
    // callbackSender_ = DriftReactive contract address
     constructor (
        address payable callbackProxy_,
        address callbackSender_
     ) AbstractCallback(IPayable(callbackProxy_), callbackSender_) {}

    // Called by DriftReactive via Reactive Network callback
    // First arg is always the ReactVM address injected by Reactive — must be address
    function updateIL(
        address callbackSender_,
        uint256 tokenId,
        int16 ilBps
    ) external onlyCallbackSender(callbackSender_) {
        _records[tokenId] = ILRecord({
            ilBps:       ilBps,
            lastUpdated: uint64(block.timestamp)
        });
        emit ILUpdated(tokenId, ilBps, uint64(block.timestamp));
    }

    function getIL(uint256 tokenId) external view returns (
        int16  ilBps,
        uint64 lastUpdated,
        bool   isStale
    ) {
        ILRecord memory r = _records[tokenId];
        ilBps       = r.ilBps;
        lastUpdated = r.lastUpdated;
        isStale     = r.lastUpdated == 0
                    || block.timestamp - r.lastUpdated > STALE_AFTER;
    }

    function getILBps(uint256 tokenId) external view returns (int16) {
        if (_records[tokenId].lastUpdated == 0) revert TokenNotRegistered();
        return _records[tokenId].ilBps;
    }
}