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
