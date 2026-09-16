#!/bin/bash
#
# load.sh — fetch a Codeforces problem's sample test into input.txt / expected.txt
#
# Usage:
#   ./load.sh 1527A          # first sample test
#   ./load.sh 1527A 2        # second sample test (if the problem has more than one)
#
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <problem_code> [sample_number]"
    echo "  e.g. $0 1527A"
    echo "       $0 1527A 2"
    exit 1
fi

CODE="$1"
SAMPLE_NUM="${2:-1}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required but was not found on PATH." >&2
    exit 1
fi

if [[ ! "$CODE" =~ ^[0-9]+[A-Za-z][A-Za-z0-9]*$ ]]; then
    echo "Could not parse '$CODE' as a problem code (expected e.g. 1527A)" >&2
    exit 1
fi

python3 - "$CODE" "$SAMPLE_NUM" <<'PYEOF'
import sys
import re
import urllib.request
import urllib.error
from html.parser import HTMLParser

code = sys.argv[1]
sample_num = int(sys.argv[2])

m = re.match(r'^(\d+)([A-Za-z][A-Za-z0-9]*)$', code)
if not m:
    sys.exit(f"Could not parse '{code}' as a problem code (expected e.g. 1527A)")
contest, index = m.group(1), m.group(2)

url = f"https://codeforces.com/problemset/problem/{contest}/{index}"

BASE_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://codeforces.com/",
}


