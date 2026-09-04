# dotfiles

My Linux dotfiles. Every config file is **symbolically linked** into place, and you
choose **which apps** each machine gets — no need to install or link everything.

```
dotfiles/
├── install.sh          # the only command you need
├── config/             #  -> ~/.config            (one folder per app)
│   ├── hypr/  waybar/  ghostty/  nvim/            (nvim is a git submodule)
│   ├── rofi/  swaync/  discord/  noctalia/  nafi/
├── home/               #  -> ~                     (per-app dotfiles)
│   ├── git/.gitconfig
│   ├── tmux/.tmux.conf
│   └── zsh/.zshrc
├── local/              #  -> ~/.local
│   └── share/nafi/     # nafi CLI helper scripts
├── system/             #  -> /                     (needs sudo)
│   └── sddm/usr/share/sddm/themes/nafi/
├── scripts/zsh.sh      # one-time zsh bootstrap
└── profiles/           # per-machine app lists (hostname) — git-ignored
```

## Why this layout?

The old layout wrapped every app in duplicate hidden folders
(`hypr/.config/hypr`, `nafi/.local/share/nafi`, ...), so browsing the repo was all
`.config` and `.local` with repeating names. Now:

- **Visible folders** — `config/`, `home/`, `local/`, `system/` hold all packages;
  the only dotted names left are the *files* that must be dashed (`./.gitconfig`).
- **Still symlinked** — `~/.config/hypr`, `~/.config/nvim`, `~/.zshrc`, etc. are all
  symbolic links back into this repo, so you edit once in git.
- **Pick per machine** — each app is independent and individually toggleable.

## Usage

```sh
./install.sh                # interactive checkbox menu, links the apps you pick
./install.sh --all          # every app (system apps still need sudo)
./install.sh hypr waybar    # just those apps, non-interactive
./install.sh --deps hypr    # also install the distro packages hypr needs
./install.sh --list         # list available apps
./install.sh --edit         # re-open the checklist next time
./install.sh -h             # help
```

With no arguments the installer opens an interactive checkbox picker (via `gum`,
which the `hypr` app already depends on): use the **arrow keys** to move, **SPACE**
to tick/untick the apps you want symlinked, type to filter, and **ENTER** to
continue. It then shows you the final ticked list and asks for confirmation
before linking anything.

**gum is optional, not required.** The core installer is pure bash + coreutils and
runs with nothing else preinstalled — on a machine without `gum` it falls back to
a plain numbered menu automatically (and on a fresh box it offers to install `gum`
for you, though you can decline and it still works). The only other tools are used
*inside specific apps*: `git` for submodules/TPM (with graceful warnings), `curl`
in `scripts/zsh.sh`, and `sudo` only for distro packages (`--deps`) or system-wide
apps like `sddm`.

### What each app maps to

| app      | links to                                                     |
|----------|--------------------------------------------------------------|
| `git`    | `~/.gitconfig`                                               |
| `tmux`   | `~/.tmux.conf` (+ TPM)                                       |
| `zsh`    | `~/.zshrc`, `~/.config/nafi/` (helpers, + oh-my-zsh setup)   |
| `nvim`   | `~/.config/nvim` (git submodule)                             |
| `hypr`   | `~/.config/hypr` (Hyprland WM ecosystem)                     |
| `waybar` | `~/.config/waybar`                                           |
| `ghostty`| `~/.config/ghostty`                                          |
| `rofi`   | `~/.config/rofi`                                             |
| `swaync` | `~/.config/swaync`                                           |
| `discord`| `~/.config/discord`                                          |
| `noctalia`| `~/.config/noctalia`                                        |
| `nafi`   | `~/.local/share/nafi` (helper scripts)                       |
| `sddm`   | `/usr/share/sddm/themes/nafi` (system-wide, needs sudo)      |

## Per-machine selection

- Pass apps as arguments, or use the interactive checklist.
- After you choose, your selection is saved to `profiles/$(hostname)` so a re-run
  on the same machine just reuses it (edit with `./install.sh --edit`).
- `profiles/` is **git-ignored**, so each computer keeps its own defaults.

## Safety

`install.sh` never overwrites a real file or directory you already own — it only
replaces symbolic links that point back into this repo (e.g. from an older layout),
and warns you to resolve anything that isn't a symlink. Remove those yourself if you
want to adopt the repo's version.

## Fresh machine

```sh
git clone --recurse-submodules <repo> ~/dotfiles
cd ~/dotfiles
./install.sh --all
```
