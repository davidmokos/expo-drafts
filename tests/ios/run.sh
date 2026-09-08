#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/expo-drafts-native-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
swiftc -emit-module -emit-library -module-name EXUpdates tests/ios/EXUpdatesTestDouble.swift -o "$test_dir/libEXUpdates.dylib" -emit-module-path "$test_dir/EXUpdates.swiftmodule"
swiftc -I "$test_dir" -L "$test_dir" -lEXUpdates -Xlinker -rpath -Xlinker "$test_dir" ios/ExpoDraftsCatalog.swift ios/ExpoDraftsUpdateTransaction.swift tests/ios/transaction-tests.swift -o "$test_dir/transaction-tests"
"$test_dir/transaction-tests"