def fetch(target_url, cookie=None):
    """Returns (status_code, body_str)."""
    headers = dict(BASE_HEADERS)
    if cookie:
        headers["Cookie"] = cookie
    req = urllib.request.Request(target_url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status, resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", errors="replace")
    except urllib.error.URLError as e:
        sys.exit(f"Could not reach Codeforces: {e.reason}")


# ---------------------------------------------------------------------------
# Codeforces' anti-bot check: a 403 response can embed an AES-encrypted token
# that a real browser decrypts client-side (via JS) into an "RCPC" cookie,
# then retries the request with. This reproduces that decryption in pure
# Python so no external crypto library is needed.
# ---------------------------------------------------------------------------

SBOX = [
    0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
    0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
    0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
    0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
    0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
    0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
    0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
    0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
    0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
    0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
    0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
    0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
    0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
    0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
    0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
    0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16,
]
INV_SBOX = [0] * 256
for _i, _v in enumerate(SBOX):
    INV_SBOX[_v] = _i
RCON = [0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1B,0x36]


def _gmul(a, b):
    p = 0
    for _ in range(8):
        if b & 1:
            p ^= a
        hi = a & 0x80
        a = (a << 1) & 0xFF
        if hi:
            a ^= 0x1B
        b >>= 1
    return p


def _key_expansion(key):
    Nk, Nr, Nb = 4, 10, 4
    w = [list(key[4 * i:4 * i + 4]) for i in range(Nk)]
    for i in range(Nk, Nb * (Nr + 1)):
        temp = list(w[i - 1])
        if i % Nk == 0:
            temp = temp[1:] + temp[:1]
            temp = [SBOX[b] for b in temp]
            temp[0] ^= RCON[i // Nk - 1]
        w.append([w[i - Nk][j] ^ temp[j] for j in range(4)])
    return w


def _aes_decrypt_block(ciphertext, key):
    Nr = 10
    w = _key_expansion(key)
    state = [[ciphertext[r + 4 * c] for c in range(4)] for r in range(4)]

    def add_round_key(rnd):
        for c in range(4):
            word = w[rnd * 4 + c]
            for r in range(4):
                state[r][c] ^= word[r]

    def inv_shift_rows():
        for r in range(1, 4):
            row = state[r]
            state[r] = row[-r:] + row[:-r]

    def inv_sub_bytes():
        for r in range(4):
            for c in range(4):
                state[r][c] = INV_SBOX[state[r][c]]

    def inv_mix_columns():
        for c in range(4):
            a0, a1, a2, a3 = state[0][c], state[1][c], state[2][c], state[3][c]
            state[0][c] = _gmul(a0, 14) ^ _gmul(a1, 11) ^ _gmul(a2, 13) ^ _gmul(a3, 9)
            state[1][c] = _gmul(a0, 9) ^ _gmul(a1, 14) ^ _gmul(a2, 11) ^ _gmul(a3, 13)
            state[2][c] = _gmul(a0, 13) ^ _gmul(a1, 9) ^ _gmul(a2, 14) ^ _gmul(a3, 11)
            state[3][c] = _gmul(a0, 11) ^ _gmul(a1, 13) ^ _gmul(a2, 9) ^ _gmul(a3, 14)

    add_round_key(Nr)
    for rnd in range(Nr - 1, 0, -1):
        inv_shift_rows()
        inv_sub_bytes()
        add_round_key(rnd)
        inv_mix_columns()
    inv_shift_rows()
    inv_sub_bytes()
    add_round_key(0)

    return bytes(state[r][c] for c in range(4) for r in range(4))


def _aes_cbc_decrypt(ciphertext, key, iv):
    out = b""
    prev = iv
    for i in range(0, len(ciphertext), 16):
        block = ciphertext[i:i + 16]
        dec = _aes_decrypt_block(block, key)
        out += bytes(x ^ y for x, y in zip(dec, prev))
        prev = block
    return out


def _pkcs7_unpad(data):
    if not data:
        return data
    pad = data[-1]
    if 1 <= pad <= 16 and data[-pad:] == bytes([pad]) * pad:
        return data[:-pad]
    return data


def solve_rcpc_challenge(body):
    """If body is Codeforces' AES challenge page, return the RCPC cookie
    value it expects, else None."""
    a_m = re.search(r'a=toNumbers\("([0-9a-f]+)"\)', body)
    b_m = re.search(r'b=toNumbers\("([0-9a-f]+)"\)', body)
    c_m = re.search(r'c=toNumbers\("([0-9a-f]+)"\)', body)
    if not (a_m and b_m and c_m):
        return None
    key = bytes.fromhex(a_m.group(1))
    iv = bytes.fromhex(b_m.group(1))
    ciphertext = bytes.fromhex(c_m.group(1))
    plaintext = _aes_cbc_decrypt(ciphertext, key, iv)
    return _pkcs7_unpad(plaintext).hex()


# ---------------------------------------------------------------------------
# Fetch the page, solving the RCPC challenge if we hit one.
# ---------------------------------------------------------------------------

status, body = fetch(url)

if status != 200:
    rcpc = solve_rcpc_challenge(body)
    if rcpc:
        status, body = fetch(url, cookie=f"RCPC={rcpc}")

if status != 200:
    sys.exit(
        f"HTTP error {status} fetching {url} (even after attempting the "
        "RCPC challenge). Codeforces may be hard-blocking this IP for a "
        "while — try again later from a real browser first, or wait it out."
    )

if "sample-test" not in body:
    sys.exit(
        f"No sample tests found for {code}.\n"
        "The problem code may be wrong, or Codeforces returned a non-problem page."
    )

page = body


class SampleParser(HTMLParser):
    """Pulls text out of the <div class="input"><pre>...</pre></div> and
    <div class="output"><pre>...</pre></div> blocks on a Codeforces problem
    page. Handles both the classic raw-newline <pre> format and the newer
    one-<div>-per-line format by turning any <br> or nested <div> inside a
    <pre> into a newline."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.inputs = []
        self.outputs = []
        self.mode = None
        self.in_pre = False
        self.buf = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        cls = attrs.get("class", "")
        if tag == "div" and cls == "input":
            self.mode = "input"
        elif tag == "div" and cls == "output":
            self.mode = "output"
        elif tag == "pre" and self.mode:
            self.in_pre = True
            self.buf = []
        elif self.in_pre and tag in ("br", "div"):
            self.buf.append("\n")

    def handle_endtag(self, tag):
        if tag == "pre" and self.in_pre:
            text = "".join(self.buf).strip("\n")
            if self.mode == "input":
                self.inputs.append(text)
            elif self.mode == "output":
                self.outputs.append(text)
            self.in_pre = False
            self.mode = None

    def handle_data(self, data):
        if self.in_pre:
            self.buf.append(data)


parser = SampleParser()
parser.feed(page)

pairs = list(zip(parser.inputs, parser.outputs))
if not pairs:
    sys.exit("Parsed the page but found no input/output sample pairs.")

if sample_num < 1 or sample_num > len(pairs):
    sys.exit(
        f"Problem {code} only has {len(pairs)} sample test(s); "
        f"sample {sample_num} does not exist."
    )

sample_input, sample_output = pairs[sample_num - 1]

with open("input.txt", "w") as f:
    f.write(sample_input + "\n")
with open("expected.txt", "w") as f:
    f.write(sample_output + "\n")

print(f"Wrote input.txt / expected.txt for {code} (sample {sample_num} of {len(pairs)})")
PYEOF