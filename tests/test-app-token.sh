#!/usr/bin/env bash
#
# app-token.sh — fixture tests against a STUB curl and a throwaway RSA key.
#
# This script is what gives the unattended driver a login that is not the
# owner's. Until it existed, `deliver-loop.sh` opened every pull request under
# the owner's own `gh` credentials, so `owner-authored.sh` compared the owner's
# login to the owner's login and passed — including on a pull request carrying
# an agent's edit to docs/DESIGN.md. The guarantee was printed and absent.
#
# What these tests pin: the three misconfiguration paths exit 3 (not yet set
# up) and the exchange failures exit 4 (set up, but wrong), because the driver
# prints a different refusal for each; the identity file is read as DATA and
# never sourced; and a minted token is the only thing that reaches stdout, so a
# caller can capture it without filtering.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

SCRIPT="$HERE/../template/.claude/scripts/app-token.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== app-token.sh ==="

# ------------------------------------------------------------------ fixtures
mkdir -p "$WORK/bin" "$WORK/repo"
init_repo "$WORK/repo"
git -C "$WORK/repo" remote add origin "https://github.com/owner/proj.git"

# A real key, because the script really signs with openssl and a fake one would
# make the signing assertions vacuous.
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out "$WORK/key.pem" 2>/dev/null
[[ -s "$WORK/key.pem" ]] || { echo "could not generate a test key"; exit 2; }

# Stub curl. Answers by endpoint, and records the Authorization header so the
# JWT's shape can be asserted without a network.
cat > "$WORK/bin/curl" <<'STUB'
#!/usr/bin/env bash
url=""; auth=""
prev=""
for a in "$@"; do
  case "$prev" in -H) [[ "$a" == Authorization:* ]] && auth="$a" ;; esac
  case "$a" in https://*) url="$a" ;; esac
  prev="$a"
done
printf '%s\n' "$auth" >> "${AUTH_LOG:-/dev/null}"
case "$url" in
  */installation)
    code="${STUB_INSTALL_CODE:-200}"
    if [[ "$code" == "200" ]]; then printf '{"id": 42, "app_id": 7}'
    else printf '{"message": "Not Found"}'; fi
    printf '\n%s' "$code" ;;
  */access_tokens)
    code="${STUB_TOKEN_CODE:-201}"
    if [[ "$code" == "201" ]]; then printf '{"token": "ghs_minted_ok", "expires_at": "2026-01-01T00:00:00Z"}'
    else printf '{"message": "nope"}'; fi
    printf '\n%s' "$code" ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/curl"

run() { # run [NAME=value ...]
  ( cd "$WORK/repo" && env PATH="$WORK/bin:$PATH" "$@" bash "$SCRIPT" 2>&1 )
}

# ------------------------------------------------ not configured at all (rc 3)
out="$(run GRIMSVERK_APP_ID= GRIMSVERK_APP_PRIVATE_KEY= GRIMSVERK_APP_IDENTITY_FILE=/nonexistent)"
expect_rc "no configuration exits 3, not 4" 3 $?
expect_contains "and names the environment variables" "$out" "GRIMSVERK_APP_ID"
expect_contains "and names the identity file" "$out" "APP_PRIVATE_KEY"
expect_contains "and says why the driver needs it" "$out" "owner-authored.sh"
expect_contains "and points at the setup command" "$out" "setup-github.sh --app"

# ------------------------------------------------------- bad configuration
out="$(run GRIMSVERK_APP_ID=not-a-number GRIMSVERK_APP_PRIVATE_KEY="$WORK/key.pem" \
           GRIMSVERK_APP_IDENTITY_FILE=/nonexistent)"
expect_rc "a non-numeric App ID exits 3" 3 $?
expect_contains "and says which id is wanted" "$out" "not the client id"

out="$(run GRIMSVERK_APP_ID=7 GRIMSVERK_APP_PRIVATE_KEY="$WORK/absent.pem" \
           GRIMSVERK_APP_IDENTITY_FILE=/nonexistent)"
