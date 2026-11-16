#!/usr/bin/env bash
# Runs every unit test suite: each module on its own, the bootstrap config, then the root wiring test.
# No AWS credentials are needed (the provider is mocked).
# Usage: ./run_tests.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

# Share one downloaded copy of the AWS provider between all suites.
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

failed=()

run_suite() {
  local dir="$1"
  shift
  echo
  echo "=== ${dir#"$ROOT"/} ==="
  if ! (cd "$dir" && terraform init -input=false "$@" >/dev/null && terraform test); then
    failed+=("${dir#"$ROOT"/}")
  fi
}

for module in "$ROOT"/modules/aws/*/; do
  run_suite "${module%/}"
done

echo
echo "=== bootstrap ==="
if ! (cd "$ROOT/bootstrap" && terraform init -input=false -backend=false >/dev/null && terraform test); then
  failed+=("bootstrap")
fi

echo
echo "=== root ==="
if ! (cd "$ROOT" && terraform init -input=false -backend=false >/dev/null && terraform test); then
  failed+=("root")
fi

echo
if [ ${#failed[@]} -gt 0 ]; then
  echo "FAILED suites: ${failed[*]}"
  exit 1
fi
echo "All suites passed."
