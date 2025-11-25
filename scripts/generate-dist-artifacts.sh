#!/usr/bin/env bash

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
    popd >/dev/null || return 2
    echo "${SCRIPT_PATH}"
    return 0
}

# Set up the script variables.
function setup_variables() {
    declare -a MODS_TO_PACKAGE
    declare _LIB_PATH SCRIPT_DIR PROJECT_ROOT DIST_DIRECTORY MODS_DIRECTORY RESP
    declare ARCHIVE_TYPE INDEX ARG STATUS
}

# Set up the script.
function setup() {
    setup_variables
}
setup

# Clean up the script variables after it is finished.
function cleanup_variables() {
    unset MODS_TO_PACKAGE
    unset _LIB_PATH SCRIPT_DIR PROJECT_ROOT DIST_DIRECTORY MODS_DIRECTORY RESP
    unset ARCHIVE_TYPE INDEX ARG STATUS
}

# Clean up after the script is finished.
function cleanup() {
    cleanup_variables
}
trap cleanup EXIT

if ! SCRIPT_DIR="$(get_script_dir)"; then
    return 1
fi
_LIB_PATH="$(realpath -e -- "${SCRIPT_DIR}/lib/")"

# shellcheck source=./lib/logging.sh
source "${_LIB_PATH}/logging.sh"
# shellcheck source=./lib/strings.sh
source "${_LIB_PATH}/strings.sh"

log_verbose "Script directory is at \"${SCRIPT_DIR}\""

# The root directory of the project.
PROJECT_ROOT="$(realpath -e -- "${SCRIPT_DIR}/../")"

log_verbose "Project root is at \"${PROJECT_ROOT}\""

# The path where distribution files will be created.
DIST_DIRECTORY="$(realpath -E -- "${PROJECT_ROOT}/dist/")"

log_verbose "Distribution output directory is at \"${DIST_DIRECTORY}\""

# The path where mod source code live.
MODS_DIRECTORY="$(realpath -e -- "${PROJECT_ROOT}/mods/")"

# The type of archive to create.
ARCHIVE_TYPE="tar.gz"

log_verbose "Mods directory is at \"${MODS_DIRECTORY}\""

if [[ -z "$1" ]]; then
    log_error "A list of mod names or '*' is required!"
    exit 2
fi


L="${#@}"
for INDEX in $(eval "echo {0..$L}"); do
    ARG="$(eval "echo \$$INDEX")"
    case "${ARG}" in
        -a | --all)
            if [[ "${#MODS_TO_PACKAGE}" -eq 0 ]]; then
                read -sra MODS_TO_PACKAGE <<<"$(find "${MODS_DIRECTORY}" -mindepth 1 -maxdepth 1 -type d -printf "%f ")"
            fi
            ;;
        -t | --archive-type=*)
            if [[ "${ARG}" == "-t" ]]; then
                INDEX="$((INDEX + 1))"
                ARG="${*[INDEX]}"
                ARCHIVE_TYPE="${ARG}"
            else
                ARCHIVE_TYPE="${ARG/--archive-type\=//}"
            fi
            ;;
        *)
            MODS_TO_PACKAGE+=("$(read -r <<<"$(find "${MODS_DIRECTORY}" -mindepth 1 -maxdepth 1 -type d -name "$1" -printf "%f ")")")
            ;;
    esac
done

if [[ "${#MODS_TO_PACKAGE[@]}" -eq 0 ]]; then
    log_error "No mods to package!"
    exit 3
fi

echo "About to package ${#MODS_TO_PACKAGE[@]} mods!"
printf "* %s\n" "${MODS_TO_PACKAGE[@]}"
while [[ -z "${RESP}" ]]; do
    read -p "Is this okay? [Y/n] " -r RESP
    case "$(to_lower_case "${RESP}")" in
        y)
            log_info "Proceeding!"
            ;;
        n)
            log_error "Aborting!"
            exit 4
            ;;
        *)
            log_error "Unknown response \"${RESP}\"! Please try again!"
            unset RESP
            ;;
    esac
done

if [[ -d "${DIST_DIRECTORY}" ]]; then
    log_info "Distribution output directory exists, proceeding"
else
    log_warning "Distribution output directory does not exist, creating"
    mkdir -p "${DIST_DIRECTORY}"
fi

for MOD in "${MODS_TO_PACKAGE[@]}"; do
    log_info "Packaging \"${MOD}\"..."
    log_verbose "Entering mod directory"
    # shellcheck disable=SC2164
    pushd "$(realpath -e -- "${MODS_DIRECTORY}/${MOD}")" >/dev/null
    STATUS="$?"
    if [[ "${STATUS}" -ne 0 ]]; then
        log_error "Failed to enter source directory for mod \"${MOD}\"!"
        exit 5
    fi
    log_verbose "Packaging with \"bsdtar\"..."
    bsdtar -C "${PWD}/src/" -cf "$(realpath -E -- "${DIST_DIRECTORY}/${MOD}.${ARCHIVE_TYPE}")" "."
    log_verbose "Exiting mod directory"
    # shellcheck disable=SC2164
    popd >/dev/null
    STATUS="$?"
    if [[ "${STATUS}" -ne 0 ]]; then
        log_error "Failed to exit source directory for mod \"${MOD}\"!"
        exit 6
    fi
    log_info "$(sgr_8bit_fg 40)[SUCCESS]$(sgr_reset) Packaged \"${MOD}\"!"
done

log_info "$(sgr_8bit_fg 40)[SUCCESS]$(sgr_reset) Packaged ${#MODS_TO_PACKAGE[@]} mods!"
