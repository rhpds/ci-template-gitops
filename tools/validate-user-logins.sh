#!/bin/bash
set -euo pipefail

KEYCLOAK_ROUTE=$(oc get route keycloak -n keycloak -o jsonpath='{.spec.host}')
ADMIN_USER=$(oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d)

TOKEN=$(curl -sk -X POST "https://${KEYCLOAK_ROUTE}/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

REALMS=$(oc get keycloakrealmimports -n keycloak -o jsonpath='{.items[*].spec.realm.realm}')

PASS=0
FAIL=0

printf "%-20s %-30s %-10s\n" "REALM" "USERNAME" "STATUS"
printf '%s\n' "$(printf '%.0s-' {1..60})"

for REALM in ${REALMS}; do
  # Get users from Keycloak API
  USERS=$(curl -sk -H "Authorization: Bearer ${TOKEN}" \
    "https://${KEYCLOAK_ROUTE}/admin/realms/${REALM}/users?max=1000")

  # Load passwords from credentials secrets
  if [ "${REALM}" = "hub" ]; then
    SECRET_JSON=$(oc get secret hub-credentials -n keycloak -o json 2>/dev/null || echo '{"data":{}}')
  else
    SECRET_JSON=$(oc get secret "tenant-${REALM}-credentials" -n keycloak -o json 2>/dev/null || echo '{"data":{}}')
  fi

  # Build username->password pairs
  USERS_AND_PASSWORDS=$(echo "${USERS}" | python3 -c "
import sys, json, base64
users = json.load(sys.stdin)
secret = json.loads('''${SECRET_JSON}''')
data = secret.get('data', {})
passwords = {k: base64.b64decode(v).decode() for k, v in data.items()}
realm = '${REALM}'
for u in users:
    username = u.get('username', '')
    if realm == 'hub':
        pw = passwords.get(username + '-password', '')
    else:
        base = username.split('@')[0] if '@' in username else username
        pw = passwords.get(base, '')
    if pw:
        print(username + '\t' + pw)
" 2>/dev/null || true)

  if [ -z "${USERS_AND_PASSWORDS}" ]; then
    printf "%-20s %-30s %-10s\n" "${REALM}" "(no users with passwords)" "SKIP"
    continue
  fi

  while IFS=$'\t' read -r USERNAME PASSWORD; do
    [ -z "${USERNAME}" ] && continue
    [ -z "${PASSWORD}" ] && continue

    RESPONSE=$(curl -sk -o /dev/null -w "%{http_code}" \
      -X POST "https://${KEYCLOAK_ROUTE}/realms/${REALM}/protocol/openid-connect/token" \
      -d "grant_type=password" \
      -d "client_id=admin-cli" \
      -d "username=${USERNAME}" \
      -d "password=${PASSWORD}")

    if [ "${RESPONSE}" = "200" ]; then
      printf "%-20s %-30s %-10s\n" "${REALM}" "${USERNAME}" "OK"
      PASS=$((PASS + 1))
    else
      printf "%-20s %-30s %-10s\n" "${REALM}" "${USERNAME}" "FAIL (${RESPONSE})"
      FAIL=$((FAIL + 1))
    fi
  done <<< "${USERS_AND_PASSWORDS}"
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
exit "${FAIL}"
