# powerline

A small powerline-style shell prompt written in [V](https://vlang.io).

Shows the time, `user@host`, the current directory, the git branch, and `$` (or `#` for
root). Needs a Powerline or Nerd font for the separator glyphs.

## Build

```sh
v -prod -o powerline .
v test .
```

## Install

Add to `~/.bashrc` (use the path where you keep the binary):

```sh
eval "$(/path/to/powerline init bash)"
```

`init zsh` and `init fish` are also available (`powerline init fish | source`).

## Configure

```sh
mkdir -p ~/.config/powerline
powerline config > ~/.config/powerline/config.toml
```

Every key is optional; anything left out keeps its default. See
[default.toml](default.toml) for all of them. For example, to hide the host, show
`~` instead of the house icon, and keep only the last two directories:

```toml
[user]
show_host = false

[dir]
home_symbol = "~"
max_depth = 2
```

To show only the first and the last folder of a long path
(`~/Development/.../powerline`):

```toml
[dir]
keep_first = 1
max_depth = 1
```

To separate folders with a powerline chevron instead of `/`:

```toml
[dir]
separator = " \ue0b1 "
```

The glyph between sections is `separator` at the top level.

To drop a segment entirely, or reorder them, edit `segments`:

```toml
segments = ["user", "dir", "git", "prompt"]   # no clock
```

`$POWERLINE_CONFIG` overrides the config file location. Changes apply on the
next prompt.
