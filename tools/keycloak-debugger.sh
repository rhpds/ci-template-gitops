#!/bin/bash
set -euo pipefail

CONSOLE_ROUTE=$(oc get route console -n openshift-console -o jsonpath='{.spec.host}')
echo "OpenShift Console: https://${CONSOLE_ROUTE}"
echo ""

ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
ARGOCD_PASS=$(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)

echo "ArgoCD Console: https://${ARGOCD_ROUTE}"
echo "ArgoCD username: admin"
echo "ArgoCD password: ${ARGOCD_PASS}"
echo ""

KEYCLOAK_ROUTE=$(oc get route keycloak -n keycloak -o jsonpath='{.spec.host}')
ADMIN_USER=$(oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d)

echo "Keycloak Admin Console: https://${KEYCLOAK_ROUTE}/admin"
echo "Admin username: ${ADMIN_USER}"
echo "Admin password: ${ADMIN_PASS}"
echo ""

TOKEN=$(curl -sk -X POST "https://${KEYCLOAK_ROUTE}/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

REALMS=$(oc get keycloakrealmimports -n keycloak -o jsonpath='{.items[*].spec.realm.realm}')

for REALM in ${REALMS}; do
  USERS=$(curl -sk -H "Authorization: Bearer ${TOKEN}" \
    "https://${KEYCLOAK_ROUTE}/admin/realms/${REALM}/users?max=1000&briefRepresentation=false")

  # Load passwords from the credentials secrets
  if [ "${REALM}" = "hub" ]; then
    SECRET_PASSWORDS=$(oc get secret hub-credentials -n keycloak -o json 2>/dev/null | \
      python3 -c "
import sys, json, base64
data = json.load(sys.stdin).get('data', {})
passwords = {}
for k, v in data.items():
    passwords[k] = base64.b64decode(v).decode()
print(json.dumps(passwords))
" 2>/dev/null || echo '{}')
  else
    SECRET_PASSWORDS=$(oc get secret "tenant-${REALM}-credentials" -n keycloak -o json 2>/dev/null | \
      python3 -c "
import sys, json, base64
data = json.load(sys.stdin).get('data', {})
passwords = {}
for k, v in data.items():
    passwords[k] = base64.b64decode(v).decode()
print(json.dumps(passwords))
" 2>/dev/null || echo '{}')
  fi

  echo "$USERS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
passwords = json.loads('''${SECRET_PASSWORDS}''')
realm = '${REALM}'
users = [u for u in (data if isinstance(data, list) else []) if isinstance(u, dict)]
if not users:
    print(f'Realm: {realm} (no users)')
    print()
    sys.exit(0)
print(f'Realm: {realm} ({len(users)} users)')
print(f'{\"REALM\":<20} {\"USERNAME\":<30} {\"PASSWORD\":<20} {\"EMAIL\":<35} {\"TYPE\"}')
print('-' * 115)
for u in users:
    username = u.get('username', '')
    federated = u.get('federatedIdentities', [])
    if federated:
        user_type = 'federated (' + federated[0].get('identityProvider', '') + ')'
    else:
        user_type = 'local'
    # Try matching by username (hub: ssoadmin, tenant: user1@realm)
    # For hub secrets, key is 'ssoadmin-password' for ssoadmin
    pw = ''
    if realm == 'hub':
        pw = passwords.get(username + '-password', '')
    else:
        # tenant secret keys are just the prefix (user1, user2)
        base = username.split('@')[0] if '@' in username else username
        pw = passwords.get(base, '')
    print(f'{realm:<20} {username:<30} {pw:<20} {u.get(\"email\", \"\"):<35} {user_type}')
print()
"
done
