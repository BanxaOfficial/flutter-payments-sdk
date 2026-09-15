#!/usr/bin/env bash
# Publish the four federated packages to pub.dev in dependency order.
#
#   ./tool/publish.sh              # dry-run only (default)
#   ./tool/publish.sh --publish    # upload; waits until each version is on pub.dev
#
# Do not run this on the workspace root or example/. Requires `dart pub login`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBLISH=0
for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=1 ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

PACKAGES=(
  banxa_payments_flutter_platform_interface
  banxa_payments_flutter_ios
  banxa_payments_flutter_android
  banxa_payments_flutter
)

package_dir() {
  echo "$ROOT/packages/$1"
}

read_version() {
  python3 - "$1" <<'PY'
import pathlib, sys, re
text = pathlib.Path(sys.argv[1], "pubspec.yaml").read_text()
m = re.search(r"^version:\s*(\S+)", text, re.M)
if not m:
    sys.exit("no version: in pubspec.yaml")
print(m.group(1))
PY
}

on_pub() {
  local name="$1" version="$2"
  python3 - "$name" "$version" <<'PY'
import json, sys, urllib.error, urllib.request
name, version = sys.argv[1], sys.argv[2]
url = f"https://pub.dev/api/packages/{name}"
try:
    with urllib.request.urlopen(url, timeout=30) as res:
        data = json.load(res)
except urllib.error.HTTPError as e:
    if e.code == 404:
        sys.exit(1)
    raise
versions = {v["version"] for v in data.get("versions", [])}
sys.exit(0 if version in versions else 1)
PY
}

wait_on_pub() {
  local name="$1" version="$2"
  local i
  echo "Waiting for $name $version on pub.dev…"
  for i in $(seq 1 36); do
    if on_pub "$name" "$version"; then
      echo "  found $name $version"
      return 0
    fi
    sleep 10
  done
  echo "Timed out waiting for $name $version (6 minutes)." >&2
  exit 1
}

hide_overrides() {
  local dir="$1"
  if [[ -f "$dir/pubspec_overrides.yaml" ]]; then
    mv "$dir/pubspec_overrides.yaml" "$dir/pubspec_overrides.yaml.publishbak"
  fi
}

restore_overrides() {
  local dir pkg
  for pkg in "${PACKAGES[@]}"; do
    dir="$(package_dir "$pkg")"
    if [[ -f "$dir/pubspec_overrides.yaml.publishbak" ]]; then
      mv "$dir/pubspec_overrides.yaml.publishbak" "$dir/pubspec_overrides.yaml"
    fi
  done
}

trap restore_overrides EXIT

command -v dart >/dev/null || { echo "dart not on PATH" >&2; exit 1; }

if [[ "$PUBLISH" -eq 1 ]]; then
  echo "Publishing to pub.dev (will prompt nothing; uses --force)."
else
  echo "Dry-run only. Pass --publish to upload."
fi

for pkg in "${PACKAGES[@]}"; do
  dir="$(package_dir "$pkg")"
  version="$(read_version "$dir")"
  echo
  echo "=== $pkg $version ==="

  if [[ "$PUBLISH" -eq 1 ]] && on_pub "$pkg" "$version"; then
    echo "Already on pub.dev; skipping."
    continue
  fi

  if [[ "$PUBLISH" -eq 1 ]]; then
    hide_overrides "$dir"
    (cd "$dir" && dart pub publish --force)
    wait_on_pub "$pkg" "$version"
  else
    (cd "$dir" && dart pub publish --dry-run)
  fi
done

echo
if [[ "$PUBLISH" -eq 1 ]]; then
  echo "All four packages are on pub.dev. Tag this commit (e.g. git tag -a 0.1.1) after you verify the listings."
  echo "Unlist the three implementation packages on pub.dev if they became listed again."
else
  echo "Dry-run finished. Re-run with --publish when you are logged in (dart pub login)."
fi
