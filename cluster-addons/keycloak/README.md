# Keycloak

## Get admin username and password

```
oc get cm keycloak-env-vars -o json | jq -r '.data.KEYCLOAK_ADMIN' && \
oc get secret keycloak -o json | jq -r '.data."admin-password"' | base64 -d && \
echo ""
```
