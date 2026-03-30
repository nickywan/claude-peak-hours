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

# ── Load peak hours config ─────────────────────────────
CONFIG_URL="https://raw.githubusercontent.com/nickywan/claude-peak-hours/main/peak-hours.json"
CONFIG_CACHE="/tmp/claude/peak-hours-config.json"
CONFIG_CACHE_TTL=3600

# Hardcoded fallback
FALLBACK_CONFIG='{"version":2,"peak_windows":[{"days":[1,2,3,4,5],"start_utc":12,"end_utc":18}]}'

mkdir -p /tmp/claude 2>/dev/null

load_config() {
    local config=""
    local needs_fetch=true

    # Check cache
    if [ -f "$CONFIG_CACHE" ]; then
        local cache_mtime
        if $IS_GNU; then
            cache_mtime=$(stat -c %Y "$CONFIG_CACHE" 2>/dev/null)
        else
            cache_mtime=$(stat -f %m "$CONFIG_CACHE" 2>/dev/null)
        fi
        local cache_age=$(( $(date +%s) - cache_mtime ))
        if [ "$cache_age" -lt "$CONFIG_CACHE_TTL" ]; then
            needs_fetch=false
            config=$(cat "$CONFIG_CACHE" 2>/dev/null)
        fi
    fi

    # Fetch if needed
    if $needs_fetch; then
        local response
        response=$(curl -s --max-time 3 "$CONFIG_URL" 2>/dev/null)
        if [ -n "$response" ] && echo "$response" | jq -e '.peak_windows' >/dev/null 2>&1; then
            config="$response"
            echo "$response" > "$CONFIG_CACHE"
        fi
    fi

    # Fallback to stale cache
    if [ -z "$config" ] && [ -f "$CONFIG_CACHE" ]; then
        config=$(cat "$CONFIG_CACHE" 2>/dev/null)
    fi

    # Fallback to hardcoded
    if [ -z "$config" ] || ! echo "$config" | jq -e '.peak_windows' >/dev/null 2>&1; then
        config="$FALLBACK_CONFIG"
    fi

    echo "$config"
}

PEAK_CONFIG=$(load_config)

# ── Peak/Off-peak detection ────────────────────────────
NOW=$(date +%s)
UTC_HOUR=$(TZ=UTC date +%-H)
UTC_MIN=$(TZ=UTC date +%-M)
UTC_SEC=$(TZ=UTC date +%-S)
UTC_DOW=$(TZ=UTC date +%u)
UTC_SECS=$((UTC_HOUR * 3600 + UTC_MIN * 60 + UTC_SEC))

LOCAL_HOUR=$(date +%-H)
LOCAL_MIN=$(date +%-M)

# Local-UTC offset in hours
TZ_DIFF_H=$(( (LOCAL_HOUR - UTC_HOUR + 24) % 24 ))
[ "$TZ_DIFF_H" -gt 12 ] && TZ_DIFF_H=$((TZ_DIFF_H - 24))

IS_PEAK=0
CURRENT_WINDOW_END_UTC=""
NUM_WINDOWS=$(echo "$PEAK_CONFIG" | jq '.peak_windows | length')

for ((w=0; w<NUM_WINDOWS; w++)); do
    W_START=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[$w].start_utc")
    W_END=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[$w].end_utc")
    W_DAYS=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[$w].days[]")

    # Check if current UTC day is in this window's days
    day_match=0
    for d in $W_DAYS; do
        [ "$d" -eq "$UTC_DOW" ] && day_match=1
    done

    if [ "$day_match" -eq 1 ]; then
        W_START_SECS=$((W_START * 3600))
        W_END_SECS=$((W_END * 3600))

        if [ "$W_END" -gt "$W_START" ]; then
            # Normal window (no midnight crossing)
            if [ "$UTC_SECS" -ge "$W_START_SECS" ] && [ "$UTC_SECS" -lt "$W_END_SECS" ]; then
                IS_PEAK=1
                CURRENT_WINDOW_END_UTC=$W_END
            fi
        else
            # Midnight-crossing window (e.g., 22:00-02:00)
            if [ "$UTC_SECS" -ge "$W_START_SECS" ] || [ "$UTC_SECS" -lt "$W_END_SECS" ]; then
                IS_PEAK=1
                CURRENT_WINDOW_END_UTC=$W_END
            fi
        fi
    fi

    # Also check: if window crosses midnight, check previous day's window applying to today
    if [ "$day_match" -eq 0 ] && [ "$W_END" -lt "$W_START" ]; then
        prev_dow=$(( (UTC_DOW - 2 + 7) % 7 + 1 ))
        for d in $W_DAYS; do
            if [ "$d" -eq "$prev_dow" ] && [ "$UTC_SECS" -lt "$((W_END * 3600))" ]; then
                IS_PEAK=1
                CURRENT_WINDOW_END_UTC=$W_END
            fi
        done
    fi
done

# ── Countdown to next transition ───────────────────────
SECS_UNTIL=0

