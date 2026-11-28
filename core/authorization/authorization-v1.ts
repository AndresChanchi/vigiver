// SPDX-License-Identifier: MIT OR Apache-2.0

export interface AuthorizationEnvelope {
    readonly chainId: bigint;
    readonly controller: string;
    readonly authority: string;
    readonly executor: string;
    readonly target: string;
    readonly action: bigint;
    readonly argument: bigint;
    readonly value: bigint;
    readonly expectedState: string;
    readonly keyHash: string;
    readonly policyEpoch: bigint;
    readonly nonce: bigint;
    readonly validAfter: bigint;
    readonly validBefore: bigint;
    readonly evidenceHash: string;
}

export const AUTHORIZATION_DOMAIN = "vigiver-authorization-v1";

export const QORESIGN_PREFIX =
    "qorechain-msg-v1|qorechain-diana|";

const FIELDS = [
    "chainId",
    "controller",
    "authority",
    "executor",
    "target",
    "action",
    "argument",
    "value",
    "expectedState",
    "keyHash",
    "policyEpoch",
    "nonce",
    "validAfter",
    "validBefore",
    "evidenceHash",
] as const;

function decimal(value: bigint, bits: number): string {
    if (
        typeof value !== "bigint"
        || value < 0n
        || value >= (1n << BigInt(bits))
    ) {
        throw new RangeError(`Invalid uint${bits} value`);
    }

    return value.toString(10);
}

function hexadecimal(value: string, byteLength: number): string {
    if (
        typeof value !== "string"
        || value.length !== 2 + byteLength * 2
        || !/^0x[0-9a-f]+$/.test(value)
    ) {
        throw new TypeError(
            `Expected canonical ${byteLength}-byte hexadecimal value`,
        );
    }

    return value;
}

function validateFields(envelope: AuthorizationEnvelope): void {
    const keys = Object.keys(envelope);

    if (
        keys.length !== FIELDS.length
        || !FIELDS.every(
            field => Object.prototype.hasOwnProperty.call(envelope, field),
        )
    ) {
        throw new TypeError("Unexpected authorization envelope fields");
    }
}

/**
 * Encodes the exact message presented to the signing wallet.
 *
 * This function validates representation, not operation eligibility.
 */
export function encodeAuthorization(
    envelope: AuthorizationEnvelope,
): string {
    validateFields(envelope);

    return [
        AUTHORIZATION_DOMAIN,
        `chainId=${decimal(envelope.chainId, 256)}`,
        `controller=${hexadecimal(envelope.controller, 20)}`,
        `authority=${hexadecimal(envelope.authority, 20)}`,
        `executor=${hexadecimal(envelope.executor, 20)}`,
        `target=${hexadecimal(envelope.target, 20)}`,
        `action=${decimal(envelope.action, 8)}`,
        `argument=${decimal(envelope.argument, 256)}`,
        `value=${decimal(envelope.value, 256)}`,
        `expectedState=${hexadecimal(envelope.expectedState, 32)}`,
        `keyHash=${hexadecimal(envelope.keyHash, 32)}`,
        `policyEpoch=${decimal(envelope.policyEpoch, 256)}`,
        `nonce=${decimal(envelope.nonce, 256)}`,
        `validAfter=${decimal(envelope.validAfter, 64)}`,
        `validBefore=${decimal(envelope.validBefore, 64)}`,
        `evidenceHash=${hexadecimal(envelope.evidenceHash, 32)}`,
    ].join("\n");
}

/**
 * Reconstructs the exact ML-DSA-87 signing input for Diana.
 */
export function frameAuthorization(
    envelope: AuthorizationEnvelope,
): Uint8Array {
    return new TextEncoder().encode(
        QORESIGN_PREFIX + encodeAuthorization(envelope),
    );
}

/**
 * Identifies the exact QoreSign-framed authorization bytes.
 */
export async function authorizationId(
    envelope: AuthorizationEnvelope,
): Promise<string> {
    const bytes = frameAuthorization(envelope);

    const digest = await crypto.subtle.digest(
        "SHA-256",
        bytes,
    );

    return "0x" + Array.from(
        new Uint8Array(digest),
        value => value.toString(16).padStart(2, "0"),
    ).join("");
}
