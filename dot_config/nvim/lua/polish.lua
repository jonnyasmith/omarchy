-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- Route the system clipboard over OSC 52 when this session's yanks have to
-- reach another machine (ssh, tmux, `herdr --remote`). A no-op in a plain
-- local session, where neovim's own wl-copy/wl-paste detection is correct.
require("remote_clipboard").setup()
