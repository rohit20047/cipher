#!/usr/bin/env bash
echo "===== CAMPFIRE ====="

echo "@campfirein:"
ls -la node_modules/@campfirein || true

echo
echo "brv-transport-client:"
ls -la node_modules/@campfirein/brv-transport-client || true

echo
echo "dist:"
ls -la node_modules/@campfirein/brv-transport-client/dist || true

echo
echo "package.json:"
cat node_modules/@campfirein/brv-transport-client/package.json || true

echo
echo "index.d.ts:"
ls -la node_modules/@campfirein/brv-transport-client/dist/index.d.ts || true

echo
echo "index.js:"
ls -la node_modules/@campfirein/brv-transport-client/dist/index.js || true

echo "========================"

MODE=""
OUTPUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    base|new)
      MODE="$1"
      shift
      ;;
    --output_path)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "Error: --output_path is required" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

node - "$MODE" "$OUTPUT_PATH" <<'EOF'
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const mode = process.argv[2];
const outputPath = process.argv[3];

// IMPORTANT:
// Every new/modified test title must contain the word "Pi".
const flags = mode === 'base' ? '--grep PiConnectorTest --invert' : '--grep PiConnectorTest';

const cmd = `npx mocha --reporter json ${flags} "test/**/*.test.ts"`;

let stdout = "";
let exitCode = 0;

try {
  stdout = execSync(cmd, {
    encoding: "utf8",
    maxBuffer: 100 * 1024 * 1024
  });
} catch (err) {
  stdout = err.stdout ? String(err.stdout) : "";
  exitCode = err.status || 1;
}

function escapeXml(str) {
  return String(str || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

let data = {
  stats: {},
  tests: []
};

try {
  const match = stdout.match(/\{\s*"stats"\s*:/);

  if (match) {
    const start = match.index;
    const end = stdout.lastIndexOf("}");

    if (end > start) {
      data = JSON.parse(stdout.substring(start, end + 1));
    }
  }
} catch (_) {}

const stats = data.stats || {};
const tests = data.tests || [];

let xml = `<?xml version="1.0" encoding="UTF-8"?>\n`;
xml += `<testsuites>\n`;
xml += `  <testsuite name="Mocha Tests" tests="${stats.tests || tests.length}" failures="${stats.failures || 0}" errors="0" skipped="${stats.pending || 0}" time="${((stats.duration || 0)/1000).toFixed(3)}">\n`;

for (const t of tests) {
  xml += `    <testcase classname="${escapeXml(t.fullTitle)}" name="${escapeXml(t.title)}" time="${((t.duration || 0)/1000).toFixed(3)}">`;

  if (t.err && (t.err.message || t.err.stack)) {
    xml += `<failure message="${escapeXml(t.err.message)}">${escapeXml(t.err.stack || t.err.message)}</failure>`;
  }

  xml += `</testcase>\n`;
}

xml += `  </testsuite>\n`;
xml += `</testsuites>\n`;

fs.mkdirSync(path.dirname(path.resolve(outputPath)), {
  recursive: true
});

fs.writeFileSync(outputPath, xml, "utf8");

process.exit(exitCode);
EOF