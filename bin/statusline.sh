#!/bin/bash
set -f

IS_GNU=false
if date --version >/dev/null 2>&1; then IS_GNU=true; fi

# ── Argument parsing ────────────────────────────────────
MODE="minimal"
TIME_FMT=""
LANG_OVERRIDE=""

for arg in "$@"; do
    case "$arg" in
        --full) MODE="full" ;;
        --24h)  TIME_FMT="24h" ;;
        --12h)  TIME_FMT="12h" ;;
        --lang) LANG_OVERRIDE="__NEXT__" ;;
        *)
            if [ "$LANG_OVERRIDE" = "__NEXT__" ]; then
                LANG_OVERRIDE="$arg"
            fi
            ;;
    esac
done
[ "$LANG_OVERRIDE" = "__NEXT__" ] && LANG_OVERRIDE=""

# ── Time format detection ───────────────────────────────
if [ -z "$TIME_FMT" ]; then
    locale_str="${LC_TIME:-${LANG:-}}"
    case "$locale_str" in
        fr_*|de_*|es_*|pt_*|it_*|ja_*|zh_*|ko_*|ru_*) TIME_FMT="24h" ;;
        *) TIME_FMT="12h" ;;
    esac
fi

# ── Language detection ──────────────────────────────────
UI_LANG="en"
if [ -n "$LANG_OVERRIDE" ]; then
    UI_LANG="$LANG_OVERRIDE"
else
    locale_str="${LC_TIME:-${LANG:-}}"
    case "$locale_str" in
        fr_*) UI_LANG="fr" ;;
    esac
fi

# ── i18n strings ────────────────────────────────────────
if [ "$UI_LANG" = "fr" ]; then
    L_PEAK="Pointe"
    L_OFFPEAK="Hors pointe"
    L_ALLDAY="toute la journée"
    L_TODAY="auj."
    L_NOW="maint."
    L_CURRENT="session"
    L_WEEKLY="hebdo"
    L_DAYS=("" "lun." "mar." "mer." "jeu." "ven." "sam." "dim.")
    L_MONTHS=("" "jan" "fév" "mar" "avr" "mai" "jun" "jul" "aoû" "sep" "oct" "nov" "déc")
else
    L_PEAK="Peak"
    L_OFFPEAK="Off-peak"
    L_ALLDAY="all day"
    L_TODAY="today"
    L_NOW="now"
    L_CURRENT="current"
    L_WEEKLY="weekly"
    L_DAYS=("" "Mon." "Tue." "Wed." "Thu." "Fri." "Sat." "Sun.")
    L_MONTHS=("" "jan" "feb" "mar" "apr" "may" "jun" "jul" "aug" "sep" "oct" "nov" "dec")
fi

input=$(cat)

# ── Colors ──────────────────────────────────────────────
blue='\033[38;2;0;153;255m'
orange='\033[38;2;255;176;85m'
green='\033[38;2;0;175;80m'
cyan='\033[38;2;86;182;194m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
white='\033[38;2;220;220;220m'
magenta='\033[38;2;180;140;255m'
dim='\033[2m'
bold='\033[1m'
reset='\033[0m'
sep=" ${dim}│${reset} "

# ── Helpers ─────────────────────────────────────────────
fmt_duration() {
    local s=$1
    local d=$((s / 86400))
    local h=$(( (s % 86400) / 3600 ))
    local m=$(( (s % 3600) / 60 ))
    if [ "$d" -gt 0 ]; then printf "%dd%dh" "$d" "$h"
    elif [ "$h" -gt 0 ]; then printf "%dh%02dm" "$h" "$m"
    else printf "%dm" "$m"; fi
}

