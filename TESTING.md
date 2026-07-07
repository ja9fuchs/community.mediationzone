# Testing

## BATS unit tests

Tests the RA logic using a mock `mzsh`. No cluster required, no root, no MediationZone installation.

**Requires**: [bats-core](https://github.com/bats-core/bats-core). No cluster, no `resource-agents` install needed - OCF shell functions are stubbed in `test/lib/heartbeat/ocf-shellfuncs`.

The suite is fully self-contained: mocked OCF functions, mocked `su`, mocked `mzsh` - nothing leaks to the host system.

```bash
bats test/mediationzone.bats
```

The mock `mzsh` in `test/bin/` tracks pico state via files in a temporary directory. Failure injection (rc=104 retry, shutdown escalation, monitor retry, timeout) is handled through sentinel files written by the test helpers. 

Example result:

```
→ bats ./test/mediationzone.bats 
mediationzone.bats
 ✓ meta-data exits 0
 ✓ meta-data outputs valid XML
 ✓ meta-data contains agent name
 ✓ validate-all passes with valid config
 ✓ validate-all passes for unknown pico type when pico_port is set
 ✓ validate-all fails for unknown pico type without pico_port
 ✓ validate-all fails when os_user does not exist
 ✓ validate-all fails when mz_home does not exist
 ✓ validate-all fails when mz_home contains shell metacharacters
 ✓ validate-all fails when mzsh not executable
 ✓ validate-all fails when java_home does not exist
 ✓ validate-all fails when java_home contains shell metacharacters
 ✓ validate-all fails when mzsh_timeout is not an integer
 ✓ validate-all fails when mzsh_timeout is 0
 ✓ validate-all fails when mzsh_timeout is below minimum (9)
 ✓ validate-all passes when mzsh_timeout is at minimum (10)
 ✓ validate-all fails when pico_port is not a positive integer
 ✓ validate-all fails when pico_port exceeds maximum (65536)
 ✓ validate-all fails when pico_name contains shell metacharacters
 ✓ validate-all fails when pico_name starts with a hyphen
 ✓ validate-all fails when pico_name contains uppercase letters
 ✓ validate-all fails when pico_name contains underscores
 ✓ validate-all fails when monitor_retries is not an integer
 ✓ validate-all passes when monitor_retries is 0 (no retries)
 ✓ monitor returns OCF_NOT_RUNNING when pico is stopped
 ✓ monitor returns OCF_SUCCESS when pico is running
 ✓ monitor returns OCF_NOT_RUNNING for ui when only platform is running
 ✓ monitor returns OCF_SUCCESS for ui when ui is running
 ✓ start brings pico from stopped to running
 ✓ start is idempotent when pico already running
 ✓ start fails when mzsh startup fails
 ✓ start fails when mzsh startup returns degraded state (started with errors)
 ✓ start fails when mzsh startup returns no such server process
 ✓ start leaves pico running after success
 ✓ stop brings pico from running to stopped
 ✓ stop is idempotent when pico already stopped
 ✓ stop leaves pico stopped after success
 ✓ stop escalates to mzsh kill when shutdown fails
 ✓ stop fails with OCF_ERR_CONFIGURED when config is invalid
 ✓ full lifecycle: start, monitor running, stop, monitor stopped
 ✓ full lifecycle for ui pico
 ✓ full lifecycle for custom pico with explicit pico_port
 ✓ monitor retries and returns OCF_SUCCESS after transient status failure
 ✓ monitor returns OCF_NOT_RUNNING with monitor_retries=0 (no retry)
 ✓ monitor detects mzsh status timeout (rc=124)
 ✓ monitor returns OCF_ERR_GENERIC on unexpected status rc
 ✓ stop returns success when kill returns rc=2 (pico already not running)
 ✓ stop returns OCF_ERR_GENERIC when shutdown and kill both fail
 ✓ start retries once on mzsh rc=104 and succeeds
 ✓ start fails when both startup attempts return mzsh rc=104
 ✓ pre-start kill failure does not block start
 ✓ usage exits 0
 ✓ methods exits 0
 ✓ help exits 0
 ✓ unknown action returns OCF_ERR_UNIMPLEMENTED

55 tests, 0 failures
```


## ocft integration tests

Tests OCF compliance on a real cluster node. Requires root and `resource-agents` installed (provides the `ocft` command and OCF libraries). No MediationZone installation required - a mock `mzsh` is created by the test setup.

```bash
# Install the RA
cp ra/mediationzone /usr/lib/ocf/resource.d/heartbeat/
chmod 755 /usr/lib/ocf/resource.d/heartbeat/mediationzone

# Copy the test case
cp tools/ocft/mediationzone /usr/share/resource-agents/ocft/configs/

# Compile test scripts and run
ocft make mediationzone
ocft test mediationzone
```

`ocft make` generates a test script from the case file. `ocft test` runs it. Both steps require root.

The test setup creates a `mzadmin` system user and a fake `mz_home` with a mock `mzsh`. The mock and the user are removed by the test cleanup. If a `mzadmin` user already exists on the node (e.g. a real MediationZone installation), it is left in place.

Example result:

```
# ocft test mediationzone
Initializing 'mediationzone' ...
Done.

mediationzone: validate-all passes with valid config - OK.
mediationzone: validate-all fails when os_user does not exist - OK.
mediationzone: validate-all fails when mz_home does not exist - OK.
mediationzone: validate-all fails when mz_home contains shell metacharacters - OK.
mediationzone: validate-all fails when mzsh is not executable - OK.
mediationzone: validate-all fails when java_home does not exist - OK.
mediationzone: validate-all fails when java_home contains shell metacharacters - OK.
mediationzone: validate-all fails when mzsh_timeout is not an integer - OK.
mediationzone: validate-all fails when mzsh_timeout is below minimum - OK.
mediationzone: validate-all fails when pico_name contains unsupported characters - OK.
mediationzone: validate-all fails when pico_name starts with a hyphen - OK.
mediationzone: validate-all fails for unknown pico type without pico_port - OK.
mediationzone: validate-all passes for unknown pico type with pico_port - OK.
mediationzone: validate-all fails when pico_port exceeds maximum - OK.
mediationzone: validate-all fails when monitor_retries is not an integer - OK.
mediationzone: validate-all passes when monitor_retries is 0 (no retries) - OK.
mediationzone: monitor returns OCF_NOT_RUNNING when pico is stopped - OK.
mediationzone: monitor returns OCF_SUCCESS when pico is running - OK.
mediationzone: start brings pico from stopped to running - OK.
mediationzone: start is idempotent when pico is already running - OK.
mediationzone: stop brings pico from running to stopped - OK.
mediationzone: stop is idempotent when pico is already stopped - OK.
mediationzone: stop fails with OCF_ERR_CONFIGURED when config is invalid - OK.
mediationzone: full lifecycle: start, monitor, stop, monitor - OK.
OK.
OK.
OK.
Cleaning 'mediationzone' ...
Done.
```