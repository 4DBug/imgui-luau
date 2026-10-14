#!/usr/bin/env python3
# Minifies a Lua/Luau file: drops comments, indentation, blank lines and spaces that don't separate tokens.
# Kept: strings (verbatim), "--!" directive lines (--!optimize, --!native, ...), @native attributes, and one newline
# wherever the source had one (so no ambiguous-call issues, and error line numbers stay roughly meaningful).
#   python3 tools/minify.py IN OUT          # write minified IN to OUT
#   python3 tools/minify.py --same-code F.. # check F.. have the same code tokens as `git show HEAD:F` (comment-only edits)
#   python3 tools/minify.py --same-code-as OLD NEW  # same check between two files
#   python3 tools/minify.py --test          # self-check
import re, subprocess, sys
from functools import lru_cache

TOKEN = re.compile(r"""
  (?P<ws>[ \t\r\n\f\v]+)
| (?P<lcom>--\[(?P<ceq>=*)\[.*?\](?P=ceq)\])
| (?P<com>--[^\n]*)
| (?P<lstr>\[(?P<seq>=*)\[.*?\](?P=seq)\])
| (?P<str>"(?:\\.|\\\n|[^"\\\n])*"|'(?:\\.|\\\n|[^'\\\n])*'|`(?:\\.|\\\n|[^`\\])*`)
| (?P<num>0[xX][0-9a-fA-F_]*(?:\.[0-9a-fA-F_]*)?(?:[pP][+-]?\d+)?[uUlLi]*|0[bB][01_]+|(?:\d[\d_]*(?:\.[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?\d+)?[uUlLi]*)
| (?P<name>@?[A-Za-z_]\w*)
| (?P<op>\.\.\.|\.\.=|//=|\.\.|==|~=|<=|>=|//|::|->|[-+*/%^]=|.)
""", re.S | re.X)

def tokenize(src):
    """[(kind, text, newline_before)]; comments/whitespace folded into newline_before ("--!" lines kept as 'dir')."""
    out, nl, pos = [], False, 0
    while pos < len(src):
        m = TOKEN.match(src, pos)
        kind, text = m.lastgroup, m.group(0)
        if kind in ("ceq", "seq"): kind = "lcom" if text.startswith("--") else "lstr"
        pos = m.end()
        if kind == "ws" or kind == "lcom" or (kind == "com" and not text.startswith("--!")):
            nl = nl or "\n" in text
            continue
        if kind == "com": kind = "dir"
        if kind == "lstr" or kind == "str": kind = "str"
        out.append((kind, text, nl))
        nl = False
    return out

@lru_cache(maxsize=None)
def glue_ok(a, b):
    """True if `a..b` with no space still tokenizes as exactly a, b."""
    if re.match(r"\w", a[-1]) and re.match(r"\w", b[0]): return False  # real lexers read `0then`/`x1` as one token
    return [t for _, t, _ in tokenize(a + b)] == [a, b]

def minify(src):
    toks, out = tokenize(src), []
    prev = None
    for kind, text, nl in toks:
        if prev is not None:
            if nl or prev[0] == "dir" or kind == "dir": out.append("\n")
            elif kind == "str" or prev[0] == "str":  # strings are self-delimiting; only `[` + `[[` would fuse
                if kind == "str" and text[0] == "[" and prev[1].endswith("["): out.append(" ")
            elif not glue_ok(prev[1], text):
                out.append(" ")
        out.append(text)
        prev = (kind, text)
    return "".join(out) + "\n"

def code(src):
    return [(k, t) for k, t, _ in tokenize(src)]

def test():
    cases = {
        "local a = 1 -- c\nlocal b = a - -1\n": "local a=1\nlocal b=a- -1\n",
        "x = 1 .. 2": "x=1 ..2\n",
        "x = t[ [[s]] ]": "x=t[ [[s]]]\n",
        "x = t[ [==[s]==] ]": "x=t[ [==[s]==]]\n",
        "--!optimize 2\n--[[ long\ncomment ]] local s = 'a -- b' .. \"c\\\"d\"": "--!optimize 2\nlocal s='a -- b'..\"c\\\"d\"\n",
        "@native\nfunction f(...) return ... end": "@native\nfunction f(...)return...end\n",
        "a = b == c and d ~= e or f <= g": "a=b==c and d~=e or f<=g\n",
        "x = 0x10 + 1e-5 + .5": "x=0x10+1e-5+.5\n",
        "f(a)\n\n\n(g)(b)": "f(a)\n(g)(b)\n",
        "s = [[a\n-- not a comment\n]]": "s=[[a\n-- not a comment\n]]\n",
        "x = a / / b": "x=a/ /b\n",
        "x = a . . b": "x=a. .b\n",
        "if a == 0 then return 1 end": "if a==0 then return 1 end\n",
        "x = 1 .. y": "x=1 ..y\n",
    }
    for src, want in cases.items():
        got = minify(src)
        assert got == want, (src, got, want)
        assert code(minify(src)) == code(src), src
    print("minify OK")

if __name__ == "__main__":
    if sys.argv[1] == "--test":
        test()
    elif sys.argv[1] in ("--same-code", "--same-code-as"):
        bad = 0
        pairs = [(sys.argv[2], sys.argv[3])] if sys.argv[1] == "--same-code-as" else [(None, f) for f in sys.argv[2:]]
        for ref, f in pairs:
            old = open(ref).read() if ref else subprocess.run(["git", "show", "HEAD:" + f], capture_output=True, text=True, check=True).stdout
            a, b = code(old), code(open(f).read())
            if a != b:
                bad += 1
                i = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
                print("%s: CODE CHANGED at token %d: %r -> %r" % (f, i, a[i:i + 6], b[i:i + 6]))
            else:
                print("%s: same code" % f)
        sys.exit(1 if bad else 0)
    else:
        src = open(sys.argv[1], encoding="utf-8").read()
        dst = minify(src)
        assert code(dst) == code(src), "minify changed code tokens"
        open(sys.argv[2], "w", encoding="utf-8").write(dst)
        print("wrote %s (%d -> %d bytes, %.0f%%)" % (sys.argv[2], len(src.encode()), len(dst.encode()), 100.0 * len(dst) / len(src)))
