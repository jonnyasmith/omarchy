-- Markdown preview: hand the current buffer to the same launcher the `mdp`
-- shell function calls (~/.config/omarchy/plugins/jonny.mdpreview), which starts
-- go-grip and opens a Chromium app window Hyprland tiles beside the terminal.
--
-- Nothing renders in nvim. That is deliberate: foot speaks sixel and not the
-- kitty graphics protocol, and herdr composites every pane into a character
-- grid with no sixel path at any setting, so no image protocol survives from
-- nvim to the screen on this machine. A browser window is not the compromise
-- here, it is the only surface that can draw a mermaid diagram at all.
--
-- The buffer is written first, because go-grip watches the file: reload is
-- fsnotify on the directory, so an unsaved buffer would preview stale bytes.
-- The trade was accepted knowingly -- live-preview.nvim renders as you type,
-- and leaks raw YAML frontmatter, which 57% of the markdown under ~/dev has.

local launcher = vim.env.HOME .. "/.config/omarchy/plugins/jonny.mdpreview/mdpreview.sh"

-- go-grip watches the file on disk, so an unsaved buffer would preview stale
-- bytes. From neo-tree the file usually is not in a buffer at all; when it is,
-- and it is dirty, it still has to be written -- the path came from the tree,
-- not from the window, so `:write` has to be aimed at that buffer explicitly.
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

-- The launcher owns every rule about what is previewable (exists, is a file,
-- ends in .md); duplicating them here would be a second copy to drift. Its
-- stderr is surfaced instead.
local function preview(path)
  write_if_dirty(path)

  -- Async on purpose: the launcher waits for the server's port to accept a
  -- connection before it opens the window, and blocking nvim for that is a
  -- visible stall on the first preview in a directory.
  vim.system({ launcher, path }, { text = true }, function(out)
    if out.code ~= 0 then
      vim.schedule(
        function()
          vim.notify("Markdown preview failed (" .. out.code .. ")\n" .. (out.stderr or ""), vim.log.levels.ERROR)
        end
      )
    end
  end)
end

local function preview_buffer()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("Markdown preview: buffer has no file", vim.log.levels.WARN)
    return
  end
  preview(path)
end

-- Neo-tree's mappings are buffer-local, so the same chord shadows the buffer
-- version above inside the tree -- which is the point: nothing new to remember,
-- and the file is never opened in a buffer just to be looked at.
local function preview_node(state)
  local node = state.tree:get_node()
  if not node then return end
  if node.type ~= "file" then
    vim.notify("Markdown preview: not a file", vim.log.levels.WARN)
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
      -- Named so which-key shows the group rather than a bare key.
      maps.n["<Leader>m"] = { desc = "Markdown" }
      maps.n["<Leader>mp"] = { preview_buffer, desc = "Preview in browser" }
    end,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      opts.window = opts.window or {}
      opts.window.mappings = opts.window.mappings or {}
      opts.window.mappings["<Leader>mp"] = {
        preview_node,
        desc = "markdown preview in browser",
        nowait = true,
      }
    end,
  },
}