if [ "$IS_PEAK" -eq 1 ]; then
    # Seconds until end of current window
    END_SECS=$((CURRENT_WINDOW_END_UTC * 3600))
    if [ "$END_SECS" -gt "$UTC_SECS" ]; then
        SECS_UNTIL=$((END_SECS - UTC_SECS))
    else
        # Midnight crossing: end is tomorrow
        SECS_UNTIL=$(( (86400 - UTC_SECS) + END_SECS ))
    fi
else
    # Find nearest upcoming window start
    BEST=999999999
    for ((w=0; w<NUM_WINDOWS; w++)); do
        W_START=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[$w].start_utc")
        W_DAYS=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[$w].days[]")
        W_START_SECS=$((W_START * 3600))

        # Check today and next 7 days
        for ((look=0; look<8; look++)); do
            check_dow=$(( (UTC_DOW - 1 + look) % 7 + 1 ))
            for d in $W_DAYS; do
                if [ "$d" -eq "$check_dow" ]; then
                    if [ "$look" -eq 0 ]; then
                        candidate=$((W_START_SECS - UTC_SECS))
                    else
                        candidate=$(( (86400 - UTC_SECS) + (look - 1) * 86400 + W_START_SECS ))
                    fi
                    if [ "$candidate" -gt 0 ] && [ "$candidate" -lt "$BEST" ]; then
                        BEST=$candidate
                    fi
                fi
            done
        done
    done
    SECS_UNTIL=$BEST
fi

# Is the next transition on a different day?
NEXT_IS_DIFFERENT_DAY=0
LOCAL_DOW=$(date +%u)
remaining_today=$(( 86400 - (LOCAL_HOUR * 3600 + LOCAL_MIN * 60) ))
if [ "$SECS_UNTIL" -ge "$remaining_today" ]; then
    NEXT_IS_DIFFERENT_DAY=1
fi

# ── Build peak status section ──────────────────────────
peak_section=""
LOCAL_TIME=$(fmt_local_time "$SECS_UNTIL")
DURATION=$(fmt_duration "$SECS_UNTIL")

if [ "$IS_PEAK" -eq 1 ]; then
    # Currently peak — show when off-peak starts
    if [ "$NEXT_IS_DIFFERENT_DAY" -eq 1 ]; then
        days_ahead=$(( (SECS_UNTIL + LOCAL_HOUR * 3600 + LOCAL_MIN * 60) / 86400 ))
        target_local_dow=$(( (LOCAL_DOW - 1 + days_ahead) % 7 + 1 ))
        day_label="${L_DAYS[$target_local_dow]}"
        peak_section="${red}${bold}${L_PEAK}${reset} ${dim}~${reset} ${green}${L_OFFPEAK} ${day_label} ${LOCAL_TIME}${reset} ${dim}(${DURATION})${reset}"
    else
        peak_section="${red}${bold}${L_PEAK}${reset} ${dim}~${reset} ${green}${L_OFFPEAK} ${LOCAL_TIME}${reset} ${dim}(${DURATION})${reset}"
    fi
else
    # Currently off-peak — show when peak starts
    if [ "$NEXT_IS_DIFFERENT_DAY" -eq 1 ]; then
        days_ahead=$(( (SECS_UNTIL + LOCAL_HOUR * 3600 + LOCAL_MIN * 60) / 86400 ))
        target_local_dow=$(( (LOCAL_DOW - 1 + days_ahead) % 7 + 1 ))
        day_label="${L_DAYS[$target_local_dow]}"
        peak_section="${green}${bold}⚡ ${L_OFFPEAK}${reset} ${dim}~${reset} ${red}${L_PEAK} ${day_label} ${LOCAL_TIME}${reset} ${dim}(${DURATION})${reset}"
    else
        peak_section="${green}${bold}⚡ ${L_OFFPEAK}${reset} ${dim}~${reset} ${red}${L_PEAK} ${LOCAL_TIME}${reset} ${dim}(${DURATION})${reset}"
    fi
fi

# ── LINE 1 ──────────────────────────────────────────────
line1="${blue}${model_name}${reset}${sep}${pct_color}${pct}%${reset}${sep}${peak_section}"

# ════════════════════════════════════════════════════════
# MINIMAL MODE
# ════════════════════════════════════════════════════════
if [ "$MODE" = "minimal" ]; then
    printf "%b" "$line1"
    exit 0
fi

# ════════════════════════════════════════════════════════
# FULL MODE — timeline + rate limits
# ════════════════════════════════════════════════════════

# ── Timeline bar ───────────────────────────────────────
timeline_section=""

# Check if today has any peak hours
TODAY_HAS_PEAK=0

for ((w=0; w<NUM_WINDOWS; w++)); do
    W_START=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[$w].start_utc")
    W_END=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[$w].end_utc")
    W_DAYS=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[$w].days[]")

    for d in $W_DAYS; do
        [ "$d" -eq "$UTC_DOW" ] && TODAY_HAS_PEAK=1
    done
done

cursor_pos=$((LOCAL_HOUR * 2 + (LOCAL_MIN >= 30 ? 1 : 0)))

