#!/usr/bin/env python3
"""Give pi's fullscreen TUI a solid, app-wide background (opencode style).

pi draws on the terminal's default background, so a transparent terminal shows through
everything that is not a tool card. There is no theme token or extension hook for a global
backdrop, so this patches pi-tui's alternate-screen frame writer in the installed release:

  * each frame row is written with the background colour set before the erase-line sequence
    (background-colour-erase), and any short row is filled to the full width with the same
    background, so it works even where BCE is disabled (e.g. some tmux configs),
  * entering the alternate screen clears with the background already set,
  * the background is reset after each frame.

Only the fullscreen (`tuiMode: "fullscreen"`) path is patched; regular mode is untouched.

The colour comes from `PI_APP_BG` at runtime (default #16181c). Re-apply after `pi update`:

    ~/.pi/agent/scripts/cc-app-background.py                     # patch current release
    ~/.pi/agent/scripts/cc-app-background.py --check             # status only
    ~/.pi/agent/scripts/cc-app-background.py --bg '#0f1115'      # bake another default
    PI_APP_BG='#1e1f22' pi                                      # override at runtime
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

MARKER = "CC_APP_BACKGROUND"
DEFAULT_BG = "#16181c"
AGENT_DIR = Path.home() / ".pi" / "agent"

TARGET = "node_modules/@earendil-works/pi-tui/dist/tui-alt-screen.js"

HELPERS = f"""// {MARKER}: solid app-wide backdrop, see ~/.pi/agent/scripts/cc-app-background.py.
const CC_APP_BG = (() => {{
    const hex = process.env.PI_APP_BG ?? "{DEFAULT_BG}";
    const match = /^#([0-9a-fA-F]{{6}})$/.exec(hex);
    if (!match)
        return "";
    const value = Number.parseInt(match[1], 16);
    return `\\x1b[48;2;${{(value >> 16) & 255}};${{(value >> 8) & 255}};${{value & 255}}m`;
}})();
const CC_APP_RESET = "\\x1b[49m";
/** Fill the rest of a row with the app background so the backdrop holds without BCE. */
function ccBgFill(line, width) {{
    if (isImageLine(line))
        return "";
    const missing = width - visibleWidth(line);
    return missing > 0 ? `${{CC_APP_BG}}${{" ".repeat(missing)}}` : "";
}}
"""

REPLACEMENTS = [
    # 1. clear on entering the alternate screen
    (
        '${this.mouseEnabled ? mouseSequence : ""}\\x1b[2J\\x1b[H\\x1b[?25l`',
        '${this.mouseEnabled ? mouseSequence : ""}${CC_APP_BG}\\x1b[2J\\x1b[H\\x1b[?25l`',
    ),
    # 2. full redraw clears
    (
        "buffer += `${clearImages}\\x1b[2J`;",
        "buffer += `${clearImages}${CC_APP_BG}\\x1b[2J`;",
    ),
    (
        'buffer += "\\x1b[2J";',
        'buffer += `${CC_APP_BG}\\x1b[2J`;',
    ),
    # 3. row erases in the image-last path
    (
        "buffer += `\\x1b[${row + 1};1H\\x1b[2K`;",
        "buffer += `\\x1b[${row + 1};1H${CC_APP_BG}\\x1b[2K`;",
    ),
    # 4. text rows in the image-last path
    (
        'buffer += `\\x1b[${row + 1};1H${preparedKittyScreen.lines[row] ?? ""}`;',
        'buffer += `\\x1b[${row + 1};1H${CC_APP_BG}${preparedKittyScreen.lines[row] ?? ""}'
        '${ccBgFill(preparedKittyScreen.lines[row] ?? "", width)}`;',
    ),
    # 5. the normal text row
    (
        'buffer += `\\x1b[${row + 1};1H\\x1b[2K${preparedKittyScreen.lines[row] ?? ""}`;',
        'buffer += `\\x1b[${row + 1};1H${CC_APP_BG}\\x1b[2K${preparedKittyScreen.lines[row] ?? ""}'
        '${ccBgFill(preparedKittyScreen.lines[row] ?? "", width)}`;',
    ),
    # 6. reset once the frame is written
    (
        "buffer += END_SYNCHRONIZED_OUTPUT;\n        this.terminal.write(buffer);",
        "buffer += `${CC_APP_RESET}${END_SYNCHRONIZED_OUTPUT}`;\n        this.terminal.write(buffer);",
    ),
]

ANCHOR = 'const ENTER_ALT_SCREEN = "\\x1b[?1049h";'


def release_dir() -> Path:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if args and not args[0].startswith("#"):
        return Path(args[0]).expanduser()
    version = (AGENT_DIR / "install" / "current-version").read_text().strip()
    return AGENT_DIR / "install" / "releases" / version


def baked_bg() -> str:
    for index, arg in enumerate(sys.argv[1:]):
        if arg == "--bg" and index + 2 <= len(sys.argv[1:]):
            return sys.argv[1:][index + 1]
        if arg.startswith("--bg="):
            return arg.split("=", 1)[1]
    return DEFAULT_BG


def patch(source: str) -> str:
    if MARKER in source:
        raise SystemExit("already patched")
    if ANCHOR not in source:
        raise SystemExit("anchor not found: pi-tui layout changed; patch manually")

    helpers = HELPERS
    bg = baked_bg()
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", bg):
        raise SystemExit(f"invalid --bg value: {bg}")
    helpers = helpers.replace(DEFAULT_BG, bg)

    for old, new in REPLACEMENTS:
        if old not in source:
            raise SystemExit(f"anchor not found (pi-tui shape changed): {old[:60]}")
        source = source.replace(old, new, 1)

    return source.replace(ANCHOR, helpers + ANCHOR, 1)


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

    target.write_text(patch(source))
    print(f"patched: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
