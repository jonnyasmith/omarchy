# Starship prompt, rendered per Omarchy theme.
#
# Starship has no `include` and, as of 1.26.0, ignores a colon-separated
# STARSHIP_CONFIG list (the multi-file PR is unmerged), so there is no
# "base config + generated theme overlay" shape like nvim's theme.lua or omp's
# omarchy-system.json. The whole config has to be the rendered artifact.
#
# omarchy-theme-set-templates substitutes the tokens below from the theme's
# colors.toml and writes this to
# ~/.local/state/omarchy/current/theme/starship.toml on every
# `omarchy theme set`. ~/.bashrc points STARSHIP_CONFIG there. No hook and no
# reload: starship is a fresh process per prompt, so the next prompt picks it
# up. There is no ~/.config/starship.toml -- do not add one back, it would be
# dead weight that STARSHIP_CONFIG overrides.
#
# Every colour here was the ANSI name `cyan` before, which already tracked the
# terminal palette through foot.ini's theme include. The point of templating is
# `accent`: a theme's chosen highlight is not always its ANSI cyan. The prompt
# stays single-hue on purpose -- this is a port of the old config, not a
# redesign. The other colors.toml keys and the `mix` function are available if
# it ever wants shades outside the 16 ANSI slots.
"$schema" = 'https://starship.rs/config-schema.json'

add_newline = true
command_timeout = 200
format = "[$directory$git_branch$git_state$git_status]($style)$status$line_break$character"
right_format = "$sudo$jobs$battery$time"

[character]
error_symbol = "[✗](bold {{ accent }})"
success_symbol = "[❯](bold {{ accent }})"

[directory]
truncation_length = 2
truncation_symbol = "…/"
# Explicit because templating cannot inherit starship's "cyan bold" default.
style = "bold {{ accent }}"
repo_root_style = "bold {{ accent }}"
repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) "
read_only = " 󰌾"

[git_branch]
format = "[$branch]($style) "
style = "italic {{ accent }}"

[git_state]
style = "bold {{ accent }}"

[git_status]
format     = '[$all_status]($style)'
style      = "{{ accent }}"
ahead      = "⇡${count} "
diverged   = "⇕⇡${ahead_count}⇣${behind_count} "
behind     = "⇣${count} "
conflicted = " "
up_to_date = " "
untracked  = "? "
modified   = " "
stashed    = ""
staged     = ""
renamed    = ""
deleted    = ""

[status]
disabled = false
format = "[$status]($style) "
style = "bold {{ accent }}"

[sudo]
disabled = false
format = "[$symbol]($style)"
symbol = "sudo "
style = "{{ accent }}"

[jobs]
format = "[$symbol$number]($style) "
style = "{{ accent }}"

[time]
disabled = false
format = "[$time]($style)"
time_format = "%H:%M"
style = "{{ accent }}"
