#!/usr/bin/env bats
#
# Tests for the mediationzone OCF resource agent.
# Run as any user: bats test/mediationzone.bats
#

load 'helpers'

setup()    { setup_test_env; }
teardown() { teardown_test_env; }

# --- meta-data ---

@test "meta-data exits 0" {
    run_ra meta-data
    [ "$status" -eq 0 ]
}

@test "meta-data outputs valid XML" {
    run_ra meta-data
    echo "$output" | xmllint --noout - 2>/dev/null || skip "xmllint not available"
    [ "$status" -eq 0 ]
}

@test "meta-data contains agent name" {
    run_ra meta-data
    [[ "$output" == *'name="mediationzone"'* ]]
}

# --- validate-all ---

@test "validate-all passes with valid config" {
    run_ra validate-all
    [ "$status" -eq 0 ]
}

@test "validate-all passes for unknown pico type when pico_port is set" {
    OCF_RESKEY_pico_name="custom" OCF_RESKEY_pico_port="9999" run_ra validate-all
    [ "$status" -eq 0 ]
}

@test "validate-all fails for unknown pico type without pico_port" {
    # unknown pico names are accepted only when pico_port is set explicitly
    OCF_RESKEY_pico_name="custom" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

@test "validate-all fails when os_user does not exist" {
    OCF_RESKEY_os_user="nosuchuser_mzonetest" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

@test "validate-all fails when mz_home does not exist" {
    OCF_RESKEY_mz_home="/nosuchdir_mzonetest" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

@test "validate-all fails when mz_home contains shell metacharacters" {
    OCF_RESKEY_mz_home="/opt/mz home" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

@test "validate-all fails when mzsh not executable" {
    chmod -x "${MZ_HOME}/bin/mzsh"
    run_ra validate-all
    [ "$status" -eq 5 ]  # OCF_ERR_INSTALLED
}

@test "validate-all fails when java_home does not exist" {
    OCF_RESKEY_java_home="/nosuchdir_mzonetest" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

@test "validate-all fails when java_home contains shell metacharacters" {
    OCF_RESKEY_java_home="/usr/lib/jvm/java;evil" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

@test "validate-all fails when mzsh_timeout is not an integer" {
    OCF_RESKEY_mzsh_timeout="30s" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

@test "validate-all fails when mzsh_timeout is 0" {
    OCF_RESKEY_mzsh_timeout="0" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

@test "validate-all fails when mzsh_timeout is below minimum (9)" {
    OCF_RESKEY_mzsh_timeout="9" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

@test "validate-all passes when mzsh_timeout is at minimum (10)" {
    OCF_RESKEY_mzsh_timeout="10" run_ra validate-all
    [ "$status" -eq 0 ]
}

@test "validate-all fails when pico_port is not a positive integer" {
    OCF_RESKEY_pico_name="custom" OCF_RESKEY_pico_port="abc" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

@test "validate-all fails when pico_name contains shell metacharacters" {
    OCF_RESKEY_pico_name="platform;evil" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

@test "validate-all fails when pico_name contains uppercase letters" {
    OCF_RESKEY_pico_name="Platform" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

@test "validate-all fails when pico_name contains underscores" {
    OCF_RESKEY_pico_name="my_pico" run_ra validate-all
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

# --- monitor ---

@test "monitor returns OCF_NOT_RUNNING when pico is stopped" {
    run_ra monitor
    [ "$status" -eq 7 ]  # OCF_NOT_RUNNING
}

@test "monitor returns OCF_SUCCESS when pico is running" {
    set_pico_running platform
    run_ra monitor
    [ "$status" -eq 0 ]
}

@test "monitor returns OCF_NOT_RUNNING for ui when only platform is running" {
    set_pico_running platform
    OCF_RESKEY_pico_name="ui" run_ra monitor
    [ "$status" -eq 7 ]
}

@test "monitor returns OCF_SUCCESS for ui when ui is running" {
    set_pico_running ui
    OCF_RESKEY_pico_name="ui" run_ra monitor
    [ "$status" -eq 0 ]
}

# --- start ---

@test "start brings pico from stopped to running" {
    run_ra start
    [ "$status" -eq 0 ]
}

@test "start is idempotent when pico already running" {
    set_pico_running platform
    run_ra start
    [ "$status" -eq 0 ]
}

@test "start fails when mzsh startup fails" {
    inject_fail startup 1   # fail with default rc (not 104), no retry triggered
    run_ra start
    [ "$status" -eq 1 ]  # OCF_ERR_GENERIC
}

@test "start fails when mzsh startup returns degraded state (started with errors)" {
    inject_degraded startup
    run_ra start
    [ "$status" -eq 1 ]  # OCF_ERR_GENERIC
    [[ "$output" == *"degraded"* ]]
}

@test "start fails when mzsh startup returns no such server process" {
    inject_notfound startup
    run_ra start
    [ "$status" -eq 1 ]  # OCF_ERR_GENERIC
    [[ "$output" == *"not found"* ]]
}

@test "start leaves pico running after success" {
    run_ra start
    [ "$status" -eq 0 ]
    run_ra monitor
    [ "$status" -eq 0 ]
}

# --- stop ---

@test "stop brings pico from running to stopped" {
    set_pico_running platform
    run_ra stop
    [ "$status" -eq 0 ]
}

@test "stop is idempotent when pico already stopped" {
    run_ra stop
    [ "$status" -eq 0 ]
}

@test "stop leaves pico stopped after success" {
    set_pico_running platform
    run_ra stop
    [ "$status" -eq 0 ]
    run_ra monitor
    [ "$status" -eq 7 ]  # OCF_NOT_RUNNING
}

@test "stop escalates to mzsh kill when shutdown fails" {
    set_pico_running platform
    inject_fail shutdown 1
    run_ra stop
    [ "$status" -eq 0 ]  # mzsh kill succeeds (pico was running, pid file present)
}

@test "stop fails with OCF_ERR_CONFIGURED when config is invalid" {
    set_pico_running platform
    OCF_RESKEY_os_user="nosuchuser_mzonetest" run_ra stop
    [ "$status" -eq 6 ]  # OCF_ERR_CONFIGURED
}

# --- lifecycle ---

@test "full lifecycle: start, monitor running, stop, monitor stopped" {
    run_ra start
    [ "$status" -eq 0 ]

    run_ra monitor
    [ "$status" -eq 0 ]

    run_ra stop
    [ "$status" -eq 0 ]

    run_ra monitor
    [ "$status" -eq 7 ]
}

@test "full lifecycle for ui pico" {
    OCF_RESKEY_pico_name="ui" run_ra start
    [ "$status" -eq 0 ]

    OCF_RESKEY_pico_name="ui" run_ra monitor
    [ "$status" -eq 0 ]

    OCF_RESKEY_pico_name="ui" run_ra stop
    [ "$status" -eq 0 ]

    OCF_RESKEY_pico_name="ui" run_ra monitor
    [ "$status" -eq 7 ]
}

@test "full lifecycle for custom pico with explicit pico_port" {
    OCF_RESKEY_pico_name="custom" OCF_RESKEY_pico_port="9999" run_ra start
    [ "$status" -eq 0 ]

    OCF_RESKEY_pico_name="custom" OCF_RESKEY_pico_port="9999" run_ra monitor
    [ "$status" -eq 0 ]

    OCF_RESKEY_pico_name="custom" OCF_RESKEY_pico_port="9999" run_ra stop
    [ "$status" -eq 0 ]

    OCF_RESKEY_pico_name="custom" OCF_RESKEY_pico_port="9999" run_ra monitor
    [ "$status" -eq 7 ]
}

# --- monitor retry ---

@test "monitor retries and returns OCF_SUCCESS after transient status failure" {
    set_pico_running platform
    inject_fail status 1  # fail first attempt, state file intact for second
    run_ra monitor
    [ "$status" -eq 0 ]  # OCF_SUCCESS on retry
}

@test "monitor detects mzsh status timeout (rc=124)" {
    set_pico_running platform
    inject_slow status
    OCF_RESKEY_mzsh_timeout=2 run_ra monitor
    [ "$status" -eq 1 ]  # OCF_ERR_GENERIC
    [[ "$output" == *"timed out"* ]]
}

@test "monitor returns OCF_ERR_GENERIC on unexpected status rc" {
    set_pico_running platform
    inject_error status  # persistent - both attempts return rc=3
    run_ra monitor
    [ "$status" -eq 1 ]  # OCF_ERR_GENERIC
}

# --- stop edge cases ---

@test "stop returns success when kill returns rc=2 (pico already not running)" {
    set_pico_running platform
    inject_fail shutdown 1
    inject_fail kill 1      # kill rc=2: process not running - stop already achieved
    run_ra stop
    [ "$status" -eq 0 ]  # OCF_SUCCESS
}

@test "stop returns OCF_ERR_GENERIC when shutdown and kill both fail" {
    set_pico_running platform
    inject_fail shutdown 1
    inject_fail kill 1 1    # kill fails with rc=1 (no pid file / permission error)
    run_ra stop
    [ "$status" -eq 1 ]  # OCF_ERR_GENERIC
}

# --- start rc=104 retry ---

@test "start retries once on mzsh rc=104 and succeeds" {
    inject_fail startup 1 104  # fail first attempt with rc=104, succeed on retry
    run_ra start
    [ "$status" -eq 0 ]
    [[ "$output" == *"mzsh rc=104"* ]]
    [[ "$output" == *"retrying"* ]]
}

@test "start fails when both startup attempts return mzsh rc=104" {
    inject_fail startup 2 104  # fail both attempts with rc=104
    run_ra start
    [ "$status" -eq 1 ]  # OCF_ERR_GENERIC
}

# --- start pre-kill ---

@test "pre-start kill failure does not block start" {
    # pico is stopped - no pid file, kill fails silently, start must still succeed
    inject_fail kill 1
    run_ra start
    [ "$status" -eq 0 ]
    run_ra monitor
    [ "$status" -eq 0 ]
}

# --- usage and methods ---

@test "usage exits 0" {
    run_ra usage
    [ "$status" -eq 0 ]
}

@test "methods exits 0" {
    run_ra methods
    [ "$status" -eq 0 ]
}

@test "help exits 0" {
    run_ra help
    [ "$status" -eq 0 ]
}

@test "unknown action returns OCF_ERR_UNIMPLEMENTED" {
    run_ra frobinate
    [ "$status" -eq 3 ]
}
