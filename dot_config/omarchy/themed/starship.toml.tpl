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
# Only the two colours this layout sets explicitly need tokens. Every other
# module keeps its stock ANSI-name style, which already follows the theme
# through foot.ini's palette include. The `accent` key and the `mix` function
# are there if the prompt ever wants a hue outside the 16 ANSI slots.
"$schema" = 'https://starship.rs/config-schema.json'

format = """
$os\
$username\
$hostname\
$directory\
$git_branch\
$git_commit\
$git_state\
$git_status\
$git_metrics\
$line_break\
$status\
$character"""

right_format = """
$sudo\
$jobs\
$battery\
$time\
"""

[directory]
read_only = " 󰌾"
truncation_length = 3
truncation_symbol = "…/"
truncate_to_repo = false

[git_branch]
symbol = " "

[git_metrics]
disabled = false

[git_status]
ahead = '⇡${count}'
diverged = '⇕⇡${ahead_count}⇣${behind_count}'
behind = '⇣${count}'
modified = '*'
conflicted = '!'

[username]
format = '[$user@]($style)'
style_user = 'bold dimmed {{ green }}'
style_root = 'bold {{ yellow }}'
show_always = true

[hostname]
ssh_only = false
format = '[$hostname ]($style)'
style = 'bold dimmed {{ green }}'

[os]
disabled = false

[os.symbols]
Alpaquita = " "
Alpine = " "
AlmaLinux = " "
Amazon = " "
Android = " "
Arch = " "
Artix = " "
CentOS = " "
Debian = " "
DragonFly = " "
Emscripten = " "
EndeavourOS = " "
Fedora = " "
FreeBSD = " "
Garuda = "󰛓 "
Gentoo = " "
HardenedBSD = "󰞌 "
Illumos = "󰈸 "
Kali = " "
Linux = " "
Mabox = " "
Macos = " "
Manjaro = " "
Mariner = " "
MidnightBSD = " "
Mint = " "
NetBSD = " "
NixOS = " "
OpenBSD = "󰈺 "
openSUSE = " "
OracleLinux = "󰌷 "
Pop = " "
Raspbian = " "
Redhat = " "
RedHatEnterprise = " "
RockyLinux = " "
Redox = "󰀘 "
Solus = "󰠳 "
SUSE = " "
Ubuntu = " "
Unknown = " "
Void = " "
Windows = "󰍲 "
