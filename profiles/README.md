# profiles/

Each machine in your fleet gets its own app list, named after its hostname.

When you run `./install.sh` interactively it writes the apps you pick to
`profiles/$(hostname)` and reuses them on later runs (override with `--edit`).

This directory is git-ignored on purpose — which apps a machine needs is personal
to that machine.
