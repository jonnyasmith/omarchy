-- Markup preview: hand the current buffer to the same launcher the `mp` shell
-- function calls (~/.config/omarchy/plugins/jonny.preview), which starts a
-- server for the file's directory and opens a Chromium app window Hyprland
-- tiles beside the terminal. Markdown renders through go-grip, mermaid
-- included; HTML is served as itself.
--
-- One chord for both, and the same letters as the shell name: `<Leader>mp` is
-- markup preview, `mp` is markup preview. The filetype is not in the mapping
-- because it is not a decision the person pressing the key has to make -- the
-- launcher dispatches on the extension and is the only place either renderer
-- is named.
--
-- Nothing renders in nvim. That is deliberate: foot speaks sixel and not the
-- kitty graphics protocol, and herdr composites every pane into a character
-- grid with no sixel path at any setting, so no image protocol survives from
-- nvim to the screen on this machine. A browser window is not the compromise
-- here, it is the only surface that can draw a mermaid diagram at all.
--
-- The buffer is written first, because the server reads the file from disk:
-- go-grip reloads on fsnotify, python's file server reloads on refresh, and
-- neither can see an unsaved buffer. The trade was accepted knowingly --
-- live-preview.nvim renders as you type, and leaks raw YAML frontmatter, which
-- 57% of the markdown under ~/dev has.

local launcher = vim.env.HOME .. "/.config/omarchy/plugins/jonny.preview/preview.sh"

-- The server reads the file from disk, so an unsaved buffer would preview
-- stale bytes. From neo-tree the file usually is not in a buffer at all; when
-- it is, and it is dirty, it still has to be written -- the path came from the
-- tree, not from the window, so `:write` has to be aimed at that buffer
-- explicitly.
local function write_if_dirty(path)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == path then
      local bo = vim.bo[buf]
      if bo.modified and bo.modifiable and not bo.readonly then
        vim.api.nvim_buf_call(buf, function() vim.cmd.write() end)
      end
      return
    end
  end
end

-- Both entrypoints report a failing launcher the same way, and neither decides
-- what a failure is: the launcher owns every rule about what is previewable
-- (exists, is a file, ends in .md/.html/.htm), so duplicating them here would
-- be a second copy to drift. Its stderr is surfaced instead.
local function run(args, what)
  -- Async on purpose: the launcher waits for the server's port to accept a
  -- connection before it opens the window, and blocking nvim for that is a
  -- visible stall on the first preview in a directory.
  vim.system(args, { text = true }, function(out)
    if out.code ~= 0 then
      vim.schedule(
        function() vim.notify(what .. " failed (" .. out.code .. ")\n" .. (out.stderr or ""), vim.log.levels.ERROR) end
      )
    end
  end)
end

local function preview(path)
  write_if_dirty(path)
  run({ launcher, path }, "Preview")
end

local function preview_buffer()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("Preview: buffer has no file", vim.log.levels.WARN)
    return
  end
  preview(path)
end

-- Stopping is here as well as in the shell because the servers outlive the
-- window and the terminal alike -- by design, so a preview survives the shell
-- that opened it -- and nvim is often the only thing still on screen.
local function stop_servers() run({ launcher, "--stop" }, "Stopping previews") end

-- Neo-tree's mappings are buffer-local, so the same chords shadow the buffer
-- versions above inside the tree -- which is the point: nothing new to
-- remember, and the file is never opened in a buffer just to be looked at.
local function preview_node(state)
  local node = state.tree:get_node()
  if not node then return end
  if node.type ~= "file" then
    vim.notify("Preview: not a file", vim.log.levels.WARN)
    return
  end
  preview(node.path)
end

---@type LazySpec
return {
  {
    "AstroNvim/astrocore",
    ---@param opts AstroCoreOpts
    opts = function(_, opts)
      local maps = assert(opts.mappings)
      -- Named so which-key shows the group rather than a bare key. "Markup"
      -- rather than "Markdown": one group, one chord per verb, both filetypes.
      maps.n["<Leader>m"] = { desc = "Markup" }
      maps.n["<Leader>mp"] = { preview_buffer, desc = "Preview in browser" }
      maps.n["<Leader>ms"] = { stop_servers, desc = "Stop preview servers" }
    end,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      opts.window = opts.window or {}
      opts.window.mappings = opts.window.mappings or {}
      opts.window.mappings["<Leader>mp"] = {
        preview_node,
        desc = "preview in browser",
        nowait = true,
      }
      opts.window.mappings["<Leader>ms"] = {
        stop_servers,
        desc = "stop preview servers",
        nowait = true,
      }
    end,
  },
}
