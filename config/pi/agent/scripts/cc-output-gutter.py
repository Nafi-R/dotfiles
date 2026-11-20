#!/usr/bin/env python3
"""Add a left gutter bar to assistant answer blocks in pi's TUI.

pi renders assistant *text* through `AssistantMessageComponent` with a plain Markdown
component, so there is no theme token or extension hook for giving answers a marker.
This script patches the installed release file to wrap answer blocks in a small
`OutputGutter` component that draws `▍ ` on every line (thinking blocks are untouched).

The patch is idempotent and only touches markdown blocks of kind "text".
`pi update` installs a fresh release, so run this again after updating:

    ~/.pi/agent/scripts/cc-output-gutter.py

Pass `--check` to report status without writing, or an explicit release dir as an argument.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

MARKER = "CC_OUTPUT_GUTTER"
AGENT_DIR = Path.home() / ".pi" / "agent"

TARGET = "node_modules/@earendil-works/pi-coding-agent/dist/modes/interactive/components/assistant-message.js"

GUTTER_CLASS = f"""// {MARKER}: assistant answer blocks get a left bar so they read apart from thinking.
class OutputGutter {{
    constructor(inner, theme) {{
        this.inner = inner;
        this.theme = theme;
    }}
    setText(text) {{
        this.inner.setText(text);
    }}
    invalidate() {{
        this.inner.invalidate();
    }}
    render(width) {{
        const bar = `${{this.theme.fg("muted", "\\u258d")}} `;
        const innerWidth = Math.max(1, width - 2);
        return this.inner.render(innerWidth).map((line) => bar + line);
    }}
}}
"""

ANCHOR = "const OSC133_ZONE_START"

OPEN_FROM = 'markdownBlock("text", text, () => new Markdown(text, this.outputPad, 0, this.markdownTheme, undefined, {'
OPEN_TO = 'markdownBlock("text", text, () => new OutputGutter(new Markdown(text, this.outputPad, 0, this.markdownTheme, undefined, {'

CLOSE_RE = re.compile(
    r'(\n\s*transform: createMarkdownTransform\("assistant", \(\) => this\.isStreaming, this\.markdownTransformers, this\.messageId, this\.timestamp\),\n\s*)\}\)\)\);'
)


def release_dir() -> Path:
    if len(sys.argv) > 1 and not sys.argv[1].startswith("-"):
        return Path(sys.argv[1]).expanduser()
    version = (AGENT_DIR / "install" / "current-version").read_text().strip()
    return AGENT_DIR / "install" / "releases" / version


def patched(source: str) -> str:
    if MARKER in source:
        raise SystemExit("already patched")
    if OPEN_FROM not in source:
        raise SystemExit("anchor not found: pi's assistant-message.js changed shape; patch manually")
    source = source.replace(OPEN_FROM, OPEN_TO, 1)
    source, count = CLOSE_RE.subn(r"\1}), theme)));", source, count=1)
    if count != 1:
        raise SystemExit("closing anchor not found; patch manually")
    return source.replace(ANCHOR, GUTTER_CLASS + ANCHOR, 1)


def main() -> int:
    target = release_dir() / TARGET
    if not target.is_file():
        print(f"not found: {target}", file=sys.stderr)
        return 1
    source = target.read_text()

    if MARKER in source:
        print(f"already patched: {target}")
        return 0
    if "--check" in sys.argv:
        print(f"not patched: {target}")
        return 0

    target.write_text(patched(source))
    print(f"patched: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
