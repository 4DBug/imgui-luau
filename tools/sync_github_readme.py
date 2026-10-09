#!/usr/bin/env python3
# Writes .github/README.md = mirror notice + README.md. GitHub shows .github/README.md in preference to the root one,
# while git.bug.tools (Gitea/Forgejo) shows the root README.md, so the notice only appears on the GitHub mirror.
# Relative links are made repo-root-absolute ("/path") since the file lives in .github/. Run after editing README.md
# (CI fails if it's out of date).
import os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NOTICE = ("> [!NOTE]\n> This is a read-only mirror of **https://git.bug.tools/bug/imgui-luau**. "
          "Releases are built here by GitHub Actions; development happens on git.bug.tools.\n\n")
src = open(os.path.join(ROOT, "README.md")).read()
def fix(m):
    url = m.group(2)
    if re.match(r"^([a-z]+:|#|/)", url): return m.group(0)
    return m.group(1) + "/" + url + ")"
out = NOTICE + re.sub(r"(\]\()([^)\s]+)\)", fix, src)
path = os.path.join(ROOT, ".github", "README.md")
if "--check" in sys.argv:
    sys.exit(0 if os.path.exists(path) and open(path).read() == out else "out of date: run python3 tools/sync_github_readme.py")
open(path, "w").write(out)
print("wrote .github/README.md")
