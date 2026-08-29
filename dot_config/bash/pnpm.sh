# pnpm's global bin directory. The pnpm installer appends this block to
# ~/.bashrc itself, where the next `chezmoi apply` deletes it again; here it is
# picked up by the glob source in dot_bashrc and survives.
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
*":$PNPM_HOME/bin:"*) ;;
*) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
