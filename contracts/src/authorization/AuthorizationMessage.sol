// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

/// @title AuthorizationMessage
/// @notice Canonical Vigiver Authorization v1 message encoding.
/// @dev Encoding does not establish operation validity or signing authority.
/// @custom:security-contact See SECURITY.md in the repository root.
library AuthorizationMessage {
    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    struct Envelope {
        uint256 chainId;
        address controller;
        address authority;
        address executor;
        address target;
        uint8 action;
        uint256 argument;
        uint256 value;
        bytes32 expectedState;
        bytes32 keyHash;
        uint256 policyEpoch;
        uint256 nonce;
        uint64 validAfter;
        uint64 validBefore;
        bytes32 evidenceHash;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string internal constant DOMAIN = "vigiver-authorization-v1";

    string internal constant QORESIGN_PREFIX = "qorechain-msg-v1|qorechain-diana|";

    bytes10 private constant DECIMAL_DIGITS = "0123456789";

    bytes16 private constant HEX_DIGITS = "0123456789abcdef";

    /*//////////////////////////////////////////////////////////////
                         CANONICAL AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Encodes the exact wallet-facing authorization message.
    /// @param e The typed authorization envelope.
    /// @return The deterministic ASCII message without a final newline.
    function encode(Envelope memory e) internal pure returns (string memory) {
        string memory identity = string.concat(
            DOMAIN,
            "\nchainId=",
            _decimal(e.chainId),
            "\ncontroller=",
            _hex(abi.encodePacked(e.controller)),
            "\nauthority=",
            _hex(abi.encodePacked(e.authority)),
            "\nexecutor=",
            _hex(abi.encodePacked(e.executor))
        );

        string memory operation = string.concat(
            "\ntarget=",
            _hex(abi.encodePacked(e.target)),
            "\naction=",
            _decimal(e.action),
            "\nargument=",
            _decimal(e.argument),
            "\nvalue=",
            _decimal(e.value),
            "\nexpectedState=",
            _hex(abi.encodePacked(e.expectedState))
        );

        string memory policy = string.concat(
            "\nkeyHash=",
            _hex(abi.encodePacked(e.keyHash)),
            "\npolicyEpoch=",
            _decimal(e.policyEpoch),
            "\nnonce=",
            _decimal(e.nonce)
        );

        string memory validity = string.concat(
            "\nvalidAfter=",
            _decimal(e.validAfter),
            "\nvalidBefore=",
            _decimal(e.validBefore),
            "\nevidenceHash=",
            _hex(abi.encodePacked(e.evidenceHash))
        );

        return string.concat(identity, operation, policy, validity);
    }

    /// @notice Reconstructs the exact ML-DSA-87 signing input for Diana.
    /// @param envelope The typed authorization envelope.
    function framed(Envelope memory envelope) internal pure returns (bytes memory) {
        return bytes.concat(bytes(QORESIGN_PREFIX), bytes(encode(envelope)));
    }

    /// @notice Identifies the exact authorization signing input.
    /// @param envelope The typed authorization envelope.
    function authorizationId(Envelope memory envelope) internal pure returns (bytes32) {
        return sha256(framed(envelope));
    }

    /*//////////////////////////////////////////////////////////////
                          CANONICAL PRIMITIVES
    //////////////////////////////////////////////////////////////*/

    function _decimal(uint256 value) private pure returns (string memory) {
        uint256 digits = 1;
        uint256 remaining = value;

        while (remaining >= 10) {
            remaining /= 10;
            digits++;
        }

        bytes memory output = new bytes(digits);

        while (digits > 0) {
            digits--;
            output[digits] = DECIMAL_DIGITS[value % 10];
            value /= 10;
        }

        return string(output);
    }

    function _hex(bytes memory data) private pure returns (string memory) {
        bytes memory output = new bytes(2 + data.length * 2);

        output[0] = "0";
        output[1] = "x";

        for (uint256 i = 0; i < data.length; i++) {
            uint256 value = uint8(data[i]);
            uint256 position = 2 + i * 2;

            output[position] = HEX_DIGITS[value / 16];
            output[position + 1] = HEX_DIGITS[value % 16];
        }

        return string(output);
    }
}
