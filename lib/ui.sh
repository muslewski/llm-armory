# armory UI bootstrap — GREEN-UI-KIT consumer with graceful fallbacks.
# Source this from bin/* after setting ARMORY_HOME (optional).
# shellcheck shell=bash

# Idempotent: re-sourcing is safe.
[[ -n ${ARMORY_UI_LOADED-} ]] && return 0
ARMORY_UI_LOADED=1

_armory_ui_source_kit() {
  local src="${GREEN_UI:-${HOME}/.local/lib/green-ui.sh}"
  if [[ -r "$src" ]]; then
    # shellcheck disable=SC1090
    source "$src"
    return 0
  fi
  return 1
}

_armory_ui_fallbacks() {
  # Minimal no-op / plain-text fallbacks when kit is absent.
  # Match the kit surface armory consumes so call sites need no branching.
  detect_color() { printf 'none\n'; }
  ui_tty() {
    case ${GREEN_UI_FORCE_TTY-} in
      1) return 0 ;;
      0) return 1 ;;
    esac
    [[ -t 2 ]]
  }
  ui_init() {
    GREEN_UI_MODE=none
    UI_R= UI_G= UI_Y= UI_B= UI_C= UI_M= UI_D= UI_BOLD= UI_Z= UI_A=
    UI_OK='OK' UI_ERR='XX' UI_WARN='!!' UI_PEND='..' UI_RUN='>>'
    UI_SPIN=('|' '/' '-' '\')
    return 0
  }
  banner() {
    local title=${1-} subtitle=${2-}
    printf '+-- %s --+\n' "$title" >&2
    [[ -n $subtitle ]] && printf '| %s\n' "$subtitle" >&2
  }
  ok()   { printf 'OK %s\n' "$*" >&2; }
  warn() { printf '!! %s\n' "$*" >&2; }
  die()  { printf 'XX %s\n' "${1-error}" >&2; exit "${2:-1}"; }
  check_set() {
    local sf=$1 id=$2 state=$3
    printf '%s %s\n' "$id" "$state" >>"$sf"
  }
  checklist() {
    local sf=$1; shift
    local item id label st g line last
    for item in "$@"; do
      id=${item%%:*}
      label=${item#*:}
      last=pending
      if [[ -f $sf ]]; then
        while IFS= read -r line || [[ -n $line ]]; do
          [[ -z $line ]] && continue
          [[ ${line%% *} == "$id" ]] && last=${line#* }
        done <"$sf"
      fi
      case $last in
        done) g='OK' ;;
        failed) g='XX' ;;
        skipped) g='--' ;;
        running) g='>>' ;;
        *) g='..' ;;
      esac
      printf '%s %s\n' "$g" "$label" >&2
    done
  }
  progress() {
    local pct=${1-0} width=${2-24}
    local filled empty i
    (( pct < 0 )) && pct=0
    (( pct > 100 )) && pct=100
    filled=$(( width * pct / 100 ))
    empty=$(( width - filled ))
    printf '[' >&2
    for (( i = 0; i < filled; i++ )); do printf '#' >&2; done
    for (( i = 0; i < empty; i++ )); do printf '-' >&2; done
    printf '] %s%%\n' "$pct" >&2
  }
  panel() {
    local title=${1-} line
    printf '+-- %s --+\n' "$title" >&2
    while IFS= read -r line || [[ -n $line ]]; do
      printf '| %s\n' "$line" >&2
    done
    printf '+--------+\n' >&2
  }
  table() { column -t -s $'\t' 2>/dev/null || cat; }
  choose() {
    local prompt=$1; shift
    local -a opts=("$@")
    local i n
    if (( ${#opts[@]} == 0 )); then return 1; fi
    if ui_tty && command -v fzf >/dev/null 2>&1; then
      printf '%s\n' "${opts[@]}" | fzf --prompt="${prompt} " --height=40% --reverse || exit 130
      return 0
    fi
    printf '› %s\n' "$prompt" >&2
    for i in "${!opts[@]}"; do
      printf '  %d) %s\n' "$((i + 1))" "${opts[i]}" >&2
    done
    printf 'Choice [1]: ' >&2
    if ! read -r n </dev/tty; then exit 130; fi
    [[ -z ${n-} ]] && n=1
    [[ $n == q || $n == Q ]] && exit 130
    [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#opts[@]} )) || exit 130
    printf '%s\n' "${opts[n - 1]}"
  }
  green_fzf_opts() { printf '%s\n' '--no-color --no-bold'; }
  ui_cleanup() { return 0; }
  # effort gauge for mission cards (plain fallback)
  sparkline() { printf '%s\n' "$*"; }
}

if ! _armory_ui_source_kit; then
  _armory_ui_fallbacks
fi
ui_init
