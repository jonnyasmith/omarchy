# Palette for the skills-sync TUI, in the active Omarchy theme. Rendered into
# ~/.local/state/omarchy/current/theme/skills-sync.env by every
# `omarchy theme set`, and sourced at launch by
# `plugins/jonny.skills/skills.sh`, which exports it into the binary's
# environment.
#
# skills-sync is a Bubble Tea TUI in ~/dev/skills-sync, i.e. one of mine, so
# unlike everything Omarchy ships it is themed by nobody. It knows these six
# variable names and nothing at all about Omarchy: the desktop's palette gets
# in through the launcher, and running the binary from a plain shell elsewhere
# still gets the 16-colour defaults it was written with.
#
# Six roles, not fifteen styles -- see theme.go, which is the only file in that
# repo allowed to know what a role is painted with.

# The cursor, the ticked rows, the focused panel border and the live source tab.
SKILLS_SYNC_ACCENT="{{ accent }}"

# `new` in the list and an inserted line in the diff: something arriving whole.
# `diverged`, and nothing else, for something being overwritten. The theme's own
# green and yellow rather than a mix, because these are the distinction
# `git status` draws and a status word is a label, not body text.
SKILLS_SYNC_ADDED="{{ green }}"
SKILLS_SYNC_CHANGED="{{ yellow }}"

# Deleted files, deleted diff lines, and every error. The theme's red, so a
# warning still reads as a warning in a palette whose accent is itself reddish.
SKILLS_SYNC_REMOVED="{{ red }}"

# Diff hunk headers: structure rather than content.
SKILLS_SYNC_META="{{ blue }}"

# Idle borders, idle tabs and the footer keybinding legend. A mix rather than
# `muted` for the same reason FZF_THEME_DIM is one: the footer is the only place
# the keys are written down, so it has to be readable, and `muted` is whatever
# each theme calls furniture -- in Nord a #4c566a border colour on a #2e3440
# background, through a 0.9-alpha terminal.
#
# This replaces the binary's own fallback, which is the terminal's faint
# attribute. Faint is a relationship rather than a colour, which is the right
# default for an unthemed terminal and worse than a mix everywhere else.
SKILLS_SYNC_DIM="{{ mix background foreground 60% }}"
