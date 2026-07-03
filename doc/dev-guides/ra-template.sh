#!/bin/sh
#
# template
#
# Description: OCF resource agent for <service>.
#
# Copyright (c) <year> <org>
# License:     GNU General Public License (GPL)
#
# OCF parameters:
#   OCF_RESKEY_example_string  - string parameter example
#   OCF_RESKEY_example_integer - integer parameter example
#
template_version="0.1.0"

: "${OCF_FUNCTIONS_DIR:=${OCF_ROOT}/lib/heartbeat}"
# shellcheck source=/dev/null
. "${OCF_FUNCTIONS_DIR}/ocf-shellfuncs"

# Parameter defaults
OCF_RESKEY_example_string_default="default"
OCF_RESKEY_example_integer_default=30

# Apply defaults for any parameter not set by Pacemaker
: "${OCF_RESKEY_example_string:=${OCF_RESKEY_example_string_default}}"
: "${OCF_RESKEY_example_integer:=${OCF_RESKEY_example_integer_default}}"

template_meta_data() {
    cat <<EOF
<?xml version="1.0"?>
<!DOCTYPE resource-agent SYSTEM "ra-api-1.dtd">
<resource-agent name="template" version="${template_version}">
<version>1.0</version>
<shortdesc lang="en">One-line description of template.</shortdesc>
<longdesc lang="en">
Full description of what the resource agent manages, how it works,
and any important constraints (e.g. VIP ordering, shared storage).
</longdesc>
<parameters>
<parameter name="example_string" unique="0" required="0">
    <shortdesc lang="en">Short string parameter description.</shortdesc>
    <longdesc lang="en">Full string parameter description.</longdesc>
    <content type="string" default="${OCF_RESKEY_example_string_default}" />
</parameter>
<parameter name="example_integer" unique="0" required="0">
    <shortdesc lang="en">Short integer parameter description.</shortdesc>
    <longdesc lang="en">Full integer parameter description. Minimum 10.</longdesc>
    <content type="integer" default="${OCF_RESKEY_example_integer_default}" />
</parameter>
</parameters>
<actions>
    <action name="start"        timeout="30s" />
    <action name="stop"         timeout="30s" />
    <action name="monitor"      timeout="20s" interval="10s" />
    <action name="validate-all" timeout="20s" />
    <action name="meta-data"    timeout="5s" />
    <action name="methods"      timeout="5s" />
    <action name="usage"        timeout="5s" />
</actions>
</resource-agent>
EOF
}

template_usage() {
    echo "usage: $0 {start|stop|monitor|validate-all|meta-data|methods|usage}"
}

template_methods() {
    echo "start stop monitor validate-all meta-data methods usage"
}

template_check() {
    # Lightweight probe: is the resource running right now?
    # Returns OCF_SUCCESS, OCF_NOT_RUNNING, or OCF_ERR_GENERIC.
    #
    # _check is a shared helper called from three places:
    #   - template_start:   idempotency guard (skip start if already running)
    #   - template_stop:    idempotency guard (skip stop if already stopped)
    #   - template_monitor: the OCF monitor action
    #
    # Keeping _check separate from _monitor means start and stop can probe the
    # resource state without invoking an OCF action, and _monitor can add retry
    # logic or deeper health checks on top of the basic running/not-running test
    # without affecting the idempotency guards.
    return "$OCF_NOT_RUNNING"
}

template_monitor() {
    # The OCF monitor action. Pacemaker calls this periodically on all nodes.
    # On the active node it verifies the resource is healthy; on the passive node
    # it is expected to return OCF_NOT_RUNNING.
    #
    # For a simple resource, delegating to _check is sufficient. For more complex
    # resources, add retry logic or deeper health checks here (e.g. verify the
    # service actually responds, not just that the process is alive) without
    # changing _check.
    template_check
}

