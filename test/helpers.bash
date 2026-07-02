# Shared BATS helpers for mediationzone tests.

RA="${BATS_TEST_DIRNAME}/../ra/mediationzone"
TEST_DIR="${BATS_TEST_DIRNAME}"
STATE_DIR=""
MZ_HOME=""
JAVA_HOME_DIR=""

setup_test_env() {
    STATE_DIR="$(mktemp -d)"
    MZ_HOME="$(mktemp -d)"
    JAVA_HOME_DIR="$(mktemp -d)"

    mkdir -p "${MZ_HOME}/bin"
    cp "${TEST_DIR}/bin/mzsh" "${MZ_HOME}/bin/mzsh"
    chmod +x "${MZ_HOME}/bin/mzsh"
    # write state dir into MZ_HOME so mock mzsh can find it after su - strips the environment
    echo "$STATE_DIR" > "${MZ_HOME}/.test_state_dir"

    # prepend test/bin to PATH so our su and mzsh stubs shadow the real ones
    export PATH="${TEST_DIR}/bin:${PATH}"
    export OCF_ROOT="${TEST_DIR}"
    OCF_RESKEY_os_user="$(id -un)"
    export OCF_RESKEY_os_user
    export OCF_RESKEY_mz_home="${MZ_HOME}"
    export OCF_RESKEY_java_home="${JAVA_HOME_DIR}"
    export OCF_RESKEY_pico_name="platform"
}

teardown_test_env() {
    rm -rf "$STATE_DIR" "$MZ_HOME" "$JAVA_HOME_DIR"
}

run_ra() {
    run "$RA" "$@"
}

set_pico_running() {
    local pico="${1:-platform}"
    echo "running" > "${STATE_DIR}/mzone_state_${pico}"
}

set_pico_stopped() {
    local pico="${1:-platform}"
    rm -f "${STATE_DIR}/mzone_state_${pico}"
}

inject_fail() {
    local action="$1" count="${2:-1}" rc="${3:-}"
    if [[ -n "$rc" ]]; then
        echo "${count}:${rc}" > "${STATE_DIR}/mzone_fail_${action}"
    else
        echo "$count" > "${STATE_DIR}/mzone_fail_${action}"
    fi
}

inject_slow() {
    local action="$1"
    touch "${STATE_DIR}/mzone_slow_${action}"
}

inject_error() {
    local action="$1"
    touch "${STATE_DIR}/mzone_error_${action}"
}

inject_degraded() {
    local action="$1"
    touch "${STATE_DIR}/mzone_degraded_${action}"
}

inject_notfound() {
    local action="$1"
    touch "${STATE_DIR}/mzone_notfound_${action}"
}
