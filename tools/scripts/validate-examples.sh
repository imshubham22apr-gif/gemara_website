#!/usr/bin/env sh
# validate-examples.sh – validate tutorial YAML artifacts defined in
#   tutorials/validation-manifest.yml against pinned Gemara CUE schemas.
#
# Usage:
#   validate-examples.sh [OPTIONS]
#
# Options:
#   --manifest PATH   Path to validation manifest (default: tutorials/validation-manifest.yml)
#   --ref REF         Override schema-ref for all entries (e.g. latest, v1.6.0)
#   --skip-negative   Skip negative fixture validation (runs by default)
#   --help            Show this help message

set -eu

# Windows Git-for-Windows path fixup (ensure GNU toolchain and cue binary in PATH)
case "$(uname -s 2>/dev/null || true)" in
  MINGW*|MSYS*|CYGWIN*)
    export PATH="/usr/bin:/bin:${PATH}"
    if command -v go >/dev/null 2>&1; then
      export PATH="${PATH}:$(go env GOPATH)/bin"
    fi
    ;;
esac

SCRIPT_DIR="$(dirname "$0")"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MANIFEST="${REPO_ROOT}/tutorials/validation-manifest.yml"
OVERRIDE_REF=""
RUN_NEGATIVE=1

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest)
      MANIFEST="$2"
      shift 2
      ;;
    --ref)
      OVERRIDE_REF="$2"
      shift 2
      ;;
    --skip-negative)
      RUN_NEGATIVE=0
      shift
      ;;
    --help)
      echo "Usage: $0 [--manifest PATH] [--ref REF] [--skip-negative]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: Manifest file not found at: $MANIFEST" >&2
  exit 1
fi

if ! command -v cue >/dev/null 2>&1; then
  echo "ERROR: 'cue' CLI tool is required but not found in PATH." >&2
  exit 1
fi

echo "  > Validating tutorial examples using manifest: $MANIFEST"

# Parse manifest using awk to extract records under 'examples:'
# Each item has: file, cue-definition, schema-ref, kind
passed=0
failed=0
fixtures_checked=0
fixtures_failed=0

# Read parsed fields: file|definition|ref|kind
awk '
  BEGIN { in_examples=0 }
  /^examples:/ { in_examples=1; next }
  in_examples && /^[[:space:]]*- file:[[:space:]]*/ {
    if (file != "") {
      print file "|" def "|" ref "|" kind
    }
    sub(/^[[:space:]]*- file:[[:space:]]*/, "")
    gsub(/["'\''\r]/, "")
    file = $0
    def = ""
    ref = ""
    kind = "full"
    next
  }
  in_examples && /^[[:space:]]+cue-definition:[[:space:]]*/ {
    sub(/^[[:space:]]+cue-definition:[[:space:]]*/, "")
    gsub(/["'\''\r]/, "")
    def = $0
    next
  }
  in_examples && /^[[:space:]]+schema-ref:[[:space:]]*/ {
    sub(/^[[:space:]]+schema-ref:[[:space:]]*/, "")
    gsub(/["'\''\r]/, "")
    ref = $0
    next
  }
  in_examples && /^[[:space:]]+kind:[[:space:]]*/ {
    sub(/^[[:space:]]+kind:[[:space:]]*/, "")
    gsub(/["'\''\r]/, "")
    kind = $0
    next
  }
  END {
    if (file != "") {
      print file "|" def "|" ref "|" kind
    }
  }
' "$MANIFEST" | while IFS='|' read -r rel_path cue_def schema_ref kind; do
  [ -z "$rel_path" ] && continue

  effective_ref="${OVERRIDE_REF:-$schema_ref}"
  full_path="${REPO_ROOT}/${rel_path}"

  if [ ! -f "$full_path" ]; then
    echo "  FAIL: file does not exist: $rel_path"
    exit 1
  fi

  module="github.com/gemaraproj/gemara@${effective_ref}"

  if [ "$kind" = "invalid-fixture" ]; then
    if [ "$RUN_NEGATIVE" -eq 1 ]; then
      if cue vet -c -d "$cue_def" "$module" "$full_path" >/dev/null 2>&1; then
        echo "  NEGATIVE TEST FAILED: $rel_path unexpectedly passed validation against $cue_def"
        exit 1
      else
        echo "  PASS (negative check): $rel_path correctly rejected by $cue_def"
      fi
    fi
  else
    if cue vet -c -d "$cue_def" "$module" "$full_path" 2>&1; then
      echo "  PASS: $rel_path -> $cue_def ($effective_ref)"
    else
      echo "  FAIL: $rel_path -> $cue_def ($effective_ref)"
      exit 1
    fi
  fi
done

echo ""
echo "  > All manifest examples validated successfully!"