bar=""
for ((i=0; i<48; i++)); do
    h=$((i / 2))
    utc_h=$(( (h - TZ_DIFF_H + 24) % 24 ))

    is_peak_slot=0
    for ((w=0; w<NUM_WINDOWS; w++)); do
        W_START=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[$w].start_utc")
        W_END=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[$w].end_utc")
        W_DAYS=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[$w].days[]")
        for d in $W_DAYS; do
            if [ "$d" -eq "$UTC_DOW" ]; then
                if [ "$W_END" -gt "$W_START" ]; then
                    [ "$utc_h" -ge "$W_START" ] && [ "$utc_h" -lt "$W_END" ] && is_peak_slot=1
                else
                    ([ "$utc_h" -ge "$W_START" ] || [ "$utc_h" -lt "$W_END" ]) && is_peak_slot=1
                fi
            fi
        done
    done

    if [ "$i" -eq "$cursor_pos" ]; then
        bar+="${white}${bold}●${reset}"
    elif [ "$is_peak_slot" -eq 1 ]; then
        bar+="${yellow}━${reset}"
    else
        bar+="${green}━${reset}"
    fi
done

if [ "$TODAY_HAS_PEAK" -eq 0 ]; then
    timeline_section="${dim}${L_TODAY}${reset}  ${bar}  ${green}━${reset}${dim} ${L_OFFPEAK} ${L_ALLDAY}${reset}  ${white}${bold}●${reset}${dim} ${L_NOW}${reset}"
else
    first_start=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[0].start_utc")
    first_end=$(echo "$PEAK_CONFIG" | jq -r ".peak_windows[0].end_utc")
    ps_local=$(( (first_start + TZ_DIFF_H + 24) % 24 ))
    pe_local=$(( (first_end + TZ_DIFF_H + 24) % 24 ))
    ps_label=$(fmt_hour $ps_local)
    pe_label=$(fmt_hour $pe_local)
    timeline_section="${dim}${L_TODAY}${reset}  ${bar}  ${green}━${reset}${dim} ${L_OFFPEAK}${reset} ${yellow}━${reset}${dim} ${L_PEAK} ${ps_label}-${pe_label}${reset}  ${white}${bold}●${reset}${dim} ${L_NOW}${reset}"
fi

# ── OAuth token ─────────────────────────────────────────
get_oauth_token() {
    if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then echo "$CLAUDE_CODE_OAUTH_TOKEN"; return 0; fi
    if command -v security >/dev/null 2>&1; then
        local blob token
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            [ -n "$token" ] && [ "$token" != "null" ] && { echo "$token"; return 0; }
        fi
    fi
    local creds_file="${HOME}/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        local token
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        [ -n "$token" ] && [ "$token" != "null" ] && { echo "$token"; return 0; }
    fi
    echo ""
}

# ── Usage data (cached 60s) ────────────────────────────
usage_cache="/tmp/claude/statusline-usage-cache.json"
usage_cache_ttl=60

needs_refresh=true
usage_data=""
if [ -f "$usage_cache" ]; then
    if $IS_GNU; then
        cache_mtime=$(stat -c %Y "$usage_cache" 2>/dev/null)
    else
        cache_mtime=$(stat -f %m "$usage_cache" 2>/dev/null)
    fi
    cache_age=$(( $(date +%s) - cache_mtime ))
    if [ "$cache_age" -lt "$usage_cache_ttl" ]; then
        needs_refresh=false
        usage_data=$(cat "$usage_cache" 2>/dev/null)
    fi
fi

if $needs_refresh; then
    token=$(get_oauth_token)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        response=$(curl -s --max-time 5 \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-code/2.1.34" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
            usage_data="$response"
            echo "$response" > "$usage_cache"
        fi
    fi
    [ -z "$usage_data" ] && [ -f "$usage_cache" ] && usage_data=$(cat "$usage_cache" 2>/dev/null)
fi

# ── Rate limits line ────────────────────────────────────
rate_line=""
if [ -n "$usage_data" ] && echo "$usage_data" | jq -e . >/dev/null 2>&1; then
    bw=10

    fh_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
    fh_reset=$(format_reset_time "$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')")
    fh_bar=$(build_usage_bar "$fh_pct" "$bw")
    fh_color=$(color_for_pct "$fh_pct")

    sd_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
    sd_reset=$(format_reset_time "$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')")
    sd_bar=$(build_usage_bar "$sd_pct" "$bw")
    sd_color=$(color_for_pct "$sd_pct")

    rate_line="${white}${L_CURRENT}${reset} ${fh_bar} ${fh_color}$(printf '%3d' "$fh_pct")%${reset} ${dim}⟳${reset} ${white}${fh_reset}${reset}"
    rate_line+="${sep}"
    rate_line+="${white}${L_WEEKLY}${reset}  ${sd_bar} ${sd_color}$(printf '%3d' "$sd_pct")%${reset} ${dim}⟳${reset} ${white}${sd_reset}${reset}"
fi

# ── Final output ────────────────────────────────────────
printf "%b" "$line1"
[ -n "$timeline_section" ] && printf "\n\n%b" "$timeline_section"
[ -n "$rate_line" ] && printf "\n%b" "$rate_line"

exit 0