fmt_local_time() {
    local secs_from_now=$1
    if $IS_GNU; then
        if [ "$TIME_FMT" = "24h" ]; then
            LC_TIME=C date -d "+${secs_from_now} seconds" "+%H:%M" 2>/dev/null
        else
            LC_TIME=C date -d "+${secs_from_now} seconds" "+%l:%M%p" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/^ //'
        fi
    else
        if [ "$TIME_FMT" = "24h" ]; then
            LC_TIME=C date -v+"${secs_from_now}S" "+%H:%M" 2>/dev/null
        else
            LC_TIME=C date -v+"${secs_from_now}S" "+%l:%M%p" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/^ //'
        fi
    fi
}

fmt_hour() {
    local h=$1
    if [ "$TIME_FMT" = "24h" ]; then
        printf "%d:00" "$h"
    else
        if [ "$h" -eq 0 ]; then echo "12am"
        elif [ "$h" -lt 12 ]; then echo "${h}am"
        elif [ "$h" -eq 12 ]; then echo "12pm"
        else echo "$(( h - 12 ))pm"; fi
    fi
}

color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf "$red"
    elif [ "$pct" -ge 70 ]; then printf "$yellow"
    elif [ "$pct" -ge 50 ]; then printf "$orange"
    else printf "$green"; fi
}

build_usage_bar() {
    local pct=$1 width=$2
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_color
    bar_color=$(color_for_pct "$pct")
    local f="" e=""
    for ((i=0; i<filled; i++)); do f+="●"; done
    for ((i=0; i<empty; i++)); do e+="○"; done
    printf "${bar_color}${f}${dim}${e}${reset}"
}

format_reset_time() {
    local iso_str="$1"
    [ -z "$iso_str" ] || [ "$iso_str" = "null" ] && return
    local stripped="${iso_str%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    stripped="${stripped%%-[0-9][0-9]:[0-9][0-9]}"
    local epoch=""
    if [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]] || [[ "$iso_str" == *"-00:00"* ]]; then
        if $IS_GNU; then
            epoch=$(env TZ=UTC date -d "${stripped}" +%s 2>/dev/null)
        else
            epoch=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
        fi
    else
        if $IS_GNU; then
            epoch=$(date -d "${stripped}" +%s 2>/dev/null)
        else
            epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
        fi
    fi
    [ -z "$epoch" ] && return
    local month_idx day_num time_str
    if $IS_GNU; then
        month_idx=$(date -d "@$epoch" +%-m 2>/dev/null)
        day_num=$(date -d "@$epoch" +%-d 2>/dev/null)
        if [ "$TIME_FMT" = "24h" ]; then
            time_str=$(date -d "@$epoch" +"%H:%M" 2>/dev/null)
        else
            time_str=$(LC_TIME=C date -d "@$epoch" +"%l:%M%p" 2>/dev/null | sed 's/^ //' | tr '[:upper:]' '[:lower:]')
        fi
    else
        month_idx=$(date -j -r "$epoch" +%-m 2>/dev/null)
        day_num=$(date -j -r "$epoch" +%-d 2>/dev/null)
        if [ "$TIME_FMT" = "24h" ]; then
            time_str=$(date -j -r "$epoch" +"%H:%M" 2>/dev/null)
        else
            time_str=$(LC_TIME=C date -j -r "$epoch" +"%l:%M%p" 2>/dev/null | sed 's/^ //' | tr '[:upper:]' '[:lower:]')
        fi
    fi
    printf "%s %s, %s" "${L_MONTHS[$month_idx]}" "$day_num" "$time_str"
}

# ── Parse stdin (model, context) ───────────────────────
model_name="Claude"
pct=0
if [ -n "$input" ]; then
    model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null)
    size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000' 2>/dev/null)
    [ "$size" -eq 0 ] 2>/dev/null && size=200000
    it=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0' 2>/dev/null)
    cc=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0' 2>/dev/null)
    cr=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0' 2>/dev/null)
    current=$(( it + cc + cr ))
    [ "$size" -gt 0 ] 2>/dev/null && pct=$(( current * 100 / size )) || pct=0
fi

pct_color=$(color_for_pct "$pct")
