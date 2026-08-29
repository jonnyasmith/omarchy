-- Window splits on <Leader>h and <Leader>v instead of AstroNvim's bare `\`
-- and `|`, which name no axis and sit on the wrong hand.
--
-- `<Leader>h` was the Snacks dashboard, so it moves to `<Leader>H`. The
-- mapping table is moved rather than rewritten, which keeps upstream's
-- toggle behaviour -- pressing it on the dashboard closes it again -- and
-- its description, so which-key still reads "Home Screen".

---@type LazySpec
return {
  {
    "AstroNvim/astrocore",
    ---@param opts AstroCoreOpts
    opts = function(_, opts)
      local maps = assert(opts.mappings)
      maps.n["<Leader>H"] = maps.n["<Leader>h"]
      maps.n["<Leader>h"] = { "<Cmd>split<CR>", desc = "Horizontal split" }
      maps.n["<Leader>v"] = { "<Cmd>vsplit<CR>", desc = "Vertical split" }
      maps.n["|"] = false
      maps.n["\\"] = false
    end,
  },
}
