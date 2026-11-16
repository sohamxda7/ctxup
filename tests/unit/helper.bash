# Shared setup for the unit tests: load the script as a library.
REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures"

load_ctxup() {
  # shellcheck source=../../ctxup
  source "$REPO_ROOT/ctxup"
  set +eEu +o pipefail
  trap - EXIT ERR
}

detect() {
  CTXUP_OS_RELEASE="$FIXTURES/os-release/$1" CTXUP_MACHINE="${2:-x86_64}" detect_os
}
