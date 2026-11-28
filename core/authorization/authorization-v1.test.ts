// SPDX-License-Identifier: MIT OR Apache-2.0

import { describe, expect, test } from "bun:test";
import {
    authorizationId,
    encodeAuthorization,
    frameAuthorization,
    type AuthorizationEnvelope,
} from "./authorization-v1";

interface ReferenceVector {
    name: string;
    envelope: Record<keyof AuthorizationEnvelope, string>;
    message: string;
    framedMessage: string;
    authorizationId: string;
}

const fixture = await Bun.file(
    new URL(
        "../../contracts/test/fixtures/authorization/v1.json",
        import.meta.url,
    ),
).json() as {
    count: number;
    vectors: ReferenceVector[];
};

function decodeEnvelope(
    raw: ReferenceVector["envelope"],
): AuthorizationEnvelope {
    return {
        ...raw,
        chainId: BigInt(raw.chainId),
        action: BigInt(raw.action),
        argument: BigInt(raw.argument),
        value: BigInt(raw.value),
        policyEpoch: BigInt(raw.policyEpoch),
        nonce: BigInt(raw.nonce),
        validAfter: BigInt(raw.validAfter),
        validBefore: BigInt(raw.validBefore),
    };
}

const example = decodeEnvelope(fixture.vectors[2].envelope);

describe("Independent reference vectors", () => {
    test("contains all six expected vectors", () => {
        expect(fixture.count).toBe(6);
        expect(fixture.vectors.length).toBe(6);
    });

    for (const vector of fixture.vectors) {
        test(vector.name, async () => {
            const envelope = decodeEnvelope(vector.envelope);

            expect(encodeAuthorization(envelope))
                .toBe(vector.message);

            expect(frameAuthorization(envelope))
                .toEqual(new TextEncoder().encode(vector.framedMessage));

            expect(await authorizationId(envelope))
                .toBe(vector.authorizationId);
        });
    }
});

describe("Canonical encoding", () => {
    test("binds every envelope field", () => {
        const original = encodeAuthorization(example);

        for (const field of Object.keys(example) as
            (keyof AuthorizationEnvelope)[]) {
            const value = example[field];

            const changed = typeof value === "bigint"
                ? value ^ 1n
                : value.slice(0, -1) + (value.endsWith("0") ? "1" : "0");

            expect(encodeAuthorization({
                ...example,
                [field]: changed,
            })).not.toBe(original);
        }
    });

    test("does not append a final newline", () => {
        expect(encodeAuthorization(example).endsWith("\n"))
            .toBe(false);
    });

    test("does not include carriage returns", () => {
        expect(encodeAuthorization(example)).not.toContain("\r");
    });

    test("rejects negative integers", () => {
        expect(() => encodeAuthorization({
            ...example,
            nonce: -1n,
        })).toThrow();
    });

    test("rejects uint256 overflow", () => {
        expect(() => encodeAuthorization({
            ...example,
            argument: 1n << 256n,
        })).toThrow();
    });

    test("rejects uint8 overflow", () => {
        expect(() => encodeAuthorization({
            ...example,
            action: 256n,
        })).toThrow();
    });

    test("rejects uint64 overflow", () => {
        expect(() => encodeAuthorization({
            ...example,
            validBefore: 1n << 64n,
        })).toThrow();
    });

    test("rejects JavaScript number input", () => {
        expect(() => encodeAuthorization({
            ...example,
            chainId: 9800 as unknown as bigint,
        })).toThrow();
    });

    test("rejects uppercase hexadecimal input", () => {
        expect(() => encodeAuthorization({
            ...example,
            authority: "0x" + "AB".repeat(20),
        })).toThrow();
    });

    test("rejects truncated addresses", () => {
        expect(() => encodeAuthorization({
            ...example,
            executor: "0x01",
        })).toThrow();
    });

    test("rejects truncated commitments", () => {
        expect(() => encodeAuthorization({
            ...example,
            keyHash: "0x01",
        })).toThrow();
    });

    test("rejects injected line separators", () => {
        expect(() => encodeAuthorization({
            ...example,
            authority: example.authority + "\n",
        })).toThrow();
    });

    test("rejects unexpected envelope fields", () => {
        const extended = {
            ...example,
            additionalPermission: "unrestricted",
        };

        expect(() => encodeAuthorization(extended)).toThrow();
    });
});
