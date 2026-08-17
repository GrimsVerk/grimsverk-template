#!/usr/bin/env bash
# Mint a short-lived GitHub App installation token for THIS repository, and
# print it on stdout. Nothing else prints there, so the caller can capture it.
#
# WHY THIS EXISTS. `owner-authored.sh` asks GitHub one question: who opened this
# pull request. It compares that login to the owner named in CODEOWNERS. When
# the owner clicks the button in a browser the answer is their login — and when
# `deliver-loop.sh` runs `gh pr create` on the owner's machine, under the
# owner's `gh` credentials, the answer is ALSO their login. GitHub cannot tell
# those apart, so the check passed for every pull request the driver has ever
# opened, including one carrying an agent's edit to docs/DESIGN.md. The
# guarantee read "the design was landed by its owner" and meant nothing.
#
# A separate identity is the whole fix. When the driver opens pull requests as
# the App, `app[bot]` is not the owner, so a driver-opened pull request touching
# docs/DESIGN.md or docs/VISION.md FAILS — correctly, loudly — and one the owner
# opened in a browser passes. The check becomes real for the first time.
#
# WHY NOT THE ACTIONS SECRETS. `setup-github.sh --app` stores APP_ID and
# APP_PRIVATE_KEY as repository secrets, which is what auto-merge.yml needs
# because it runs inside Actions. The driver runs on the owner's laptop, where
# repository secrets are unreadable by design. So the credentials have to exist
# locally too, and this script is the only thing that reads them.
#
# Configuration, in precedence order:
#   1. GRIMSVERK_APP_ID and GRIMSVERK_APP_PRIVATE_KEY environment variables
#      (the private key is a PATH to the .pem, never the key material itself —
#      a key in the environment leaks into every child process's /proc entry);
#   2. .claude/app-identity, an untracked file in the repository root holding
#      APP_ID=... and APP_PRIVATE_KEY=... (gitignored; see .gitignore.jinja).
#
# Exit codes are distinct because the caller treats them differently:
#   0  a token was minted and printed
#   3  not configured at all — the owner has not set the App up yet
#   4  configured but the exchange failed — wrong id, wrong key, App not
#      installed on this repository, or the network is down
#
# Both non-zero paths are a REFUSAL upstream, never a warning (docs/DECISIONS.md
# on the readiness check, and the owner's ruling that a run which cannot succeed
# must fail loudly before they walk away).

set -uo pipefail

fail() { echo "app-token: $*" >&2; exit "${EXIT_CODE:-4}"; }

command -v openssl >/dev/null 2>&1 || fail "openssl is not on PATH — it signs the App's JWT and there is no fallback"
command -v curl >/dev/null 2>&1 || fail "curl is not on PATH"

# ------------------------------------------------------------- configuration
APP_ID="${GRIMSVERK_APP_ID:-}"
KEY_PATH="${GRIMSVERK_APP_PRIVATE_KEY:-}"

IDENTITY_FILE="${GRIMSVERK_APP_IDENTITY_FILE:-.claude/app-identity}"
if [[ -z "$APP_ID" || -z "$KEY_PATH" ]] && [[ -f "$IDENTITY_FILE" ]]; then
  # Read as data, never sourced: a stray command in a credentials file would
  # otherwise run with the owner's shell.
  while IFS='=' read -r k v; do
    k="${k#"${k%%[![:space:]]*}"}"; k="${k%"${k##*[![:space:]]}"}"
    v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
    v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
    case "$k" in
      APP_ID)          [[ -z "$APP_ID"   ]] && APP_ID="$v" ;;
      APP_PRIVATE_KEY) [[ -z "$KEY_PATH" ]] && KEY_PATH="$v" ;;
    esac
  done < "$IDENTITY_FILE"
fi

if [[ -z "$APP_ID" || -z "$KEY_PATH" ]]; then
  EXIT_CODE=3 fail "no App identity configured.

The unattended driver must open pull requests as the App rather than as you.
Until it does, .github/scripts/owner-authored.sh cannot tell an agent's design
edit from one you wrote, because both arrive under your login.

To configure, either export both of these:

    GRIMSVERK_APP_ID=<the App's numeric id>
    GRIMSVERK_APP_PRIVATE_KEY=/absolute/path/to/private-key.pem

or write ${IDENTITY_FILE} (untracked) containing:

    APP_ID=<the App's numeric id>
    APP_PRIVATE_KEY=/absolute/path/to/private-key.pem

