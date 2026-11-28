#!/usr/bin/env python3
# SPDX-License-Identifier: MIT OR Apache-2.0

"""Generate independent public authorization encoding fixtures."""

from pathlib import Path
import hashlib
import json

DOMAIN = "vigiver-authorization-v1"
SIGNING_PREFIX = "qorechain-msg-v1|qorechain-diana|"

FIELDS = (
    ("chainId", 256),
    ("controller", "address"),
    ("authority", "address"),
    ("executor", "address"),
    ("target", "address"),
    ("action", 8),
    ("argument", 256),
    ("value", 256),
    ("expectedState", "bytes32"),
    ("keyHash", "bytes32"),
    ("policyEpoch", 256),
    ("nonce", 256),
    ("validAfter", 64),
    ("validBefore", 64),
    ("evidenceHash", "bytes32"),
)

def encode(envelope):
    lines = [DOMAIN]

    for field, kind in FIELDS:
        value = envelope[field]

        if isinstance(kind, int):
            assert isinstance(value, int)
            assert 0 <= value < (1 << kind)
            encoded = str(value)
        else:
            width = 20 if kind == "address" else 32
            assert isinstance(value, bytes)
            assert len(value) == width
            encoded = "0x" + value.hex()

        lines.append(f"{field}={encoded}")

    return "\n".join(lines)

def vector(name, envelope):
    message = encode(envelope)
    framed = SIGNING_PREFIX + message

    json_envelope = {
        field: str(value) if isinstance(value, int)
        else "0x" + value.hex()
        for field, value in envelope.items()
    }

    return {
        "name": name,
        "envelope": json_envelope,
        "message": message,
        "framedMessage": framed,
        "authorizationId": (
            "0x" + hashlib.sha256(framed.encode("ascii")).hexdigest()
        ),
    }

def boundary(maximum):
    result = {}

    for field, kind in FIELDS:
        if isinstance(kind, int):
            result[field] = (1 << kind) - 1 if maximum else 0
        else:
            width = 20 if kind == "address" else 32
            result[field] = bytes([255 if maximum else 0]) * width

    return result

example = {
    "chainId": 9800,
    "controller": bytes.fromhex("00" * 19 + "11"),
    "authority": bytes.fromhex("11" * 19 + "ab"),
    "executor": bytes.fromhex("22" * 20),
    "target": bytes.fromhex("33" * 20),
    "action": 1,
    "argument": 200,
    "value": 0,
    "expectedState": bytes.fromhex("00" + "ab" * 31),
    "keyHash": bytes.fromhex("cd" * 32),
    "policyEpoch": 1,
    "nonce": 12,
    "validAfter": 1795824000,
    "validBefore": 1795827600,
    "evidenceHash": bytes.fromhex("ef" * 32),
}

vectors = [
    vector("zero_encoding_boundary", boundary(False)),
    vector("maximum_encoding_boundary", boundary(True)),
]

for action, name in [
    (1, "set_parameter"),
    (2, "invalidate"),
    (3, "sync_key"),
    (4, "revoke"),
]:
    envelope = dict(example)
    envelope["action"] = action

    if action != 1:
        envelope["target"] = envelope["controller"]
        envelope["argument"] = 0
        envelope["evidenceHash"] = bytes(32)

    vectors.append(vector(name, envelope))

output = (
    Path(__file__).resolve().parents[2]
    / "test/fixtures/authorization/v1.json"
)

payload = json.dumps(
    {
        "schema": "vigiver-authorization-v1",
        "count": len(vectors),
        "vectors": vectors,
    },
    indent=2,
    ensure_ascii=True,
) + "\n"

output.write_bytes(payload.encode("ascii"))

print(f"Fixture: {output}")
print(f"Vectors: {len(vectors)}")
print(f"SHA-256: {hashlib.sha256(payload.encode('ascii')).hexdigest()}")
