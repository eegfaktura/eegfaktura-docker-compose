#!/bin/sh
set -eu
: "${WAIT_URL:?WAIT_URL is not set}"
interval="${WAIT_INTERVAL:-2}"
case "$interval" in ''|*[!0-9]*|0) echo "WAIT_INTERVAL must be a positive integer" >&2; exit 2;; esac
until curl --fail --silent --show-error --connect-timeout 2 --max-time 5 "$WAIT_URL" >/dev/null
do
    echo "Waiting for $WAIT_URL ..."
    sleep "$interval"
done
if [ -n "${WRAPPED_ENTRYPOINT:-}" ]; then
    exec "$WRAPPED_ENTRYPOINT" "$@"
fi
exec "$@"
