#!/usr/bin/env python3
"""Replace hardcoded Battly palette colors with theme-aware references."""
from __future__ import annotations

import re
from pathlib import Path

LIB = Path(__file__).resolve().parent.parent / "lib"

SKIP = {
    "core/theme/battly_theme.dart",
    "services/theme_service.dart",
}

REPLACEMENTS = [
    (r"const Color\(0xFF0F1115\)", "context.battlyScaffold"),
    (r"const Color\(0xFF07080A\)", "context.battly.navBar"),
    (r"const Color\(0xFF15181E\)", "context.battlyCard"),
    (r"const Color\(0xFF1A1D24\)", "context.battly.elevatedSurface"),
    (r"const Color\(0xFF2B2F3A\)", "context.battlyBorder"),
    (r"const Color\(0xFFA0A0A0\)", "context.battlyMuted"),
]

IMPORT_LINE = "import 'package:app/core/theme/battly_theme.dart';\n"
REL_IMPORT = "import '../core/theme/battly_theme.dart';\n"

# Also fix common text colors in poppins (only when clearly body/title text)
TEXT_REPLACEMENTS = [
    (
        r"GoogleFonts\.poppins\(\s*color: Colors\.white",
        "GoogleFonts.poppins(color: context.battlyOnSurface",
    ),
    (
        r"style: GoogleFonts\.poppins\(\s*color: Colors\.white",
        "style: GoogleFonts.poppins(color: context.battlyOnSurface",
    ),
]


def relative_import(file_path: Path) -> str:
    rel = file_path.relative_to(LIB).as_posix()
    depth = rel.count("/")
    prefix = "../" * depth
    return f"import '{prefix}core/theme/battly_theme.dart';\n"


def strip_outer_const(content: str) -> str:
    """Remove const from widgets that now contain non-const color expressions."""
    patterns = [
        (r"const (BoxDecoration\()", r"\1"),
        (r"const (Scaffold\()", r"\1"),
        (r"const (Container\()", r"\1"),
        (r"const (Border\()", r"\1"),
        (r"const (BorderSide\()", r"\1"),
        (r"const (Divider\()", r"\1"),
        (r"const (Icon\([^)]*color: context\.)", r"\1"),
    ]
    for pat, repl in patterns:
        content = re.sub(pat, repl, content)
    return content


def process_file(path: Path) -> bool:
    rel = path.relative_to(LIB).as_posix()
    if rel in SKIP:
        return False

    original = path.read_text(encoding="utf-8")
    content = original

    for pat, repl in REPLACEMENTS + TEXT_REPLACEMENTS:
        content = re.sub(pat, repl, content)

    if content == original:
        return False

    content = strip_outer_const(content)

    if "context.battly" in content or "context.battlyScaffold" in content or "context.battlyOnSurface" in content:
        if "battly_theme.dart" not in content:
            imp = relative_import(path)
            # insert after last import
            m = list(re.finditer(r"^import .+?;\n", content, re.M))
            if m:
                insert_at = m[-1].end()
                content = content[:insert_at] + imp + content[insert_at:]
            else:
                content = imp + content

    path.write_text(content, encoding="utf-8")
    return True


def main() -> None:
    changed = 0
    for path in sorted(LIB.rglob("*.dart")):
        if process_file(path):
            changed += 1
            print(f"updated: {path.relative_to(LIB)}")
    print(f"Done. {changed} files updated.")


if __name__ == "__main__":
    main()
