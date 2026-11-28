// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {Test} from "forge-std/Test.sol";

import {AuthorizationMessage} from "../../../src/authorization/AuthorizationMessage.sol";

import {
    AuthorizationMessageHarness
} from "../../helpers/authorization/AuthorizationMessageHarness.sol";

contract AuthorizationMessageTest is Test {
    string private constant FIXTURE = "test/fixtures/authorization/v1.json";

    string private constant SIGNING_PREFIX = "qorechain-msg-v1|qorechain-diana|";

    AuthorizationMessageHarness private s_encoder;

    function setUp() public {
        s_encoder = new AuthorizationMessageHarness();
    }

    /*//////////////////////////////////////////////////////////////
                           INDEPENDENT VECTORS
    //////////////////////////////////////////////////////////////*/

    function testMatchesIndependentReferenceVectors() public view {
        string memory json = vm.readFile(FIXTURE);

        uint256 count = vm.parseJsonUint(json, ".count");

        assertEq(count, 6);

        for (uint256 i = 0; i < count; i++) {
            string memory path = string.concat(".vectors[", vm.toString(i), "]");

            string memory name = vm.parseJsonString(json, string.concat(path, ".name"));

            AuthorizationMessage.Envelope memory envelope =
                _readEnvelope(json, string.concat(path, ".envelope"));

            assertEq(
                s_encoder.encode(envelope),
                vm.parseJsonString(json, string.concat(path, ".message")),
                name
            );

            assertEq(
                s_encoder.framed(envelope),
                bytes(vm.parseJsonString(json, string.concat(path, ".framedMessage"))),
                name
            );

            assertEq(
                s_encoder.authorizationId(envelope),
                vm.parseJsonBytes32(json, string.concat(path, ".authorizationId")),
                name
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                             FIELD BINDING
    //////////////////////////////////////////////////////////////*/

    function testBindsEveryEnvelopeField() public view {
        AuthorizationMessage.Envelope memory envelope;

        bytes32 original = keccak256(bytes(s_encoder.encode(envelope)));

        for (uint256 field = 0; field < 15; field++) {
            _mutateField(envelope, field);

            assertNotEq(keccak256(bytes(s_encoder.encode(envelope))), original);

            // XOR mutation is reversible.
            _mutateField(envelope, field);

            assertEq(keccak256(bytes(s_encoder.encode(envelope))), original);
        }
    }

    function testFuzzBindsModifiedField(
        AuthorizationMessage.Envelope memory envelope,
        uint8 rawField
    ) public view {
        uint256 field = bound(uint256(rawField), 0, 14);

        bytes32 original = keccak256(bytes(s_encoder.encode(envelope)));

        _mutateField(envelope, field);

        assertNotEq(keccak256(bytes(s_encoder.encode(envelope))), original);
    }

    /*//////////////////////////////////////////////////////////////
                          FRAMING PROPERTIES
    //////////////////////////////////////////////////////////////*/

    function testFuzzPreservesExactSigningDomain(AuthorizationMessage.Envelope memory envelope)
        public
        view
    {
        bytes memory message = bytes(s_encoder.encode(envelope));

        assertGt(message.length, 0);

        assertEq(s_encoder.framed(envelope), bytes.concat(bytes(SIGNING_PREFIX), message));

        assertTrue(message[message.length - 1] != bytes1(0x0a));

        assertEq(s_encoder.authorizationId(envelope), sha256(s_encoder.framed(envelope)));
    }

    /*//////////////////////////////////////////////////////////////
                           FIXTURE DECODING
    //////////////////////////////////////////////////////////////*/

    function _readEnvelope(string memory json, string memory path)
        internal
        pure
        returns (AuthorizationMessage.Envelope memory e)
    {
        e.chainId = _readUint(json, path, "chainId");

        e.controller = vm.parseJsonAddress(json, string.concat(path, ".controller"));

        e.authority = vm.parseJsonAddress(json, string.concat(path, ".authority"));

        e.executor = vm.parseJsonAddress(json, string.concat(path, ".executor"));

        e.target = vm.parseJsonAddress(json, string.concat(path, ".target"));

        uint256 action = _readUint(json, path, "action");
        assertLe(action, type(uint8).max);
        e.action = uint8(action);

        e.argument = _readUint(json, path, "argument");
        e.value = _readUint(json, path, "value");

        e.expectedState = vm.parseJsonBytes32(json, string.concat(path, ".expectedState"));

        e.keyHash = vm.parseJsonBytes32(json, string.concat(path, ".keyHash"));

        e.policyEpoch = _readUint(json, path, "policyEpoch");
        e.nonce = _readUint(json, path, "nonce");

        uint256 validAfter = _readUint(json, path, "validAfter");
        uint256 validBefore = _readUint(json, path, "validBefore");

        assertLe(validAfter, type(uint64).max);
        assertLe(validBefore, type(uint64).max);

        e.validAfter = uint64(validAfter);
        e.validBefore = uint64(validBefore);

        e.evidenceHash = vm.parseJsonBytes32(json, string.concat(path, ".evidenceHash"));
    }

    function _readUint(string memory json, string memory path, string memory field)
        internal
        pure
        returns (uint256)
    {
        return vm.parseUint(vm.parseJsonString(json, string.concat(path, ".", field)));
    }

    function _mutateField(AuthorizationMessage.Envelope memory e, uint256 field) internal pure {
        if (field == 0) e.chainId ^= 1;
        else if (field == 1) e.controller = address(uint160(e.controller) ^ 1);
        else if (field == 2) e.authority = address(uint160(e.authority) ^ 1);
        else if (field == 3) e.executor = address(uint160(e.executor) ^ 1);
        else if (field == 4) e.target = address(uint160(e.target) ^ 1);
        else if (field == 5) e.action ^= 1;
        else if (field == 6) e.argument ^= 1;
        else if (field == 7) e.value ^= 1;
        else if (field == 8) e.expectedState ^= bytes32(uint256(1));
        else if (field == 9) e.keyHash ^= bytes32(uint256(1));
        else if (field == 10) e.policyEpoch ^= 1;
        else if (field == 11) e.nonce ^= 1;
        else if (field == 12) e.validAfter ^= 1;
        else if (field == 13) e.validBefore ^= 1;
        else if (field == 14) e.evidenceHash ^= bytes32(uint256(1));
        else revert("Invalid test field");
    }
}
