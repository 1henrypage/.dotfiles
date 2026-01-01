
command_exists () {
  hash "$1" 2> /dev/null
}

alias_not_used () {
  ! alias "$1" >/dev/null && ! hash "$1" 2> /dev/null
}

if alias_not_used a; then; alias a='alias'; fi
if alias_not_used c; then; alias c='clear'; fi
if alias_not_used e; then; alias e='exit'; fi
if alias_not_used f; then; alias f='find'; fi
if alias_not_used g; then; alias g='grep'; fi
if alias_not_used h; then; alias h='history'; fi
if alias_not_used i; then; alias i='id'; fi
if alias_not_used j; then; alias j='jobs'; fi
if alias_not_used l; then; alias l='ls'; fi
if alias_not_used m; then; alias m='man'; fi
if alias_not_used n; then; alias n='nc'; fi
if alias_not_used p; then; alias p='pwd'; fi
if alias_not_used s; then; alias s='sudo'; fi
if alias_not_used t; then; alias t='touch'; fi
if alias_not_used v; then; alias v='vim'; fi

# File listing options
alias lr='ls -R' # List files in sub-directories, recursivley

# List contents of packed file, depending on type
ls-archive () {
  if [ -z "$1" ]; then
    echo "No archive specified"
    return;
  fi
  if [[ ! -f $1 ]]; then
    echo "File not found"
    return;
  fi
  ext="${1##*.}"
  if [ $ext = 'zip' ]; then
    unzip -l $1
  elif [ $ext = 'rar' ]; then
    unrar l $1
  elif [ $ext = 'tar' ]; then
    tar tf $1
  elif [ $ext = 'tar.gz' ]; then
    echo $1
  elif [ $ext = 'ace' ]; then
    unace l $1
  else
    echo "Unknown Archive Format"
  fi
}

alias lz='ls-archive'

# Make directory, and cd into it
mkcd() {
  local dir="$*";
  mkdir -p "$dir" && cd "$dir";
}

# Make dir and copy
mkcp() {
  local dir="$2"
  local tmp="$2"; tmp="${tmp: -1}"
  [ "$tmp" != "/" ] && dir="$(dirname "$2")"
  [ -d "$dir" ] ||
    mkdir -p "$dir" &&
    cp -r "$@"
}

# Move dir and move into it
mkmv() {
  local dir="$2"
  local tmp="$2"; tmp="${tmp: -1}"
  [ "$tmp" != "/" ] && dir="$(dirname "$2")"
  [ -d "$dir" ] ||
      mkdir -p "$dir" &&
      mv "$@"
}

alias cg='cd `git rev-parse --show-toplevel`' # Base of git project

# Finding files and directories
alias dud='du -d 1 -h' # List sizes of files within directory
alias duf='du -sh *' # List total size of current directory
alias ff='find . -type f -name' # Find a file by name within current directory
(( $+commands[fd] )) || alias fd='find . -type d -name' # Find direcroy by name

# Command line history
alias h='history' # Shows full history
alias h-search='fc -El 0 | grep' # Searchses for a word in terminal history
alias top-history='history 0 | awk '{print $2}' | sort | uniq -c | sort -n -r | head' 
alias histrg='history -500 | rg' # Rip grep search recent history

# Command line head / tail shortcuts

# Use color diff, if availible
if command_exists colordiff ; then
  alias diff='colordiff'
fi

# System Monitoring
alias meminfo='free -m -l -t' # Show free and used memory
alias cpuinfo='lscpu' # Show CPU Info
alias cpuhog='ps -eo pid,ppid,cmd,%cpu --sort=-%cpu | head' # Processes consuming most cpu
alias distro='cat /etc/*-release' # Show OS info
alias ports='netstat -tulanp' # Show open ports

# App Specific
if command_exists code ; then; alias vsc='code .'; fi # Launch VS Code in current dir

# Alias for install script
alias dotfiles="${DOTFILES_DIR:-$HOME/Documents/config/dotfiles}/install.sh"
alias dots="dotfiles"
