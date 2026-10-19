#!/usr/bin/env python3
"""Drift checks: keep code, tests, docs and pinned versions consistent with docs/SPEC.md and CLAUDE.md.

Each check returns a list of problems. Suppress a single line with `# drift:ok <reason>`.
Stdlib only, so it runs anywhere Python 3 runs.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CODE_DIRS = ["autoload", "logic", "scenes"]
ALLOWED_NUMBERS = {"0", "1", "2", "-1", "0.0", "1.0", "0.5", "1000", "1000.0", "1000000"}
DUP_WINDOW = 6  # identical significant lines in a row that count as duplicated code
MAX_FUNC_LINES = 40
RAW_INPUT = re.compile(r"\b(InputEventKey|InputEventJoypad\w*|KEY_[A-Z0-9_]+|JOY_[A-Z_]+|is_key_pressed)\b")


def gd_files(dirs):
    return sorted(p for d in dirs for p in (ROOT / d).rglob("*.gd"))


def rel(path):
    return path.relative_to(ROOT).as_posix()


def code_lines(path):
    """(line_no, code) pairs with comments and string contents stripped; suppressed lines skipped."""
    for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if "drift:ok" in line:
            continue
        code = re.sub(r'"[^"]*"|\'[^\']*\'', '""', line).split("#", 1)[0].rstrip()
        yield no, code


def check_godot_pin():
    pinned = re.search(r"GODOT_VERSION=(\d+\.\d+)", (ROOT / "tools/versions.env").read_text()).group(1)
    features = re.search(r"config/features=.*", (ROOT / "project.godot").read_text())
    if not features or f'"{pinned}"' not in features.group(0):
        return [f"project.godot config/features does not match pinned Godot {pinned} (tools/versions.env)"]
    return []


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
    progress = (ROOT / "docs/PROGRESS.md").read_text()
    done = set(re.findall(r"^\|\s*(M\d+)\s*\|\s*done\s*\|", progress, re.M))
    problems = []
    for path in gd_files(CODE_DIRS + ["tests"]):
        for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for ms in re.findall(r"TODO\((M\d+)", line):
                if ms in done:
                    problems.append(f"{rel(path)}:{no} TODO({ms}) left, but {ms} is marked done")
    return problems


def check_spec_has_decision():
    try:
        out = subprocess.run(["git", "status", "--porcelain", "--", "docs/SPEC.md", "docs/DECISIONS.md"],
                             cwd=ROOT, capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return []
    changed = {line[3:].strip() for line in out.splitlines()}
    if "docs/SPEC.md" in changed and "docs/DECISIONS.md" not in changed:
        return ["docs/SPEC.md changed without a new entry in docs/DECISIONS.md (use /spec-change)"]
    return []


def check_magic_numbers():
    problems = []
    for path in gd_files(["logic", "scenes/puzzles"]):
        for no, code in code_lines(path):
            if code.lstrip().startswith(("const ", "enum ")):
                continue
            for num in re.findall(r"(?<![\w.])-?\d+(?:\.\d+)?(?![\w.])", code):
                if num not in ALLOWED_NUMBERS:
                    problems.append(f"{rel(path)}:{no} magic number {num} — read it from Balance")
    return problems


def check_duplicates():
    seen, problems = {}, []
    for path in gd_files(CODE_DIRS):
        sig = [(no, c.strip()) for no, c in code_lines(path) if len(c.strip()) > 12]
        for i in range(len(sig) - DUP_WINDOW + 1):
            key = "\n".join(c for _, c in sig[i:i + DUP_WINDOW])
            here = (rel(path), sig[i][0])
            first = seen.setdefault(key, here)
            if first != here and (first[0] != here[0] or here[1] - first[1] >= DUP_WINDOW):
                problems.append(f"{here[0]}:{here[1]} duplicates {first[0]}:{first[1]} "
                                f"({DUP_WINDOW}+ lines) — extract a shared function")
    return sorted(set(problems))


def check_function_length():
    problems = []
    for path in gd_files(CODE_DIRS):
        name, start, count = None, 0, 0
        for no, code in list(code_lines(path)) + [(0, "func __end__")]:
            if re.match(r"\s*(static\s+)?func\s", code) or (code and not code[0].isspace() and name):
                if name and count > MAX_FUNC_LINES:
                    problems.append(f"{rel(path)}:{start} {name}() has {count} lines (max {MAX_FUNC_LINES})")
                m = re.match(r"\s*(?:static\s+)?func\s+(\w+)", code)
                name, start, count = (m.group(1), no, 0) if m else (None, 0, 0)
            elif name and code.strip():
                count += 1
    return problems


def check_input_and_layers():
    problems = []
    for path in gd_files(CODE_DIRS):
        is_input_owner = rel(path) == "autoload/InputMode.gd"
        pure = rel(path).startswith(("logic/", "scenes/puzzles/"))
        for no, code in code_lines(path):
            if not is_input_owner and RAW_INPUT.search(code):
                problems.append(f"{rel(path)}:{no} raw key/button access — use InputMap actions")
            if pure and re.search(r"\bGameState\b", code):
                problems.append(f"{rel(path)}:{no} logic/puzzles must not touch GameState")
    return problems


CHECKS = [check_godot_pin, check_tests_mirror_logic, check_done_todos, check_spec_has_decision,
          check_magic_numbers, check_duplicates, check_function_length, check_input_and_layers]


def main():
    problems = [p for check in CHECKS for p in check()]
    for p in problems:
        print(p)
    print(f"drift: {len(problems)} problem(s)" if problems else "drift: clean")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
