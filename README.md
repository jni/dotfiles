:warning: this is just slop, don't read it, find me on Zulip or whatever :warning:

# dotfiles

Personal config files for zsh, bash, fish, Ghostty, Neovim, git, COSMIC, Sway,
starship, and keyd, managed by a single dependency-free Python script, `dots`.

## Layout

```
dotfiles/
├── dots                        # the manager itself - lives at the repo root
├── zsh/zshrc                   # ~/.zshrc
├── bash/bashrc                 # ~/.bashrc
├── fish/config.fish            # ~/.config/fish/config.fish
├── fish/fish_plugins           # ~/.config/fish/fish_plugins
├── ghostty/config.ghostty      # ~/.config/ghostty/config.ghostty
├── nvim/                       # ~/.config/nvim
├── git/gitconfig               # ~/.gitconfig
├── cosmic/xkb_config           # ~/.config/cosmic/com.system76.CosmicComp/v1/xkb_config
├── cosmic/custom-shortcuts     # ~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom
├── cosmic/system-actions       # ~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/system_actions
├── sway/                       # ~/.config/sway
├── starship/starship.toml      # ~/.config/starship.toml
├── keyd/default.conf           # /etc/keyd/default.conf
└── backups/                    # created automatically by `dots install`, gitignore-able
```

## Commands

```bash
./dots collect [--dry-run]   # system  -> repo   (copy current configs in)
./dots install [--dry-run]   # repo    -> system  (symlink configs into place)
./dots check                 # show install status of every tracked item
./dots diff [timestamp]      # compare a backup snapshot against the repo
./dots diff --list           # list available backup snapshots
```

`collect` and `install` print exactly what they're about to do under
`--dry-run`, with no changes made — worth running first any time you're
unsure what will happen.

## First-time setup

```bash
mkdir -p ~/dotfiles && cd ~/dotfiles
git init
# put `dots` in here, then:
chmod +x dots          # note: the executable bit may not survive
                        # download/transfer - this step is normal
./dots collect
git add -A
git commit -m "initial dotfiles"
git remote add origin <your-repo-url>
git push -u origin main
```

## On a new machine

```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
chmod +x dots
./dots install
```

Each tracked file/directory becomes a symlink pointing into the repo
(e.g. `~/.config/nvim` -> `~/dotfiles/nvim`). Anything that was already
sitting at that path gets moved into `backups/<timestamp>/...` inside
the repo first — nothing is ever silently overwritten or deleted.

## Keeping it in sync

Once installed, your real configs *are* the repo files (via the
symlinks), so editing `~/.config/sway/config` day-to-day is editing the
repo directly. Just remember to commit:

```bash
cd ~/dotfiles && git add -A && git commit -m "tweak sway config"
```

`collect` is mainly useful for the first run, or any time you've edited
a file outside the symlink (e.g. restored from a backup) and want to
pull it back into the repo.

## Checking status / recovering from a backup

```bash
./dots check          # what's linked, what's not, what differs
./dots diff --list    # see available backup snapshots
./dots diff            # diff the most recent backup against the repo
./dots diff 20260620-073535   # diff a specific snapshot
```

`diff` is for the case where `install` backed something up (because a
real file was sitting where a symlink was about to go) and you want to
see exactly what was in it versus what's there now.

## Adding or removing tracked files

Edit the `DOTFILES_MAP` dictionary near the top of `dots`.

## Notes / things worth reviewing before your first commit

- **`cosmic/`** tracks three specific files (keyboard layout, custom
  shortcuts, and system-action overrides) rather than the entire
  `~/.config/cosmic` tree. COSMIC spreads state across many per-component
  subfolders; only these three have been singled out as worth versioning.
- Consider adding `backups/` to `.gitignore` — those are local safety
  snapshots, not really meant for version control.
