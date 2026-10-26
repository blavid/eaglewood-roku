#!/usr/bin/env bash
# Exercise deploy.sh without a television.
# A fake curl records its arguments and returns a canned installer page.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REAL_PATH="$PATH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$FAKE_CURL_ARGV"
output=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    if [[ "${args[$i]}" == "--output" ]]; then
        output="${args[$((i + 1))]}"
    fi
done
if [[ -n "$output" ]]; then
    printf '%s' "$FAKE_CURL_BODY" > "$output"
fi
printf '%s' "${FAKE_HTTP_CODE:-200}"
exit "${FAKE_CURL_EXIT:-0}"
EOF
chmod 755 "$TMP/curl"

run_case() {
    local name="$1"
    local body="$2"
    local code="$3"
    local expect="$4"
    local password="$5"
    rm -f "$TMP/argv" "$TMP/out"
    export FAKE_CURL_ARGV="$TMP/argv"
    export FAKE_CURL_BODY="$body"
    export FAKE_HTTP_CODE="$code"
    export FAKE_CURL_EXIT=0
    export PATH="$TMP:$REAL_PATH"
    export ROKUPASS="$password"
    export ROKU_IP="127.0.0.1"
    set +e
    "$ROOT/scripts/deploy.sh" >"$TMP/out" 2>&1
    local status=$?
    set -e
    if [[ "$status" -ne "$expect" ]]; then
        echo "FAIL $name exit $status, expected $expect"
        cat "$TMP/out"
        exit 1
    fi
    if grep -F -q "$password" "$TMP/out" "$TMP/argv"; then
        echo "FAIL $name leaked the password into output or curl arguments"
        exit 1
    fi
    echo "ok $name"
}

run_case "success" '<html><font color="red">Install Success.</font>' 200 0 's3cret-value'
run_case "failure" '<html><font color="red">Install Failure: Identical to previous version.</font>' 200 1 's3cret-value'
run_case "auth" '<html>Unauthorized</html>' 401 1 's3cret"value\with-slash'

# Missing password must fail before any upload and must not print a prior secret.
env -u ROKUPASS ROKU_IP=127.0.0.1 PATH="$REAL_PATH" "$ROOT/scripts/deploy.sh" >"$TMP/missing.out" 2>&1 && {
    echo "FAIL missing password exited 0"
    exit 1
}
if grep -q "s3cret" "$TMP/missing.out"; then
    echo "FAIL missing-password output contained a password"
    exit 1
fi
echo "ok missing password"

# Curl config quoting survives a quote and a backslash. Connection failure is expected.
cfg="$TMP/quote.cfg"
ROKUPASS='a"b\c d' ROKU_IP="127.0.0.1" python3 - "$cfg" <<'PY'
import os, sys
password = os.environ["ROKUPASS"]
def curl_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    handle.write("digest\n")
    handle.write("user = " + curl_quote("rokudev:" + password) + "\n")
    handle.write("silent\n")
    handle.write("connect-timeout = 1\n")
    handle.write("max-time = 2\n")
PY
set +e
PATH="$REAL_PATH" curl --config "$cfg" --output /dev/null --write-out "%{http_code}" "http://127.0.0.1:9/plugin_install" >"$TMP/quote.out" 2>"$TMP/quote.err"
quote_status=$?
set -e
if grep -qi "error while reading config" "$TMP/quote.err" || grep -qi "unquoted" "$TMP/quote.err"; then
    echo "FAIL curl rejected the password quoting"
    cat "$TMP/quote.err"
    exit 1
fi
echo "ok curl config quoting (curl exit ${quote_status})"
echo "deploy tests ok"
