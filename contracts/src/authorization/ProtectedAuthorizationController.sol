// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {AuthorizationMessage} from "./AuthorizationMessage.sol";
import {IProtectedTarget} from "./interfaces/IProtectedTarget.sol";

import {QorePqcKeyRegistry} from "../cryptography/qorechain/QorePqcKeyRegistry.sol";

import {QorePqcVerifier} from "../cryptography/qorechain/QorePqcVerifier.sol";

/// @title ProtectedAuthorizationController
/// @notice Enforces typed post-quantum authorization on QoreChain Diana.
/// @dev Supports one explicitly admitted, directly deployed target.
///      Native key synchronization is not enabled in this implementation.
/// @custom:security-contact See SECURITY.md in the repository root.
contract ProtectedAuthorizationController {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidNetwork();
    error InvalidTarget();
    error TargetCodeMismatch();
    error ControllerRevoked();
    error InvalidController();
    error InvalidAuthority();
    error InvalidExecutor();
    error UnsupportedAction();
    error InvalidOperation();
    error InvalidValue();
    error InvalidEpoch();
    error InvalidNonce();
    error InvalidValidityInterval();
    error AuthorizationNotActive();
    error ExpectedStateMismatch();
    error KeyCommitmentMismatch();
    error InvalidSignature();
    error TargetOwnershipMismatch();
    error TargetPostconditionFailed();
    error ReentrantExecution();

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant DIANA_CHAIN_ID = 9800;

    uint256 public constant MAX_VALIDITY_INTERVAL = 3600;

    uint8 public constant SET_PARAMETER = 1;
    uint8 public constant INVALIDATE = 2;
    uint8 public constant SYNC_KEY = 3;
    uint8 public constant REVOKE = 4;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    address public immutable i_authority;

    address public immutable i_target;

    bytes32 public immutable i_targetCodeHash;

    /*//////////////////////////////////////////////////////////////
                              CONTROLLER STATE
    //////////////////////////////////////////////////////////////*/

    bytes32 public s_admittedKeyHash;

    uint256 public s_policyEpoch;

    uint256 public s_nextNonce;

    bool public s_revoked;

    mapping(bytes32 => bool) public s_previouslyAdmittedKeys;

    bool private s_entered;

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event ControllerBootstrapped(
        address indexed authority,
        address indexed target,
        bytes32 indexed keyHash,
        bytes32 targetCodeHash,
        address initialTargetOwner,
        uint256 initialTargetParameter
    );

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

    event ParameterChanged(bytes32 indexed authorizationId, uint256 previousValue, uint256 newValue);

    event PolicyInvalidated(bytes32 indexed authorizationId, uint256 newPolicyEpoch);

    event PermanentRevocation(bytes32 indexed authorizationId, uint256 newPolicyEpoch);

    /*//////////////////////////////////////////////////////////////
                                  MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier nonReentrant() {
        if (s_entered) revert ReentrantExecution();

        s_entered = true;

        _;

        s_entered = false;
    }

    /*//////////////////////////////////////////////////////////////
                                   BOOTSTRAP
    //////////////////////////////////////////////////////////////*/

    /// @notice Atomically establishes the recognized authority and target.
    /// @dev Deployment does not transfer ownership of the target.
    ///      The expected runtime commitment must be independently reviewed.
    constructor(address authority, address target, bytes32 expectedTargetCodeHash) {
        if (block.chainid != DIANA_CHAIN_ID) {
            revert InvalidNetwork();
        }

        if (target == address(0) || target.code.length == 0) {
            revert InvalidTarget();
        }

        if (target.codehash != expectedTargetCodeHash) {
            revert TargetCodeMismatch();
        }

        (, bytes32 keyHash) = QorePqcKeyRegistry.requireEligibleKey(authority);

        // Check that the required typed target getters are callable.
        // Their availability does not establish the target's security.
        address initialOwner = IProtectedTarget(target).owner();

        uint256 initialParameter = IProtectedTarget(target).parameter();

        i_authority = authority;
        i_target = target;
        i_targetCodeHash = expectedTargetCodeHash;

        s_admittedKeyHash = keyHash;
        s_policyEpoch = 1;
        s_nextNonce = 0;

        s_previouslyAdmittedKeys[keyHash] = true;

        emit ControllerBootstrapped(authority, target, keyHash, expectedTargetCodeHash, initialOwner, initialParameter);
    }

    /*//////////////////////////////////////////////////////////////
                               EXPECTED STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current controller-state commitment.
    function controlState() public view returns (bytes32) {
        return keccak256(abi.encode(i_authority, s_admittedKeyHash, s_policyEpoch, s_nextNonce, s_revoked));
    }

    /// @notice Returns the current supported target-state commitment.
    /// @dev Rejects unavailable code or incompatible ownership.
    function targetState() public view returns (bytes32 commitment) {
        (commitment,) = _readTargetState();
    }

    /*//////////////////////////////////////////////////////////////
                            PROTECTED EXECUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes an exact, currently valid PQC authorization.
    /// @dev No arbitrary target, selector, calldata or native-value transfer.
    ///      Every protected action shares the same reentrancy boundary.
    function execute(AuthorizationMessage.Envelope calldata e, bytes calldata signature) external payable nonReentrant {
        _validateCommon(e);

        uint256 previousParameter;
        bytes32 currentState;

        if (e.action == SET_PARAMETER) {
            (currentState, previousParameter) = _readTargetState();
        } else {
            currentState = controlState();
        }

        if (e.expectedState != currentState) {
            revert ExpectedStateMismatch();
        }

        bytes32 authorizationId = _verifyAuthorization(e, signature);

        // Consume before any mutable external interaction.
        // Reverting the transaction restores the previous nonce.
        s_nextNonce = e.nonce + 1;

        if (e.action == SET_PARAMETER) {
            _executeParameter(e.argument);
        } else if (e.action == INVALIDATE) {
            s_policyEpoch = e.policyEpoch + 1;
        } else if (e.action == REVOKE) {
            s_policyEpoch = e.policyEpoch + 1;
            s_revoked = true;
        } else {
            revert UnsupportedAction();
        }

        // Success events describe committed transitions only.
        emit AuthorizationExecuted(
            authorizationId, i_authority, e.executor, e.action, e.target, e.nonce, e.policyEpoch, e.evidenceHash
        );

        if (e.action == SET_PARAMETER) {
            emit ParameterChanged(authorizationId, previousParameter, e.argument);
        } else if (e.action == INVALIDATE) {
            emit PolicyInvalidated(authorizationId, s_policyEpoch);
        } else {
            emit PermanentRevocation(authorizationId, s_policyEpoch);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            COMMON AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    function _validateCommon(AuthorizationMessage.Envelope calldata e) private view {
        if (s_revoked) revert ControllerRevoked();

        if (block.chainid != DIANA_CHAIN_ID || e.chainId != block.chainid) {
            revert InvalidNetwork();
        }

        if (e.controller != address(this)) {
            revert InvalidController();
        }

        if (e.authority != i_authority) {
            revert InvalidAuthority();
        }

        if (e.executor == address(0) || e.executor != msg.sender) {
            revert InvalidExecutor();
        }

        if (e.value != 0 || msg.value != 0) {
            revert InvalidValue();
        }

        _validateOperation(e);

        if (e.policyEpoch != s_policyEpoch) {
            revert InvalidEpoch();
        }

        if (e.nonce != s_nextNonce) {
            revert InvalidNonce();
        }

        _validateValidity(e.validAfter, e.validBefore);
    }

    function _validateOperation(AuthorizationMessage.Envelope calldata e) private view {
        if (e.action == SET_PARAMETER) {
            if (e.target != i_target || e.evidenceHash == bytes32(0)) {
                revert InvalidOperation();
            }

            return;
        }

        if (e.action == INVALIDATE || e.action == REVOKE) {
            if (e.target != address(this) || e.argument != 0) {
                revert InvalidOperation();
            }

            return;
        }

        // SYNC_KEY and all unrecognized actions fail closed.
        revert UnsupportedAction();
    }

    function _validateValidity(uint64 validAfter, uint64 validBefore) private view {
        // Check ordering before subtraction.
        if (validBefore <= validAfter) {
            revert InvalidValidityInterval();
        }

        if (validBefore - validAfter > MAX_VALIDITY_INTERVAL) {
            revert InvalidValidityInterval();
        }

        if (block.timestamp < validAfter || block.timestamp >= validBefore) {
            revert AuthorizationNotActive();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            CRYPTOGRAPHIC POLICY
    //////////////////////////////////////////////////////////////*/

    function _verifyAuthorization(AuthorizationMessage.Envelope calldata e, bytes calldata signature)
        private
        view
        returns (bytes32)
    {
        if (e.keyHash != s_admittedKeyHash) {
            revert KeyCommitmentMismatch();
        }

        // The trusted verification key is never supplied by the executor.
        bytes memory publicKey = QorePqcKeyRegistry.requireMatchingKey(i_authority, s_admittedKeyHash);

        bytes memory message = AuthorizationMessage.framed(e);

        if (!QorePqcVerifier.verify(publicKey, signature, message)) {
            revert InvalidSignature();
        }

        return sha256(message);
    }

    /*//////////////////////////////////////////////////////////////
                             TARGET EXECUTION
    //////////////////////////////////////////////////////////////*/

    function _readTargetState() private view returns (bytes32 commitment, uint256 currentParameter) {
        if (i_target.codehash != i_targetCodeHash) {
            revert TargetCodeMismatch();
        }

        address currentOwner = IProtectedTarget(i_target).owner();

        if (currentOwner != address(this)) {
            revert TargetOwnershipMismatch();
        }

        currentParameter = IProtectedTarget(i_target).parameter();

        commitment = keccak256(abi.encode(i_target, i_targetCodeHash, currentOwner, currentParameter));
    }

    function _executeParameter(uint256 newValue) private {
        IProtectedTarget(i_target).setParameter(newValue);

        // Recheck runtime code, ownership and the resulting parameter.
        (, uint256 actualParameter) = _readTargetState();

        if (actualParameter != newValue) {
            revert TargetPostconditionFailed();
        }
    }
}