expect_rc "a missing key file exits 3" 3 $?
expect_contains "and says the value is a path" "$out" "PATH to the .pem"

# ----------------------------------------- the identity file is data, not code
# A credentials file that gets sourced runs whatever is in it with the owner's
# shell. This asserts the parser never evaluates a value.
cat > "$WORK/identity" <<EOF
APP_ID=7
APP_PRIVATE_KEY=$WORK/key.pem
PWNED=\$(touch $WORK/pwned)
EOF
out="$(run GRIMSVERK_APP_ID= GRIMSVERK_APP_PRIVATE_KEY= \
           GRIMSVERK_APP_IDENTITY_FILE="$WORK/identity" AUTH_LOG="$WORK/auth.log")"
rc=$?
if [[ -e "$WORK/pwned" ]]; then
  no "the identity file is read as data, never sourced" "a command in it executed"
else
  ok "the identity file is read as data, never sourced"
fi
expect_rc "and a well-formed identity file mints a token" 0 "$rc"
expect_contains "and the token is the only thing on stdout" "$out" "ghs_minted_ok"
if [[ "$out" == "ghs_minted_ok" ]]; then
  ok "stdout carries nothing a caller would have to filter"
else
  no "stdout carries nothing a caller would have to filter" "got: $out"
fi

# ------------------------------------------------------------------- the JWT
auth="$(head -1 "$WORK/auth.log" 2>/dev/null)"
expect_contains "the credential travels in a header, not on the command line" "$auth" "Authorization: Bearer "
jwt="${auth#Authorization: Bearer }"
dots="${jwt//[^.]/}"
if [[ "${#dots}" == "2" ]]; then
  ok "the JWT has three base64url segments"
else
  no "the JWT has three base64url segments" "segments: $((${#dots} + 1))"
fi
expect_not_contains "the JWT carries no base64 padding" "$jwt" "="

# ------------------------------------------------- exchange failures (rc 4)
out="$(run GRIMSVERK_APP_ID=7 GRIMSVERK_APP_PRIVATE_KEY="$WORK/key.pem" \
           GRIMSVERK_APP_IDENTITY_FILE=/nonexistent STUB_INSTALL_CODE=404)"
expect_rc "an uninstalled App exits 4, not 3" 4 $?
expect_contains "and says it is an installation problem" "$out" "not installed"
expect_contains "and names the repository it looked for" "$out" "owner/proj"

out="$(run GRIMSVERK_APP_ID=7 GRIMSVERK_APP_PRIVATE_KEY="$WORK/key.pem" \
           GRIMSVERK_APP_IDENTITY_FILE=/nonexistent STUB_INSTALL_CODE=401)"
expect_rc "a rejected JWT exits 4" 4 $?
expect_contains "and blames the id/key pair rather than the network" "$out" "do not match"

out="$(run GRIMSVERK_APP_ID=7 GRIMSVERK_APP_PRIVATE_KEY="$WORK/key.pem" \
           GRIMSVERK_APP_IDENTITY_FILE=/nonexistent STUB_TOKEN_CODE=500)"
expect_rc "a failed token exchange exits 4" 4 $?
expect_contains "and reports the status it got" "$out" "500"

# ------------------------------------------------------- repository detection
# The README's SSH alias ceremony means 'origin' is often not github.com, so the
# owner/repo parse has to survive an alias host.
git -C "$WORK/repo" remote set-url origin "git@gh-grimsverk:GrimsVerk/thing.git"
out="$(run GRIMSVERK_APP_ID=7 GRIMSVERK_APP_PRIVATE_KEY="$WORK/key.pem" \
           GRIMSVERK_APP_IDENTITY_FILE=/nonexistent STUB_INSTALL_CODE=404)"
expect_contains "an ssh alias remote still yields owner/repo" "$out" "GrimsVerk/thing"

summary
