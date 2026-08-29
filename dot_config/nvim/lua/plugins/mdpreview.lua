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

local function preview()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("Markdown preview: buffer has no file", vim.log.levels.WARN)
    return
  end
  if vim.bo.modified and vim.bo.modifiable and not vim.bo.readonly then vim.cmd.write() end

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

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@param opts AstroCoreOpts
  opts = function(_, opts)
    local maps = assert(opts.mappings)
    -- Named so which-key shows the group rather than a bare key.
    maps.n["<Leader>m"] = { desc = "Markdown" }
    maps.n["<Leader>mp"] = { preview, desc = "Preview in browser" }
  end,
}
