#!/usr/bin/env python3
"""Drift checks: keep code, tests, docs and pinned versions consistent with the spec and CLAUDE.md.

Each check returns a list of problems. Suppress a single line with `# drift:ok <reason>`.
Stdlib only, so it runs anywhere Python 3 runs. With DRIFT_BASE=<git ref> (CI), the
spec/decision check compares against that commit instead of the uncommitted changes.
"""
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CODE_DIRS = ["autoload", "logic", "scenes"]
# Where tuning numbers must come from Balance or the theme (named constants are exempt).
NUMBER_DIRS = ["logic", "scenes/puzzles"]
ALLOWED_VALUES = {0, 1, 2, -1, 0.5, 1000, 1_000_000}
DUP_WINDOW = 6  # identical significant lines in a row that count as duplicated code
MAX_FUNC_LINES = 40
RAW_INPUT = re.compile(
    r"\b(InputEventKey|InputEventJoypad\w*|KEY_[A-Z0-9_]+|JOY_[A-Z_]+|is_key_pressed)\b"
)
NUMBER = re.compile(r"(?<![\w.])-?\d+(?:\.\d+)?(?![\w.])")


def gd_files(dirs):
    return sorted(p for d in dirs for p in (ROOT / d).rglob("*.gd"))


def rel(path):
    return path.relative_to(ROOT).as_posix()


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def code_lines(path):
    """(line_no, code) pairs, comments and string contents stripped; suppressed lines skipped."""
    for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if "drift:ok" in line:
            continue
        code = re.sub(r'"[^"]*"|\'[^\']*\'', '""', line).split("#", 1)[0].rstrip()
        yield no, code


