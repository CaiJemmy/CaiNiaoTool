#!/bin/bash

[[ -n "${_COLOR_SH:-}" ]] && return
readonly _COLOR_SH=1

echo=echo
for cmd in echo /bin/echo; do
  $cmd >/dev/null 2>&1 || continue
  if ! $cmd -e "" | grep -qE '^-e'; then
    echo=$cmd
    break
  fi
done

# 颜色（仅终端）
if [[ -t 2 ]]; then
    readonly CSI=$($echo -e "\033[")
    readonly _C_RED="${CSI}1;31m"
    readonly _C_YELLOW="${CSI}1;33m"
    readonly _C_GREEN="${CSI}1;32m"
    readonly _C_BLUE="${CSI}1;34m"
    readonly _C_YAN="${CSI}1;36m"
    readonly _C_GRAY="${CSI}90m"
    readonly _C_RESET="${CSI}0m"
    readonly _C_BOLD="${CSI}1m"
    readonly C_SUCCESS="$_C_GREEN"
    readonly C_FAILURE="$_C_RED"
    readonly C_QUESTION="$_C_BLUE"
    readonly C_WARNING="$_C_YELLOW"
    readonly C_MSG="$_C_YAN"
    readonly C_END="$_C_RESET"
else
    readonly _C_RED='' _C_YELLOW='' _C_GREEN='' _C_BLUE=''
    readonly _C_GRAY='' _C_RESET='' _C_BOLD=''
    readonly C_SUCCESS='' C_FAILURE='' C_QUESTION='' C_WARNING='' C_MSG='' C_END=''
fi