template_start() {
    # Idempotency: Pacemaker may call start on an already-running resource.
    if template_check; then
        ocf_log info "template already running"
        return "$OCF_SUCCESS"
    fi

    # Start the resource here.

    # If the start command is synchronous (blocks until the resource is ready),
    # a single template_check after it is sufficient. For asynchronous starts,
    # poll until running or the attempt limit is reached. Keep the loop bounded -
    # an unbounded loop can consume the entire Pacemaker start action timeout
    # silently.
    attempt=0
    while [ "$attempt" -lt 10 ]; do
        attempt=$((attempt + 1))
        if template_check; then
            ocf_log info "template started"
            return "$OCF_SUCCESS"
        fi
        sleep 1
    done

    # ocf_exit_reason writes a human-readable failure message that appears in
    # "pcs status" output, making failures visible without needing to read logs.
    ocf_exit_reason "template not running after ${attempt} checks"
    return "$OCF_ERR_GENERIC"
}

template_stop() {
    # validate-all is called before stop (in the dispatch below), consistent with
    # the OCF RA developer guide. A broken configuration means service calls in
    # stop will also fail - validate surfaces the root cause immediately with
    # OCF_ERR_CONFIGURED rather than obscuring it behind a generic service error.
    # If the service binary is gone (OCF_ERR_INSTALLED), the same applies.
    # Validate also matters for performance: if a stop call can time out (e.g.
    # connecting to an unreachable service), validate fails in milliseconds
    # instead of waiting out the full stop timeout before returning an error.
    #
    # Idempotency: succeed immediately if already stopped.
    if ! template_check; then
        ocf_log info "template already stopped"
        return "$OCF_SUCCESS"
    fi

    # Stop the resource here.

    ocf_log info "template stopped"
    return "$OCF_SUCCESS"
}

template_validate() {
    # Validate parameters and verify this node can run the resource.
    # Called explicitly before start; also available as the validate-all action.
    #
    # Use the correct error code:
    #   OCF_ERR_CONFIGURED - parameter value is wrong (bad type, out of range)
    #   OCF_ERR_INSTALLED  - required binary or file is missing on this node

    if ! ocf_is_decimal "$OCF_RESKEY_example_integer" || \
       [ "$OCF_RESKEY_example_integer" -lt 10 ]; then
        ocf_exit_reason "example_integer \"${OCF_RESKEY_example_integer}\" must be 10 or greater"
        return "$OCF_ERR_CONFIGURED"
    fi

    if ! have_binary "/usr/bin/myservice"; then
        ocf_exit_reason "myservice binary not found or not executable"
        return "$OCF_ERR_INSTALLED"
    fi

    return "$OCF_SUCCESS"
}

# --- main ---

if [ "$#" -ne 1 ]; then
    template_usage
    exit "$OCF_ERR_ARGS"
fi

# meta-data, usage, and methods must always succeed regardless of environment.
# Handle them before the root check so "pcs resource describe" works without
# privileges and crm_resource can query the agent during cluster setup.
case "$__OCF_ACTION" in
    meta-data)  template_meta_data; exit "$OCF_SUCCESS" ;;
    usage|help) template_usage;     exit "$OCF_SUCCESS" ;;
    methods)    template_methods;   exit "$OCF_SUCCESS" ;;
esac

ocf_is_root || { ocf_exit_reason "must be run as root"; exit "$OCF_ERR_PERM"; }

ocf_log debug "begin ${__OCF_ACTION}"

case "$__OCF_ACTION" in
    start)
        # Exit with validate's exact OCF error code so Pacemaker knows whether
        # to retry on another node (OCF_ERR_INSTALLED) or not (OCF_ERR_CONFIGURED).
        template_validate || exit "$?"
        template_start
        ;;
    stop)
        template_validate || exit "$?"
        template_stop
        ;;
    monitor)
        template_monitor
        ;;
    validate-all)
        template_validate
        ;;
    *)
        template_methods
        exit "$OCF_ERR_UNIMPLEMENTED"
        ;;
esac

rc=$?
ocf_log debug "end ${__OCF_ACTION} rc=${rc}"
exit "$rc"
