"""Credential masking shared by the history-audit scripts.

Best-effort shape matching, not a guarantee: it masks explicit credential
shapes (vendor token prefixes, JWTs, private-key blocks, bearer and Basic
authorization values, URL userinfo, long hex, long base64-like strings with
several digits) and assignments whose key names a credential. A key names a
credential when its last component (split on `_`, `-`, `.` and camelCase) is
password, passwd, passphrase, secret, token, or a key component after api,
access, private or secret: `DB_PASSWORD`, `githubToken`, `api_key` do;
`token_count`, `input_tokens`, `tokenizer` do not. Assignment forms: a quoted
JSON key, `NAME=value` with no space before `=`, `--password value`, and a
line that starts with the key. A line-start `token:` or `key:` masks only a
value that looks secret (a digit or symbol, or 16+ characters), so a prose
label such as "Token: the parser..." stays readable. Apply it to whole
strings before cutting them, so a truncated secret cannot leave a readable
tail.
"""
import json
import re

_PREFIXED = (
    r"sk-ant-[A-Za-z0-9_-]{8,}|sk-[A-Za-z0-9_-]{8,}"
    r"|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{16,}"
    r"|xox[abeoprs]-[A-Za-z0-9-]{10,}|xapp-[A-Za-z0-9-]{10,}"
    r"|AKIA[A-Z0-9]{12,}|ASIA[A-Z0-9]{12,}|AIza[0-9A-Za-z_-]{20,}|ya29\.[0-9A-Za-z_-]{20,}"
    r"|npm_[A-Za-z0-9]{30,}|hf_[A-Za-z0-9]{30,}|tskey-[A-Za-z0-9-]{10,}"
)
_B64 = r"[A-Za-z0-9+/_=-]"
_SHAPES = re.compile(
    r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z0-9 ]*PRIVATE KEY-----|\Z)"
    r"|eyJ[A-Za-z0-9_-]{8,}(?:\.[A-Za-z0-9_-]{4,}){0,2}"
    r"|(?:" + _PREFIXED + r")"
    r"|(?<=[Bb]earer )[A-Za-z0-9._~+/=-]{12,}|(?<=BEARER )[A-Za-z0-9._~+/=-]{12,}"
    r"|(?<=://)[^/\s:@]+:[^/\s@]+(?=@)"
    r"|\b[0-9a-fA-F]{32,}\b"
    # random-looking: 32+ chars, upper and lower case, at least four digits
    # (identifiers such as ParseUserMessagesVersion2Implementation have fewer)
    r"|(?<!" + _B64 + r")(?=(?:" + _B64 + r"*?\d){4})(?=" + _B64 + r"*[a-z])(?=" + _B64 + r"*[A-Z])"
    + _B64 + r"{32,}"
)
_AUTH = re.compile(r"""(?i)(["']?authorization["']?\s*:\s*["']?(?:basic|bearer|token)\s+)[^\s"']+""")

_STRONG = {"password", "passwd", "passphrase", "secret", "token"}
_KEYED = {"api", "access", "private", "secret", "client"}  # ...followed by "key"
_QVAL = r"\"(?:[^\"\\]|\\.){0,4000}\"|'(?:[^'\\]|\\.){0,4000}'"
_UNQ = r"\"\S*|'\S*|[^\s\"',;]+"  # an unbalanced quote still masks its first word
_IDENT = r"[A-Za-z0-9_.-]+"
_JSON_ASSIGN = re.compile(r'"(' + _IDENT + r')"(\s*:\s*)(' + _QVAL + r"|[^\s,}\]]+)")
_ENV_ASSIGN = re.compile(r"(?<![A-Za-z0-9_.-])(" + _IDENT + r")(=)(" + _QVAL + "|" + _UNQ + ")")
_CLI_ASSIGN = re.compile(r"(?<![A-Za-z0-9_-])(--?" + _IDENT + r")([ \t]+)(" + _QVAL + "|" + _UNQ + ")")
_LINE_ASSIGN = re.compile(r"(?m)^(\s*(?:export\s+)?)(" + _IDENT + r")(\s*[:=][ \t]*)(" + _QVAL + r"|\S+)")


def _components(key):
    parts = re.split(r"[_.\-]+|(?<=[a-z0-9])(?=[A-Z])", key.lstrip("-"))
    return [p.lower() for p in parts if p]


def _names_credential(key):
    c = _components(key)
    if not c:
        return False
    if c[-1] in _STRONG:
        return True
    if c[-1] == "apikey" or (c[-1] == "key" and len(c) > 1 and c[-2] in _KEYED):
        return True
    return False


def _looks_secret(value):
    v = value.strip("\"'")
    return bool(re.search(r"[\d!@#$%^&*+/=_.-]", v)) or len(v) >= 16


def _mask_assign(m, key_group, value_group, strong_only_line=False):
    key = m.group(key_group)
    if not _names_credential(key):
        return m.group(0)
    if strong_only_line and _components(key)[-1] not in (_STRONG - {"token"}) \
            and not _looks_secret(m.group(value_group)):
        return m.group(0)
    start = m.start(value_group) - m.start(0)
    return m.group(0)[:start] + "<masked>"


def redact(text):
    if not isinstance(text, str) or not text:
        return text
    text = _SHAPES.sub("<masked>", text)
    text = _AUTH.sub(lambda m: m.group(1) + "<masked>", text)
    text = _JSON_ASSIGN.sub(lambda m: _mask_assign(m, 1, 3), text)
    text = _ENV_ASSIGN.sub(lambda m: _mask_assign(m, 1, 3), text)
    text = _CLI_ASSIGN.sub(lambda m: _mask_assign(m, 1, 3), text)
    text = _LINE_ASSIGN.sub(lambda m: _mask_assign(m, 2, 4, strong_only_line=True), text)
    return text


def redact_obj(obj):
    """Redact every string, keys included, in a JSON-compatible structure."""
    if isinstance(obj, str):
        return redact(obj)
    if isinstance(obj, dict):
        return {redact(str(k)): redact_obj(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [redact_obj(v) for v in obj]
    return obj


def dumps(obj, **kw):
    return json.dumps(redact_obj(obj), **kw)
