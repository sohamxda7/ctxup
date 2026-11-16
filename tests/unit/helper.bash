# Shared setup for the unit tests: load the script as a library.
REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures"

load_ctxup() {
  # shellcheck source=../../ctxup
  source "$REPO_ROOT/ctxup"
  # Keep errexit on: bats needs it to notice a failing assertion. Only undo
  # the two options that interfere with bats itself.
  set +u +o pipefail
}

detect() {
  CTXUP_OS_RELEASE="$FIXTURES/os-release/$1" CTXUP_MACHINE="${2:-x86_64}" detect_os
}
