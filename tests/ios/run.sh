#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/expo-drafts-native-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
swiftc -emit-module -emit-library -module-name EXUpdates tests/ios/EXUpdatesTestDouble.swift -o "$test_dir/libEXUpdates.dylib" -emit-module-path "$test_dir/EXUpdates.swiftmodule"
swiftc -I "$test_dir" -L "$test_dir" -lEXUpdates -Xlinker -rpath -Xlinker "$test_dir" ios/ExpoDraftsCatalog.swift ios/ExpoDraftsUpdateTransaction.swift tests/ios/transaction-tests.swift -o "$test_dir/transaction-tests"
"$test_dir/transaction-tests"
swiftc ios/ExpoDraftsCatalog.swift ios/ExpoDraftsBuildCatalog.swift tests/ios/build-catalog-tests.swift -o "$test_dir/build-catalog-tests"
"$test_dir/build-catalog-tests" "$test_dir/build-request-fixture.json"
swiftc ios/ExpoDraftsCatalog.swift ios/ExpoDraftsBuildCatalog.swift ios/ExpoDraftsBuildInstallation.swift tests/ios/build-installation-tests.swift -o "$test_dir/build-installation-tests"
"$test_dir/build-installation-tests"
node --input-type=module - "$test_dir/build-request-fixture.json" <<'NODE'
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseBuildRequest } from './cli/build-request.mjs';
const fixture = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const query = new URL(fixture.url).searchParams;
assert.equal(query.get('title'), fixture.title, 'The browser must decode the exact native issue title.');
assert.equal(query.get('body'), fixture.body, 'The browser must decode the exact native request body.');
assert.deepEqual(parseBuildRequest(query.get('body')), fixture.expected);
console.log('PASS native request URL round-trips through browser decoding and trusted CI parser');
NODE
