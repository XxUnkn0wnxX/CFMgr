#!/usr/bin/env python3
"""Check planning consistency only; this gate provides no runtime acceptance."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
SUBGOAL = re.compile(r"^S([0-9]{2})\.([0-9]{2})$")
SPEC_ROW = re.compile(r"^\|\s*(S[0-9]{2}\.[0-9]{2})\s*\|\s*([^|]+?)\s*\|\s*(.*?)\s*\|$")
CHECKLIST_ROW = re.compile(
    r"^\|\s*\[[ xX]\]\s*\|\s*\[[ xX]\]\s*\|\s*"
    r"(S[0-9]{2}\.[0-9]{2})\s*\|\s*\*\*(.+?):\*\*\s*(.*?)\s*\|$"
)
SPEC_ID_ROW = re.compile(r"^\|\s*S[0-9]{2}\.[0-9]{2}\s*\|")
CHECKLIST_ID_ROW = re.compile(
    r"^\|\s*\[[ xX]\]\s*\|\s*\[[ xX]\]\s*\|\s*S[0-9]{2}\.[0-9]{2}\s*\|"
)
CHECKED_SUBGOAL = re.compile(
    r"^\|\s*\[([xX ])\]\s*\|\s*\[([xX ])\]\s*\|\s*(S[0-9]{2}\.[0-9]{2})\s*\|"
)
GOAL_HEADING = re.compile(r"^##\s+(\d{1,2})\.\s+(.+?)\s*$")
CHECK_GOAL_HEADING = re.compile(r"^###\s+(\d{1,2})\.\s+(.+?)\s*$")
INLINE_LINK = re.compile(r"!?\[[^\]\n]*\]\(\s*(<[^>\n]+>|[^)\s]+)(?:\s+[^)]*)?\)")
PERSONAL_HOME = re.compile(rb"(?<![A-Za-z0-9])/(?:Users|home)/[A-Za-z0-9._-]+")
IGNORED_DIRS = {
    ".git",
    ".old",
    ".tmp",
    ".venv",
    ".pytest_cache",
    ".ruff_cache",
    "__pycache__",
    "node_modules",
}
PLACEHOLDERS = {
    "modules/helpers/.gitkeep",
    "modules/hooks/.gitkeep",
    "modules/lib/.gitkeep",
    "tests/.gitkeep",
}
FORBIDDEN_RUNTIME_PATHS = ("cfmgr.sh", "catalog.txt", "package.manifest")


def _read(root: Path, relative: str, errors: list[str]) -> str | None:
    path = root / relative
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        errors.append(f"cannot read {relative}: {error}")
        return None


def _rows(
    document: str,
    pattern: re.Pattern[str],
    row_start: re.Pattern[str],
    label: str,
) -> tuple[dict[str, tuple[str, str]], list[str]]:
    rows: dict[str, tuple[str, str]] = {}
    errors: list[str] = []
    for number, line in enumerate(document.splitlines(), 1):
        if row_start.match(line.strip()) is None:
            continue
        match = pattern.fullmatch(line.strip())
        if match is None:
            errors.append(f"{label}:{number}: malformed subgoal row")
            continue
        identifier, title, requirement = (part.strip() for part in match.groups())
        if SUBGOAL.fullmatch(identifier) is None:
            errors.append(f"{label}:{number}: invalid subgoal ID {identifier!r}")
        if identifier in rows:
            errors.append(f"{label}:{number}: duplicate subgoal ID {identifier}")
        else:
            rows[identifier] = (title, requirement)
    return rows, errors


def _goal_sections(
    document: str, pattern: re.Pattern[str], label: str
) -> tuple[dict[int, str], list[str]]:
    sections: dict[int, str] = {}
    errors: list[str] = []
    for number, line in enumerate(document.splitlines(), 1):
        match = pattern.fullmatch(line.strip())
        if match is None:
            continue
        goal, title = int(match.group(1)), match.group(2).strip()
        if goal > 16:
            continue
        if goal in sections:
            errors.append(f"{label}:{number}: duplicate main goal section {goal}")
        else:
            sections[goal] = title
    expected = set(range(1, 17))
    if set(sections) != expected:
        missing = sorted(expected - set(sections))
        extra = sorted(set(sections) - expected)
        errors.append(
            f"{label}: expected main goals 1-16 (missing={missing}, extra={extra})"
        )
    return sections, errors


def _active_markdown(root: Path) -> list[Path]:
    documents: list[Path] = []
    for directory, names, filenames in os.walk(root):
        base = Path(directory)
        names[:] = sorted(
            name
            for name in names
            if name not in IGNORED_DIRS and not (base / name).is_symlink()
        )
        documents.extend(
            base / name
            for name in sorted(filenames)
            if name.endswith((".md", ".markdown")) and not (base / name).is_symlink()
        )
    return sorted(documents)


def _link_destination(raw: str) -> str:
    destination = raw[1:-1] if raw.startswith("<") and raw.endswith(">") else raw
    return unquote(destination)


def _readme_goal_links(text: str) -> set[int]:
    goals: set[int] = set()
    in_goal_table = False
    for line in text.splitlines():
        if re.match(r"^##\s+.*Planned product goals\s*$", line):
            in_goal_table = True
            continue
        if in_goal_table and line.startswith("## "):
            break
        if not in_goal_table:
            continue
        for match in INLINE_LINK.finditer(line):
            parsed = urlsplit(_link_destination(match.group(1)))
            if parsed.path == "PLAN_V2.md":
                goal = re.match(r"([0-9]{1,2})-", parsed.fragment)
                if goal:
                    goals.add(int(goal.group(1)))
    return goals


def _markdown_checks(root: Path, errors: list[str]) -> None:
    documents = _active_markdown(root)
    goal_readme = root / "README.md"
    readme_text: str | None = None
    for document in documents:
        relative = document.relative_to(root).as_posix()
        try:
            content = document.read_bytes()
            text = content.decode("utf-8")
        except (OSError, UnicodeError) as error:
            errors.append(f"cannot read active Markdown {relative}: {error}")
            continue
        if PERSONAL_HOME.search(content):
            errors.append(f"{relative}: contains a literal personal home path")
        if document == goal_readme:
            readme_text = text
        text = re.sub(r"(?ms)^\s*(```|~~~).*?^\s*\1\s*$", "", text)
        for match in INLINE_LINK.finditer(text):
            target = _link_destination(match.group(1))
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            relative_target = Path(parsed.path)
            if relative_target.is_absolute():
                relative_target = Path(*relative_target.parts[1:])
            target_path = (document.parent / relative_target).resolve()
            try:
                target_path.relative_to(root.resolve())
            except ValueError:
                errors.append(
                    f"{relative}: local link escapes the repository: {target}"
                )
                continue
            if not target_path.exists():
                errors.append(f"{relative}: local link target is missing: {target}")
    goals_covered = _readme_goal_links(readme_text or "")
    if goals_covered != set(range(1, 17)):
        missing = sorted(set(range(1, 17)) - goals_covered)
        errors.append(
            f"README.md: planned-goal table must link all 16 main goals (missing={missing})"
        )


def _current_code(root: Path, errors: list[str]) -> bool:
    found = False
    for relative in FORBIDDEN_RUNTIME_PATHS:
        path = root / relative
        if path.exists() or path.is_symlink():
            errors.append(
                f"{relative}: runtime/package entry is not allowed in the planning-only baseline"
            )
            found = True
    for relative in ("modules", "tests"):
        directory = root / relative
        if not directory.exists():
            continue
        if directory.is_symlink() or not directory.is_dir():
            errors.append(
                f"{relative}: expected a real directory containing placeholders only"
            )
            found = True
            continue
        for current, names, filenames in os.walk(directory):
            parent = Path(current)
            names[:] = sorted(
                name for name in names if name not in {"__pycache__", ".pytest_cache"}
            )
            for name in names:
                child = parent / name
                if child.is_symlink():
                    errors.append(
                        f"{child.relative_to(root)}: runtime symlink is not allowed"
                    )
                    found = True
            for name in filenames:
                child = parent / name
                path_name = child.relative_to(root).as_posix()
                if name == ".DS_Store" or name.endswith((".pyc", ".pyo")):
                    continue
                if (
                    path_name in PLACEHOLDERS
                    and child.is_file()
                    and not child.is_symlink()
                    and child.stat().st_size == 0
                ):
                    continue
                errors.append(
                    f"{path_name}: non-placeholder code/data is not allowed in the planning-only baseline"
                )
                found = True
    return found


def validate(root: Path) -> list[str]:
    """Return planning-only contract failures without invoking external tools."""
    errors: list[str] = []
    specification = _read(root, "PLAN_V2.md", errors)
    checklist = _read(root, "PLAN_V2_checklist.md", errors)
    readme = _read(root, "README.md", errors)
    if specification is not None:
        spec_rows, row_errors = _rows(
            specification, SPEC_ROW, SPEC_ID_ROW, "PLAN_V2.md"
        )
        errors.extend(row_errors)
        if len(spec_rows) != 156:
            errors.append(
                f"PLAN_V2.md: expected 156 unique subgoals, found {len(spec_rows)}"
            )
        _, section_errors = _goal_sections(specification, GOAL_HEADING, "PLAN_V2.md")
        errors.extend(section_errors)
    else:
        spec_rows = {}
    if checklist is not None:
        checklist_rows, row_errors = _rows(
            checklist, CHECKLIST_ROW, CHECKLIST_ID_ROW, "PLAN_V2_checklist.md"
        )
        errors.extend(row_errors)
        for number, line in enumerate(checklist.splitlines(), 1):
            match = CHECKED_SUBGOAL.match(line.strip())
            if match and (match.group(1).strip() or match.group(2).strip()):
                errors.append(
                    f"PLAN_V2_checklist.md:{number}: product subgoals must remain unchecked "
                    "while this planning-only baseline contains no runtime"
                )
        if len(checklist_rows) != 156:
            errors.append(
                f"PLAN_V2_checklist.md: expected 156 unique subgoals, found {len(checklist_rows)}"
            )
        _, section_errors = _goal_sections(
            checklist, CHECK_GOAL_HEADING, "PLAN_V2_checklist.md"
        )
        errors.extend(section_errors)
    else:
        checklist_rows = {}
    if spec_rows != checklist_rows:
        for identifier in sorted(set(spec_rows) | set(checklist_rows)):
            if spec_rows.get(identifier) != checklist_rows.get(identifier):
                errors.append(
                    f"subgoal content differs between specification and checklist: {identifier}"
                )
    if readme is not None:
        _markdown_checks(root, errors)
    code_found = _current_code(root, errors)
    if code_found:
        errors.append(
            "Before delivering code, replace this planning-only gate with meaningful focused and full "
            "runtime tests, including required BusyBox/platform coverage."
        )
    return errors


def main() -> int:
    if sys.version_info < (3, 11):
        print("Planning checks require Python 3.11 or newer.", file=sys.stderr)
        return 2
    errors = validate(ROOT)
    if errors:
        print("Planning-only checks failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(
        "Planning consistency passed: 156 aligned subgoals, 16 README goal links, "
        "active document links/privacy, and planning-only inventory. No runtime acceptance was performed."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
