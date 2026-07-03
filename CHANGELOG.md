# Changelog

## [0.4.8] - 2026-07-03

### Changed
- Stop: call `validate-all` before stopping, consistent with the start action. Fails
  fast with `OCF_ERR_CONFIGURED` when the configuration is broken rather than letting
  mzsh calls fail with a less informative error.

## [0.4.7] - 2026-07-03

### Fixed
- Monitor: add `sleep 1` between retry attempts so back-to-back status calls do not
  both land in the same transient failure window.

### Changed
- Corrected resource name in header comment (`rsc_platform` -> `rsc_mz_platform`).
- `mzsh_timeout` longdesc: clarified that the timeout also applies to the pre-start
  kill call that runs before startup.

## [0.4.6] - 2026-07-02

### Fixed
- Stop: treat `mzsh kill` rc=2 ("target process is not running") as success. Previously
  any non-zero kill rc caused `OCF_ERR_GENERIC`; rc=2 during stop escalation means the
  pico has already stopped, which is the desired state.

## [0.4.5] - 2026-07-02

### Fixed
- Start: detect `mzsh startup` returning "no such server process" with rc=0 and fail with
  `OCF_ERR_GENERIC`. mzsh exits 0 when the pico name is not registered, without starting
  anything; previously accepted as success.

## [0.4.4] - 2026-07-02

### Fixed
- Start: detect degraded startup (rc=0 with "Started with errors" in mzsh output) and return `OCF_ERR_GENERIC`. mzsh startup returns rc=0 when the pico starts in codeserver-only mode (e.g. platform VIP absent), previously accepted as success. Stdout is now captured and checked; a healthy start produces no such output.

## [0.4.3] - 2026-07-02

### Changed
- Removed `ec` as a known pico name with a default port (9090). Execution context picos always have custom names in practice (e.g. `eh1ec1`); the generic name `ec` does not exist in production deployments. Any non-platform, non-ui pico now requires `pico_port` to be set explicitly.

## [0.4.2] - 2026-07-02

### Changed
- Renamed `pico` parameter to `pico_name` for clarity; the value has always been a pico name, not a type

## [0.4.1] - 2026-07-01

### Fixed
- Monitor: redirected mzsh stdout to `/dev/null`; mzsh status output ("ui is running") was passed to the Pacemaker XML parser, producing `pcmk__log_xmllib_err` errors in the cluster log

### Changed
- Added `ocf_exit_reason` on all error-exit paths so failure reasons appear in `pcs status`
- Removed `mediationzone:` prefix from log messages; Pacemaker already tags log lines with the resource agent name

## [0.4.0] - 2026-07-01

### Changed
- `#!/bin/bash` → `#!/bin/sh`; replaced all `[[ ]]` with `[ ]`, `==` with `-eq`/`-ne`, and `(( attempt++ ))` with `attempt=$((attempt + 1))`
- Renamed `call_rc` to `rc` throughout; consolidated monitor to a single `rc` variable, replacing nested `if` for rc=124 with a direct `case` arm
- Dropped quotes on `$rc` in numeric comparisons (`[ $rc -eq 0 ]`) except where shellcheck requires them (loop variable not immediately preceded by assignment)
- `pico_port` validation: `-eq 0` → `-le 0` to also reject negative values
- Removed unused `notify` action from dispatch table
- Demoted begin/end action logs and successful monitor log to `ocf_log debug`; these fired on every invocation and added noise at info level

## [0.3.1] - 2026-06-29

### Fixed
- `MZ_PLATFORM=http://localhost` is now set only for status, shutdown, and kill operations.
  Startup no longer sets it, so mzsh routes the startup command through the platform RCP address
  configured in the container properties (`pico.rcp.platform.host`). With MZ_PLATFORM=localhost
  set during startup, mzsh could not reach a remote platform and fell back to spawning the JVM
  directly without platform-managed initialization, resulting in "Started with errors, Only
  Codeserver service is guaranteed to be running."

## [0.3.0] - 2026-06-29

### Changed
- Hardcoded `MZ_PLATFORM=http://localhost` in the mzsh environment. mzsh uses the hostname from
  this URL to determine the RCP target (port 6790); with localhost, all mzsh operations either
  connect directly to the local platform RCP or fail fast via ECONNREFUSED and fall back to the
  local pico's own RCP port. This eliminates the 2x30s TCP SYN timeout that occurred when the
  platform VIP was unreachable, reducing worst-case status time from ~64s to ~4s and worst-case
  shutdown time from ~136s to ~76s (pico teardown only).
- `mediationzone_stop`: removed pre-stop `mediationzone_check` - mzsh shutdown returns 0 for an
  already-stopped pico, so idempotency is handled by the shutdown call itself
- `mediationzone_stop`: removed post-shutdown `mediationzone_check` - strace confirms mzsh
  shutdown blocks until the pico process exits before returning; the verification step was
  redundant

## [0.2.1] - 2026-06-29

### Changed
- Split `local` declarations in `mediationzone_monitor` onto separate lines for clarity
- Added blank lines in `mediationzone_start` and `mediationzone_stop` to separate guard blocks from action code
- Added blank lines and section comments in `mediationzone_validate` to group input validation, path checks, and pico checks

## [0.2.0] - 2026-06-26

### Changed
- Collapsed multiline `su -c "..."` arguments onto single lines to clean up `set -x` trace output
- Removed single quotes from `MEDIATIONZONE_MZSH_ENV` and mzsh path to reduce quote noise in trace output; compensated with allow-list path validation in `validate-all`
- Replaced regex numeric validation with `ocf_is_decimal` (OCF built-in)
- Replaced metacharacter deny-list with allow-list glob pattern (`*[^[:alnum:]/_+.-]*`) for `mz_home` and `java_home`
- Removed `ocf_is_probe` guard from `mediationzone_validate` - filesystem checks now run unconditionally so EFS failures are visible during cluster start
- Replaced `if mediationzone_check; then` idiom in `mediationzone_start` and `mediationzone_stop` for consistency
- Removed redundant `local call_rc` from `mediationzone_check`
- Improved readability: case block alignment, whitespace, comments in parameter init block
- Added `help` and `notify` to the dispatch table and test suite

## [0.1.0] - 2026-06-23

Initial version.
- OCF resource agent for MediationZone by DigitalRoute
- Manages a single pico process as an active/passive cluster resource
- Actions: start, stop, monitor, validate-all, meta-data, methods, usage
- Pre-start `mzsh kill` to evict lingering JVMs; `ss -K` to clear TIME-WAIT before startup
- Single rc=104 retry on start
- Stop escalation: `mzsh shutdown` then `mzsh kill`
- Monitor retry loop (2 attempts) with timeout detection
- BATS test suite with mock mzsh