def git(*args):
    """stdout of a git command, or None when git is unavailable or the command fails."""
    try:
        return subprocess.run(
            ["git", *args], cwd=ROOT, capture_output=True, text=True, check=True
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return None


def versions():
    return dict(re.findall(r"^([A-Z_]+)=(\S+)", read("tools/versions.env"), re.M))


def check_versions():
    """Every stated Godot/GUT version matches tools/versions.env; presets match config/version."""
    pins = versions()
    godot, gut = pins["GODOT_VERSION"], pins["GUT_VERSION"]
    problems = []
    features = re.search(r"config/features=.*", read("project.godot"))
    major_minor = godot.rsplit(".", 1)[0]
    if not features or f'"{major_minor}"' not in features.group(0):
        problems.append(f"project.godot config/features does not list Godot {major_minor}")
    plugin = read("addons/gut/plugin.cfg")
    if f'version="{gut}"' not in plugin:
        problems.append(f"addons/gut/plugin.cfg is not GUT {gut} (tools/versions.env)")
    docs = [p for p in ROOT.rglob("*.md") if ".venv" not in p.parts and "addons" not in p.parts]
    for doc in docs:
        text = doc.read_text(encoding="utf-8")
        for tool, pin in (("Godot", godot), ("GUT", gut)):
            for found in set(re.findall(rf"\b{tool} (\d+\.\d+\.\d+)\b", text)):
                if found != pin:
                    problems.append(f"{rel(doc)} says {tool} {found}, pinned is {pin}")
    app_version = re.search(r'config/version="([^"]+)"', read("project.godot"))
    presets = read("export_presets.cfg")
    if app_version:
        fields = re.findall(r"(version/name|application/(?:short_)?version)=\"([^\"]+)\"", presets)
        for key, found in fields:
            if found != app_version.group(1):
                problems.append(f"export_presets.cfg {key}={found} differs from config/version")
    filters = set(re.findall(r"^(include_filter|exclude_filter)=.*$", presets, re.M))
    if len(filters) > 2:
        problems.append("export_presets.cfg: presets have different include/exclude filters")
    return problems


def check_tests_mirror_logic():
    problems = []
    for src in gd_files(["logic"]):
        has_code = any(c.lstrip().startswith(("func ", "static func ")) for _, c in code_lines(src))
        snake = re.sub(r"(?<!^)(?=[A-Z])", "_", src.stem).lower()
        test = ROOT / "tests" / "logic" / f"test_{snake}.gd"
        if has_code and not test.exists():
            problems.append(f"{rel(src)} has functions but no test file {rel(test)}")
    return problems


def check_done_todos():
    done = set(re.findall(r"^\|\s*(M\d+)\s*\|\s*done\s*\|", read("docs/PROGRESS.md"), re.M))
    problems = []
    for path in gd_files(CODE_DIRS + ["tests"]):
        for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if "drift:ok" in line:
                continue
            for ms in re.findall(r"TODO\((M\d+)", line):
                if ms in done:
                    problems.append(f"{rel(path)}:{no} TODO({ms}) left, but {ms} is marked done")
    return problems


def check_spec_has_decision():
    base = os.environ.get("DRIFT_BASE", "")
    if base and not base.startswith("0000000"):
        out = git("diff", "--name-only", base, "HEAD", "--", "docs/SPEC.md", "docs/DECISIONS.md")
        if out is None:
            return [f"cannot diff against DRIFT_BASE={base} (not fetched?)"]
        changed = set(out.split())
    else:
        out = git("status", "--porcelain", "--", "docs/SPEC.md", "docs/DECISIONS.md")
        if out is None:
            return []
        changed = {line[3:].strip() for line in out.splitlines()}
    if "docs/SPEC.md" in changed and "docs/DECISIONS.md" not in changed:
        return ["docs/SPEC.md changed without a new entry in docs/DECISIONS.md (use /spec-change)"]
    return []


def check_magic_numbers():
    problems = []
    for path in gd_files(NUMBER_DIRS):
        depth = 0  # open brackets of a multi-line const/enum, whose lines are all exempt
        for no, code in code_lines(path):
            if depth > 0 or code.lstrip().startswith(("const ", "enum ")):
                opened = sum(code.count(c) for c in "([{") - sum(code.count(c) for c in ")]}")
                depth = max(0, depth + opened)
                continue
            for num in NUMBER.findall(code):
                if float(num) not in ALLOWED_VALUES:  # 2.0 counts as 2
                    problems.append(f"{rel(path)}:{no} magic number {num} — read it from Balance")
    return problems


def check_duplicates():
    seen, problems = {}, []
    for path in gd_files(CODE_DIRS):
        sig = [(no, c.strip()) for no, c in code_lines(path) if len(c.strip()) > 12]
        i = 0
        while i <= len(sig) - DUP_WINDOW:
            key = "\n".join(c for _, c in sig[i:i + DUP_WINDOW])
            here = (rel(path), sig[i][0])
            first = seen.setdefault(key, here)
            if first != here and (first[0] != here[0] or here[1] - first[1] >= DUP_WINDOW):
                problems.append(f"{here[0]}:{here[1]} duplicates {first[0]}:{first[1]} "
                                f"({DUP_WINDOW}+ lines) — extract a shared function")
                i += DUP_WINDOW  # one report per copied block
            else:
                i += 1
    return problems


def check_function_length():
    problems = []
    for path in gd_files(CODE_DIRS):
        name, start, count = None, 0, 0
        for no, code in list(code_lines(path)) + [(0, "func __end__")]:
            top_level = code and not code[0].isspace() and name
            if re.match(r"\s*(static\s+)?func\s", code) or top_level:
                if name and count > MAX_FUNC_LINES:
                    problems.append(
                        f"{rel(path)}:{start} {name}() has {count} lines (max {MAX_FUNC_LINES})"
                    )
                m = re.match(r"\s*(?:static\s+)?func\s+(\w+)", code)
                name, start, count = (m.group(1), no, 0) if m else (None, 0, 0)
            elif name and code.strip():
                count += 1
    return problems


def check_input_and_layers():
    """Raw input only in InputMode; logic/ is pure (no nodes, no autoload but Balance);
    puzzles never touch GameState."""
    autoloads = re.findall(r"^(\w+)=\"\*res://", read("project.godot"), re.M)
    forbidden = re.compile(r"\b(" + "|".join(a for a in autoloads if a != "Balance") + r")\b")
    problems = []
    for path in gd_files(CODE_DIRS):
        name = rel(path)
        for no, code in code_lines(path):
            if name != "autoload/InputMode.gd" and RAW_INPUT.search(code):
                problems.append(f"{name}:{no} raw key/button access — use InputMap actions")
            if name.startswith("logic/"):
                if forbidden.search(code):
                    problems.append(f"{name}:{no} logic/ may use no autoload except Balance")
                if re.match(r"extends\s+(Node|Control|CanvasItem)\b", code):
                    problems.append(f"{name}:{no} logic/ must be RefCounted, not a node")
            elif name.startswith("scenes/puzzles/") and re.search(r"\bGameState\b", code):
                problems.append(f"{name}:{no} puzzles must not touch GameState")
    return problems


CHECKS = [check_versions, check_tests_mirror_logic, check_done_todos, check_spec_has_decision,
          check_magic_numbers, check_duplicates, check_function_length, check_input_and_layers]


def main():
    problems = [p for check in CHECKS for p in check()]
    for p in problems:
        print(p)
    print(f"drift: {len(problems)} problem(s)" if problems else "drift: clean")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