If the App does not exist yet, create it once per account and install it on
this repository: scripts/setup-github.sh --app prints the exact URL and the
permission list."
fi

[[ -f "$KEY_PATH" ]] || EXIT_CODE=3 fail "App private key not found at '$KEY_PATH' — APP_PRIVATE_KEY must be the PATH to the .pem file, not the key itself"
[[ -r "$KEY_PATH" ]] || EXIT_CODE=3 fail "App private key at '$KEY_PATH' is not readable"
[[ "$APP_ID" =~ ^[0-9]+$ ]] || EXIT_CODE=3 fail "APP_ID '$APP_ID' is not numeric — this is the App ID from its settings page, not the client id and not the installation id"

# ------------------------------------------------------------- which repository
REPO="${GITHUB_REPOSITORY:-}"
if [[ -z "$REPO" ]]; then
  origin="$(git config --get remote.origin.url 2>/dev/null || true)"
  [[ -n "$origin" ]] || fail "no git remote 'origin' and GITHUB_REPOSITORY is unset — cannot tell which repository to mint a token for"
  # Handles https://, ssh://, git@host:owner/repo and any host alias, because
  # the SSH alias ceremony in README.md means 'origin' is often not github.com.
  REPO="${origin%.git}"; REPO="${REPO##*:}"; REPO="${REPO#//}"
  REPO="$(printf '%s' "$REPO" | awk -F/ '{ if (NF>=2) printf "%s/%s", $(NF-1), $NF }')"
  [[ "$REPO" == */* ]] || fail "could not read owner/repo out of remote '$origin'"
fi

# ------------------------------------------------------------------- the JWT
# RS256 over {header}.{payload}, base64url with the padding stripped. `iat` is
# backdated 60s because GitHub rejects a token whose issue time is ahead of its
# clock, and laptop clocks drift.
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
now="$(date +%s)"
header='{"alg":"RS256","typ":"JWT"}'
payload="$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$((now - 60))" "$((now + 540))" "$APP_ID")"
signing_input="$(printf '%s' "$header" | b64url).$(printf '%s' "$payload" | b64url)"
signature="$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign "$KEY_PATH" 2>/dev/null | b64url)" \
  || fail "could not sign the JWT with '$KEY_PATH' — is it the App's PEM private key?"
[[ -n "$signature" ]] || fail "signing produced nothing — '$KEY_PATH' is not a usable RSA private key"
JWT="${signing_input}.${signature}"

api() { # api <method> <path> — the JWT goes in a header, never on the command line
  curl -sS -X "$1" \
    -H "Authorization: Bearer ${JWT}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -w '\n%{http_code}' \
    "https://api.github.com$2" 2>/dev/null
}

# ---------------------------------------------------------- the installation
resp="$(api GET "/repos/${REPO}/installation")" || fail "could not reach api.github.com"
code="$(tail -n1 <<<"$resp")"; body="$(sed '$d' <<<"$resp")"

case "$code" in
  200) : ;;
  401) fail "GitHub rejected the App's JWT (401). The App ID and the private key do not match, or the key has been revoked. Check the App's settings page and generate a fresh key if needed." ;;
  404) fail "the App is not installed on ${REPO} (404).

The App exists (or the id is wrong) but it has no installation here, so it
cannot act on this repository. Install it: the App's settings page ->
Install App -> pick ${REPO}." ;;
  *)   fail "unexpected ${code} asking GitHub for the App's installation on ${REPO}: $(tr -d '\n' <<<"$body" | cut -c1-300)" ;;
esac

INSTALL_ID="$(printf '%s' "$body" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)"
[[ -n "$INSTALL_ID" ]] || fail "could not read the installation id out of GitHub's reply"

# ------------------------------------------------------------------ the token
resp="$(api POST "/app/installations/${INSTALL_ID}/access_tokens")" || fail "could not reach api.github.com"
code="$(tail -n1 <<<"$resp")"; body="$(sed '$d' <<<"$resp")"
[[ "$code" == "201" ]] || fail "GitHub returned ${code} minting the installation token: $(tr -d '\n' <<<"$body" | cut -c1-300)"

TOKEN="$(printf '%s' "$body" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[[ -n "$TOKEN" ]] || fail "GitHub replied 201 but the token field was not where it should be"

printf '%s\n' "$TOKEN"
