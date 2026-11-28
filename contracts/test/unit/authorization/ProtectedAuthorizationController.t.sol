// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {Test} from "forge-std/Test.sol";

import {ProtectedAuthorizationController} from "../../../src/authorization/ProtectedAuthorizationController.sol";

import {AuthorizationMessage} from "../../../src/authorization/AuthorizationMessage.sol";

import {QorePqcKeyRegistry} from "../../../src/cryptography/qorechain/QorePqcKeyRegistry.sol";

import {QorePqcVerifier} from "../../../src/cryptography/qorechain/QorePqcVerifier.sol";

import {
    IQorePqcKeyStatusPrecompile
} from "../../../src/cryptography/qorechain/interfaces/IQorePqcKeyStatusPrecompile.sol";

import {IQorePqcVerifyPrecompile} from "../../../src/cryptography/qorechain/interfaces/IQorePqcVerifyPrecompile.sol";

import {AdversarialProtectedTarget} from "../../helpers/authorization/AdversarialProtectedTarget.sol";

contract ProtectedAuthorizationControllerTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant DIANA_CHAIN_ID = 9800;

    address private constant AUTHORITY = address(0xA11CE);
    address private constant EXECUTOR = address(0xB0B);
    address private constant DEPLOYER = address(0xD3);
    address private constant ATTACKER = address(0xBAD);

    address private constant PQC_VERIFY = address(0x0A01);
    address private constant PQC_KEY_STATUS = address(0x0A02);

    uint64 private constant NOW = 1_800_000_000;

    uint8 private constant SET_PARAMETER = 1;
    uint8 private constant INVALIDATE = 2;
    uint8 private constant SYNC_KEY = 3;
    uint8 private constant REVOKE = 4;

    bytes32 private constant EVIDENCE = bytes32(uint256(123));

    /*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    ProtectedAuthorizationController private s_controller;

    AdversarialProtectedTarget private s_target;

    bytes private s_publicKey;
    bytes private s_signature;

    bytes32 private s_keyHash;

    event AuthorizationExecuted(
        bytes32 indexed authorizationId,
        address indexed authority,
        address indexed executor,
        uint8 action,
        address target,
        uint256 nonce,
        uint256 policyEpoch,
        bytes32 evidenceHash
    );

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.chainId(DIANA_CHAIN_ID);
        vm.warp(NOW);

        s_publicKey = new bytes(2592);
        s_publicKey[0] = 0x01;
        s_publicKey[2591] = 0x02;

        s_signature = new bytes(4627);
        s_signature[0] = 0x03;

        s_keyHash = sha256(s_publicKey);

        _mockKeyStatus(true, 1, s_publicKey, true);

        // No signature is valid unless a test explicitly approves
        // the exact verification calldata.
        vm.mockCall(PQC_VERIFY, abi.encodePacked(IQorePqcVerifyPrecompile.pqcVerify.selector), abi.encode(false));

        s_target = new AdversarialProtectedTarget(10);

        bytes32 targetCodeHash = address(s_target).codehash;

        vm.prank(DEPLOYER);

        s_controller = new ProtectedAuthorizationController(AUTHORITY, address(s_target), targetCodeHash);

        // Separate owner-authorized migration.
        s_target.transferOwnership(address(s_controller));

        vm.deal(EXECUTOR, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                               BOOTSTRAP
    //////////////////////////////////////////////////////////////*/

    function testBootstrapEstablishesExplicitAuthority() public view {
        assertEq(s_controller.i_authority(), AUTHORITY);
        assertEq(s_controller.i_target(), address(s_target));
        assertEq(s_controller.i_targetCodeHash(), address(s_target).codehash);

        assertEq(s_controller.s_admittedKeyHash(), s_keyHash);
        assertEq(s_controller.s_policyEpoch(), 1);
        assertEq(s_controller.s_nextNonce(), 0);

        assertFalse(s_controller.s_revoked());
        assertTrue(s_controller.s_previouslyAdmittedKeys(s_keyHash));

        assertNotEq(s_controller.i_authority(), DEPLOYER);
    }

    function testBootstrapDoesNotTransferTargetOwnership() public {
        AdversarialProtectedTarget target = new AdversarialProtectedTarget(42);

        bytes32 codeHash = address(target).codehash;

        vm.prank(DEPLOYER);

        ProtectedAuthorizationController controller =
            new ProtectedAuthorizationController(AUTHORITY, address(target), codeHash);

        assertEq(target.owner(), address(this));
        assertNotEq(target.owner(), address(controller));
        assertNotEq(target.owner(), DEPLOYER);
    }

    function testBootstrapRejectsWrongNetwork() public {
        vm.chainId(421_614);

        vm.expectRevert(ProtectedAuthorizationController.InvalidNetwork.selector);

        new ProtectedAuthorizationController(AUTHORITY, address(s_target), address(s_target).codehash);
    }

    function testBootstrapRejectsZeroAuthority() public {
        vm.expectRevert(QorePqcKeyRegistry.InvalidAuthority.selector);

        new ProtectedAuthorizationController(address(0), address(s_target), address(s_target).codehash);
    }

    function testBootstrapRejectsUnregisteredAuthority() public {
        _mockKeyStatus(false, 0, new bytes(0), false);

        vm.expectRevert(QorePqcKeyRegistry.KeyNotRegistered.selector);

        new ProtectedAuthorizationController(AUTHORITY, address(s_target), address(s_target).codehash);
    }

    function testBootstrapRejectsAuthorityWithoutPossession() public {
        _mockKeyStatus(true, 1, s_publicKey, false);

        vm.expectRevert(QorePqcKeyRegistry.PossessionNotProven.selector);

        new ProtectedAuthorizationController(AUTHORITY, address(s_target), address(s_target).codehash);
    }

    function testBootstrapRejectsTargetWithoutCode() public {
        vm.expectRevert(ProtectedAuthorizationController.InvalidTarget.selector);

        new ProtectedAuthorizationController(AUTHORITY, ATTACKER, ATTACKER.codehash);
    }

    function testBootstrapRejectsUnexpectedTargetCode() public {
        vm.expectRevert(ProtectedAuthorizationController.TargetCodeMismatch.selector);

        new ProtectedAuthorizationController(AUTHORITY, address(s_target), bytes32(uint256(1)));
    }

    /*//////////////////////////////////////////////////////////////
                          SUCCESSFUL EXECUTION
    //////////////////////////////////////////////////////////////*/

    function testExecutesExactAuthorizedParameterChange() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        bytes32 authorizationId = AuthorizationMessage.authorizationId(e);

        vm.expectEmit(true, true, true, true, address(s_controller));

        emit AuthorizationExecuted(
            authorizationId, AUTHORITY, EXECUTOR, SET_PARAMETER, address(s_target), 0, 1, EVIDENCE
        );

        _submit(e);

        assertEq(s_target.parameter(), 200);
        assertEq(s_target.owner(), address(s_controller));

        assertEq(s_controller.s_nextNonce(), 1);
        assertEq(s_controller.s_policyEpoch(), 1);

        assertEq(s_controller.s_admittedKeyHash(), s_keyHash);
        assertFalse(s_controller.s_revoked());
    }

    function testRejectsSuccessfulAuthorizationReplay() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);
        _submit(e);

        _reject(e, ProtectedAuthorizationController.InvalidNonce.selector);

        assertEq(s_controller.s_nextNonce(), 1);
        assertEq(s_target.parameter(), 200);
    }

    function testRejectsConventionalDeployerWithoutAuthorization() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.executor = DEPLOYER;

        vm.expectRevert(ProtectedAuthorizationController.InvalidSignature.selector);

        vm.prank(DEPLOYER);

        s_controller.execute(e, s_signature);

        _assertInitialState();
    }

    function testRejectsDirectTargetCallByFormerOwner() public {
        vm.expectRevert(AdversarialProtectedTarget.UnauthorizedOwner.selector);

        s_target.setParameter(200);

        _assertInitialState();
    }

    /*//////////////////////////////////////////////////////////////
                           AUTHORIZATION BINDINGS
    //////////////////////////////////////////////////////////////*/

    function testRejectsWrongChain() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.chainId = 421_614;
        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidNetwork.selector);
    }

    function testRejectsChangedExecutionNetwork() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        vm.chainId(421_614);

        _reject(e, ProtectedAuthorizationController.InvalidNetwork.selector);
    }

    function testRejectsWrongController() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.controller = ATTACKER;
        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidController.selector);
    }

    function testRejectsWrongAuthority() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.authority = ATTACKER;
        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidAuthority.selector);
    }

    function testRejectsCopiedAuthorizationFromAnotherExecutor() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        vm.expectRevert(ProtectedAuthorizationController.InvalidExecutor.selector);

        vm.prank(ATTACKER);

        s_controller.execute(e, s_signature);

        _assertInitialState();
    }

    function testRejectsZeroExecutor() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.executor = address(0);
        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidExecutor.selector);
    }

    function testRejectsWrongTarget() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.target = ATTACKER;
        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidOperation.selector);
    }

    function testRejectsUnsupportedAction() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.action = 255;
        _approve(e);

        _reject(e, ProtectedAuthorizationController.UnsupportedAction.selector);
    }

    function testRejectsKeySynchronizationWhileDisabled() public {
        AuthorizationMessage.Envelope memory e = _controlAuthorization(SYNC_KEY);

        _approve(e);

        _reject(e, ProtectedAuthorizationController.UnsupportedAction.selector);
    }

    function testRejectsSignedNonzeroValue() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.value = 1;
        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidValue.selector);
    }

    function testRejectsAttachedNativeValue() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        vm.expectRevert(ProtectedAuthorizationController.InvalidValue.selector);

        vm.prank(EXECUTOR);

        s_controller.execute{value: 1}(e, s_signature);

        assertEq(address(s_controller).balance, 0);

        _assertInitialState();
    }

    function testRejectsMissingEvidenceCommitment() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.evidenceHash = bytes32(0);
        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidOperation.selector);
    }

    function testRejectsFutureNonce() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.nonce = 1;
        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidNonce.selector);
    }

    function testRejectsWrongPolicyEpoch() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.policyEpoch = 2;
        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidEpoch.selector);
    }

    function testRejectsModifiedSignedArgument() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        e.argument = 201;

        _reject(e, ProtectedAuthorizationController.InvalidSignature.selector);

        _assertInitialState();
    }

    function testRejectsModifiedEvidenceAfterSignature() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        e.evidenceHash = bytes32(uint256(456));

        _reject(e, ProtectedAuthorizationController.InvalidSignature.selector);

        _assertInitialState();
    }

    /*//////////////////////////////////////////////////////////////
                            VALIDITY INTERVALS
    //////////////////////////////////////////////////////////////*/

    function testAcceptsInclusiveValidityStart() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        vm.warp(e.validAfter);

        _approve(e);
        _submit(e);

        assertEq(s_controller.s_nextNonce(), 1);
    }

    function testAcceptsLastValidSecond() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        vm.warp(e.validBefore - 1);

        _approve(e);
        _submit(e);

        assertEq(s_controller.s_nextNonce(), 1);
    }

    function testRejectsPrematureAuthorization() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        vm.warp(e.validAfter - 1);

        _approve(e);

        _reject(e, ProtectedAuthorizationController.AuthorizationNotActive.selector);
    }

    function testRejectsExclusiveValidityEnd() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        vm.warp(e.validBefore);

        _approve(e);

        _reject(e, ProtectedAuthorizationController.AuthorizationNotActive.selector);
    }

    function testRejectsEmptyValidityInterval() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.validBefore = e.validAfter;

        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidValidityInterval.selector);
    }

    function testRejectsReversedValidityInterval() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.validBefore = e.validAfter - 1;

        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidValidityInterval.selector);
    }

    function testRejectsValidityLongerThanOneHour() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.validBefore = e.validAfter + 3601;

        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidValidityInterval.selector);
    }

    /*//////////////////////////////////////////////////////////////
                            STATE PRECONDITIONS
    //////////////////////////////////////////////////////////////*/

    function testReportsCanonicalTargetState() public view {
        assertEq(s_controller.targetState(), _targetState());
    }

    function testReportsCanonicalControlState() public view {
        assertEq(s_controller.controlState(), _controlState(1, 0, false));
    }

    function testRejectsStaleTargetParameter() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        s_target.forceParameter(11);

        _reject(e, ProtectedAuthorizationController.ExpectedStateMismatch.selector);

        assertEq(s_target.parameter(), 11);
        assertEq(s_controller.s_nextNonce(), 0);
    }

    function testRejectsLostTargetOwnership() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        s_target.forceOwner(ATTACKER);

        _reject(e, ProtectedAuthorizationController.TargetOwnershipMismatch.selector);

        assertEq(s_controller.s_nextNonce(), 0);
    }

    function testRejectsChangedTargetRuntimeCode() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        vm.etch(address(s_target), hex"00");

        _reject(e, ProtectedAuthorizationController.TargetCodeMismatch.selector);

        assertEq(s_controller.s_nextNonce(), 0);
    }

    function testRejectsIncorrectControlState() public {
        AuthorizationMessage.Envelope memory e = _controlAuthorization(INVALIDATE);

        e.expectedState = bytes32(0);

        _approve(e);

        _reject(e, ProtectedAuthorizationController.ExpectedStateMismatch.selector);

        _assertInitialState();
    }

    /*//////////////////////////////////////////////////////////////
                             CRYPTOGRAPHIC POLICY
    //////////////////////////////////////////////////////////////*/

    function testRejectsUnapprovedSignature() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _reject(e, ProtectedAuthorizationController.InvalidSignature.selector);

        _assertInitialState();
    }

    function testRejectsIncorrectSignatureLength() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        bytes memory shortSignature = new bytes(4626);

        vm.expectRevert(ProtectedAuthorizationController.InvalidSignature.selector);

        vm.prank(EXECUTOR);

        s_controller.execute(e, shortSignature);

        _assertInitialState();
    }

    function testRejectsWrongSignedKeyCommitment() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        e.keyHash = bytes32(uint256(1));

        _approve(e);

        _reject(e, ProtectedAuthorizationController.KeyCommitmentMismatch.selector);
    }

    function testRejectsUnregisteredCurrentAuthority() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        _mockKeyStatus(false, 0, new bytes(0), false);

        _reject(e, QorePqcKeyRegistry.KeyNotRegistered.selector);

        _assertInitialState();
    }

    function testRejectsCurrentKeyWithoutPossession() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        _mockKeyStatus(true, 1, s_publicKey, false);

        _reject(e, QorePqcKeyRegistry.PossessionNotProven.selector);

        _assertInitialState();
    }

    function testDoesNotAutomaticallyAdmitRotatedKey() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        bytes memory replacement = new bytes(2592);

        replacement[0] = 0x99;

        bytes32 replacementHash = sha256(replacement);

        _mockKeyStatus(true, 1, replacement, true);

        bytes memory expectedError =
            abi.encodeWithSelector(QorePqcKeyRegistry.KeyCommitmentMismatch.selector, s_keyHash, replacementHash);

        vm.expectRevert(expectedError);

        vm.prank(EXECUTOR);

        s_controller.execute(e, s_signature);

        assertEq(s_controller.s_admittedKeyHash(), s_keyHash);
        assertFalse(s_controller.s_previouslyAdmittedKeys(replacementHash));

        _assertInitialState();
    }

    function testRejectsMalformedRegistryResponse() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        vm.mockCall(PQC_KEY_STATUS, _registryCalldata(), hex"01");

        _reject(e, QorePqcKeyRegistry.InvalidPqcKeyStatusResponse.selector);

        _assertInitialState();
    }

    function testRejectsEmptyVerificationResponse() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        vm.mockCall(PQC_VERIFY, _verificationCalldata(e), hex"");

        _reject(e, QorePqcVerifier.InvalidPqcResponse.selector);

        _assertInitialState();
    }

    function testRejectsNonCanonicalVerificationResponse() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        vm.mockCall(PQC_VERIFY, _verificationCalldata(e), abi.encode(uint256(2)));

        _reject(e, QorePqcVerifier.InvalidPqcResponse.selector);

        _assertInitialState();
    }

    function testRejectsFailedVerificationCall() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        vm.mockCallRevert(PQC_VERIFY, _verificationCalldata(e), hex"");

        _reject(e, QorePqcVerifier.PqcCallFailed.selector);

        _assertInitialState();
    }

    /*//////////////////////////////////////////////////////////////
                           ATOMIC STATE TRANSITIONS
    //////////////////////////////////////////////////////////////*/

    function testRollsBackNonceWhenTargetReverts() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        s_target.setMode(AdversarialProtectedTarget.Mode.RevertExecution);

        _reject(e, AdversarialProtectedTarget.IntentionalTargetFailure.selector);

        _assertInitialState();

        // A failed attempt did not consume the authorization.
        s_target.setMode(AdversarialProtectedTarget.Mode.Normal);

        _submit(e);

        assertEq(s_target.parameter(), 200);
        assertEq(s_controller.s_nextNonce(), 1);
    }

    function testRollsBackWhenTargetIgnoresParameter() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        s_target.setMode(AdversarialProtectedTarget.Mode.IgnoreParameter);

        _reject(e, ProtectedAuthorizationController.TargetPostconditionFailed.selector);

        _assertInitialState();
    }

    function testRollsBackWhenTargetChangesOwner() public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(200);

        _approve(e);

        s_target.setMode(AdversarialProtectedTarget.Mode.ChangeOwner);

        _reject(e, ProtectedAuthorizationController.TargetOwnershipMismatch.selector);

        _assertInitialState();
    }

    function testRejectsReentrantNextNonceAuthorization() public {
        AuthorizationMessage.Envelope memory outer = _parameterAuthorization(200);

        AuthorizationMessage.Envelope memory inner = _controlAuthorization(INVALIDATE);

        // The inner operation has its own approved signature,
        // the correct executor and the next sequential nonce.
        inner.executor = address(s_target);
        inner.nonce = 1;
        inner.expectedState = _controlState(1, 1, false);

        _approve(outer);
        _approve(inner);

        bytes memory reentryCalldata = abi.encodeCall(ProtectedAuthorizationController.execute, (inner, s_signature));

        s_target.configureReentry(address(s_controller), reentryCalldata);

        s_target.setMode(AdversarialProtectedTarget.Mode.Reenter);

        _reject(outer, ProtectedAuthorizationController.ReentrantExecution.selector);

        _assertInitialState();
    }

    /*//////////////////////////////////////////////////////////////
                             CONTROL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function testInvalidationAdvancesNonceAndEpoch() public {
        AuthorizationMessage.Envelope memory e = _controlAuthorization(INVALIDATE);

        _approve(e);
        _submit(e);

        assertEq(s_controller.s_nextNonce(), 1);
        assertEq(s_controller.s_policyEpoch(), 2);

        assertEq(s_controller.s_admittedKeyHash(), s_keyHash);
        assertEq(s_target.parameter(), 10);
        assertFalse(s_controller.s_revoked());
    }

    function testInvalidationRejectsOldEpochAuthorization() public {
        AuthorizationMessage.Envelope memory pending = _parameterAuthorization(200);

        AuthorizationMessage.Envelope memory invalidation = _controlAuthorization(INVALIDATE);

        _approve(pending);
        _approve(invalidation);

        _submit(invalidation);

        _reject(pending, ProtectedAuthorizationController.InvalidEpoch.selector);

        AuthorizationMessage.Envelope memory fresh = _parameterAuthorization(300);

        _approve(fresh);
        _submit(fresh);

        assertEq(s_controller.s_nextNonce(), 2);
        assertEq(s_controller.s_policyEpoch(), 2);
        assertEq(s_target.parameter(), 300);
    }

    function testRejectsControlOperationWithWrongTarget() public {
        AuthorizationMessage.Envelope memory e = _controlAuthorization(INVALIDATE);

        e.target = address(s_target);

        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidOperation.selector);
    }

    function testRejectsControlOperationWithNonzeroArgument() public {
        AuthorizationMessage.Envelope memory e = _controlAuthorization(REVOKE);

        e.argument = 1;

        _approve(e);

        _reject(e, ProtectedAuthorizationController.InvalidOperation.selector);
    }

    function testRevocationIsPermanent() public {
        AuthorizationMessage.Envelope memory e = _controlAuthorization(REVOKE);

        _approve(e);
        _submit(e);

        assertTrue(s_controller.s_revoked());
        assertEq(s_controller.s_nextNonce(), 1);
        assertEq(s_controller.s_policyEpoch(), 2);

        assertEq(s_target.owner(), address(s_controller));

        AuthorizationMessage.Envelope memory fresh = _parameterAuthorization(300);

        _approve(fresh);

        _reject(fresh, ProtectedAuthorizationController.ControllerRevoked.selector);

        AuthorizationMessage.Envelope memory invalidate = _controlAuthorization(INVALIDATE);

        _approve(invalidate);

        _reject(invalidate, ProtectedAuthorizationController.ControllerRevoked.selector);

        assertTrue(s_controller.s_revoked());
        assertEq(s_controller.s_nextNonce(), 1);
        assertEq(s_controller.s_policyEpoch(), 2);
        assertEq(s_target.parameter(), 10);
    }

    /*//////////////////////////////////////////////////////////////
                                PROPERTIES
    //////////////////////////////////////////////////////////////*/

    function testFuzzExecutesExactParameter(uint256 newValue) public {
        AuthorizationMessage.Envelope memory e = _parameterAuthorization(newValue);

        _approve(e);
        _submit(e);

        assertEq(s_target.parameter(), newValue);
        assertEq(s_controller.s_nextNonce(), 1);
        assertEq(s_controller.s_policyEpoch(), 1);
        assertEq(s_target.owner(), address(s_controller));
    }

    function testFuzzRejectsModifiedSignedParameter(uint256 original, uint256 modified) public {
        vm.assume(original != modified);

        AuthorizationMessage.Envelope memory e = _parameterAuthorization(original);

        _approve(e);

        e.argument = modified;

        _reject(e, ProtectedAuthorizationController.InvalidSignature.selector);

        _assertInitialState();
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _baseAuthorization() internal view returns (AuthorizationMessage.Envelope memory e) {
        e.chainId = DIANA_CHAIN_ID;
        e.controller = address(s_controller);
        e.authority = AUTHORITY;
        e.executor = EXECUTOR;

        e.keyHash = s_keyHash;
        e.policyEpoch = s_controller.s_policyEpoch();
        e.nonce = s_controller.s_nextNonce();

        e.validAfter = NOW;
        e.validBefore = NOW + 3600;
    }

    function _parameterAuthorization(uint256 newValue) internal view returns (AuthorizationMessage.Envelope memory e) {
        e = _baseAuthorization();

        e.target = address(s_target);
        e.action = SET_PARAMETER;
        e.argument = newValue;
        e.expectedState = _targetState();
        e.evidenceHash = EVIDENCE;
    }

    function _controlAuthorization(uint8 action) internal view returns (AuthorizationMessage.Envelope memory e) {
        e = _baseAuthorization();

        e.target = address(s_controller);
        e.action = action;

        e.expectedState = _controlState(e.policyEpoch, e.nonce, s_controller.s_revoked());
    }

    function _targetState() internal view returns (bytes32) {
        return
            keccak256(abi.encode(address(s_target), address(s_target).codehash, s_target.owner(), s_target.parameter()));
    }

    function _controlState(uint256 epoch, uint256 nonce, bool revoked) internal view returns (bytes32) {
        return keccak256(abi.encode(AUTHORITY, s_keyHash, epoch, nonce, revoked));
    }

    function _registryCalldata() internal pure returns (bytes memory) {
        return abi.encodeCall(IQorePqcKeyStatusPrecompile.pqcKeyStatus, (AUTHORITY));
    }

    function _mockKeyStatus(bool registered, uint8 algorithm, bytes memory publicKey, bool possession) internal {
        vm.mockCall(PQC_KEY_STATUS, _registryCalldata(), abi.encode(registered, algorithm, publicKey, possession));
    }

    function _verificationCalldata(AuthorizationMessage.Envelope memory e) internal view returns (bytes memory) {
        return
            abi.encodeCall(
                IQorePqcVerifyPrecompile.pqcVerify, (s_publicKey, s_signature, AuthorizationMessage.framed(e))
            );
    }

    function _approve(AuthorizationMessage.Envelope memory e) internal {
        vm.mockCall(PQC_VERIFY, _verificationCalldata(e), abi.encode(true));
    }

    function _submit(AuthorizationMessage.Envelope memory e) internal {
        vm.prank(EXECUTOR);

        s_controller.execute(e, s_signature);
    }

    function _reject(AuthorizationMessage.Envelope memory e, bytes4 expectedError) internal {
        vm.expectRevert(expectedError);

        vm.prank(EXECUTOR);

        s_controller.execute(e, s_signature);
    }

    function _assertInitialState() internal view {
        assertEq(s_controller.s_nextNonce(), 0);
        assertEq(s_controller.s_policyEpoch(), 1);
        assertEq(s_controller.s_admittedKeyHash(), s_keyHash);

        assertFalse(s_controller.s_revoked());

        assertEq(s_target.parameter(), 10);
        assertEq(s_target.owner(), address(s_controller));
    }
}
