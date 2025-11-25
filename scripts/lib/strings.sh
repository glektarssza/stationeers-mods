# shellcheck shell=bash

# Get the directory the script is running from.
# === Outputs ===
# The path to the directory the script is running from.
# === Returns ===
# `0` - the function succeeded.
# `1` - a `cd` call failed.
# `2` - a `popd` call failed.
function get_script_dir() {
    pushd . >/dev/null
    local SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
    while [[ -L "${SCRIPT_PATH}" ]]; do
        cd "$(dirname -- "${SCRIPT_PATH}")" || return 1
        SCRIPT_PATH="$(readlink -f -- "$SCRIPT_PATH")"
    done
    cd "$(dirname -- "$SCRIPT_PATH")" >/dev/null || return 1
    SCRIPT_PATH="$(pwd)"
    # shellcheck disable=SC2164
    popd >/dev/null 2>&1
    echo "${SCRIPT_PATH}"
    return 0
}

if [[ -z "${SCRIPT_DIR}" ]] && ! SCRIPT_DIR="$(get_script_dir)"; then
    return 1
fi
if [[ -z "${_LIB_PATH}" ]]; then
    _LIB_PATH="${SCRIPT_DIR}"
fi

if [[ -n "${_LIB_STRINGS}" ]]; then
    return 0
fi
declare _LIB_STRINGS="loaded"

# Clean up after the script is finished.
function _lib_strings_cleanup() {
    unset _LIB_STRINGS
    unset to_lower_case to_upper_case
}
trap _lib_strings_cleanup EXIT

# Convert a string to all lower case.
# === Inputs ===
# `$1` - The string to convert to all lower case.
# === Outputs ===
# The input string as all lower case.
# === Returns ===
# `?` - The result of the operation.
function to_lower_case() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
    return $?
}

# Convert a string to all upper case.
# === Inputs ===
# `$1` - The string to convert to all upper case.
# === Outputs ===
# The input string as all upper case.
# === Returns ===
# `?` - The result of the operation.
function to_upper_case() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
    return $?
}
