// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {AuthorizationMessage} from "../../../src/authorization/AuthorizationMessage.sol";

contract AuthorizationMessageHarness {
    function encode(AuthorizationMessage.Envelope calldata envelope)
        external
        pure
        returns (string memory)
    {
        return AuthorizationMessage.encode(envelope);
    }

    function framed(AuthorizationMessage.Envelope calldata envelope)
        external
        pure
        returns (bytes memory)
    {
        return AuthorizationMessage.framed(envelope);
    }

    function authorizationId(AuthorizationMessage.Envelope calldata envelope)
        external
        pure
        returns (bytes32)
    {
        return AuthorizationMessage.authorizationId(envelope);
    }
}
