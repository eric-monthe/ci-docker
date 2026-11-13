#!/usr/bin/env bash
# Run the tests of each app inside its Docker image and export the JUnit reports.
# Nothing but Docker is needed on the host.
#
# Usage: scripts/run-tests.sh [app...]   (default: backend frontend)
#   reports are written to reports/<app>/
#   DOCKER_BUILD_ARGS: extra docker build flags (used by CI for the cache)

set -uo pipefail

cd "$(dirname "$0")/.."

apps=("$@")
[ ${#apps[@]} -eq 0 ] && apps=(backend frontend)

failed=()

for app in "${apps[@]}"; do
    name=$(basename "$app")
    out="reports/$name"

    echo "--Test $name--"
    rm -rf "$out"

    # shellcheck disable=SC2086
    if ! docker build --target test-reports --output "$out" ${DOCKER_BUILD_ARGS:-} "$app"; then
        echo "✗ $name: docker build failed"
        failed+=("$name")
        continue
    fi

    code=$(cat "$out/test-exit-code" 2>/dev/null || echo 1)
    if [ "$code" = "0" ]; then
        echo "✓ $name: tests passed (reports in $out)"
    else
        echo "✗ $name: tests failed (reports in $out)"
        failed+=("$name")
    fi
done

if [ ${#failed[@]} -gt 0 ]; then
    echo "Failed: ${failed[*]}"
    exit 1
fi

echo "All tests passed"
