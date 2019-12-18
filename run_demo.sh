#!/usr/bin/env bash

# requires: kubectl, skaffold
# optional: jq, xmllint

# Get directory this script is located in to access script local files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${SCRIPT_DIR}/common_scripts.sh"
source "${SCRIPT_DIR}/working_environment.sh"

# Will exit script if we would use an uninitialised variable (nounset) or when a
# simple command (not a control structure) fails (errexit)
set -eu
trap print_error ERR

# Configure OAuth Credentials
if [[ -f "${HOME}/scripts/secret/azure_credentials.sh" ]]; then
  # export AZURE_DOMAIN="login.microsoftonline.com"
  # export AZURE_TENANT='<tenant>'
  # export OAUTH_CLIENT_ID='<client id>'
  # export OUATH_CLIENT_SECRET='<client secret>'
  # export OAUTH_CLIENT_ID_2='<client id>'
  # export OUATH_CLIENT_SECRET_2='<client secret>'
  # export OAUTH_AUDIENCE='<application id>'
  source "${HOME}/scripts/secret/azure_credentials.sh"
fi

if [[ -z "${OAUTH_CLIENT_ID}" ]] || [[ -z "${OUATH_CLIENT_SECRET}" ]]; then
  echo 'Must set OAUTH_CLIENT_ID and OUATH_CLIENT_SECRET environment variables'
  exit
fi

AZURE_UPSTREAM='azure-oauth'
OPA_POLICY_CONFIGMAP='my-opa-policy'
OPA_AUTH_CONFIG='my-opa'

# Cleanup old examples
kubectl --namespace="${GLOO_NAMESPACE}" delete \
  --ignore-not-found='true' \
  virtualservice/default \
  configmap/"${OPA_POLICY_CONFIGMAP}" \
  authconfig/"${OPA_AUTH_CONFIG}" \
  upstream/"${AZURE_UPSTREAM}"

# Deploy SOAP Service
( cd soap-service && skaffold run )

# Deploy REST Service
( cd rest-service && skaffold run )

# Create policy ConfigMap
kubectl --namespace="${GLOO_NAMESPACE}" create configmap "${OPA_POLICY_CONFIGMAP}" \
  --from-file="${SCRIPT_DIR}/policy.rego"

kubectl apply --filename - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: "${OPA_AUTH_CONFIG}"
  namespace: "${GLOO_NAMESPACE}"
spec:
  configs:
  - opa_auth:
      modules:
      - name: "${OPA_POLICY_CONFIGMAP}"
        namespace: "${GLOO_NAMESPACE}"
      query: 'data.test.allow == true'
EOF

kubectl apply --filename - <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: "${AZURE_UPSTREAM}"
  namespace: "${GLOO_NAMESPACE}"
spec:
  static:
    hosts:
    - addr: "${AZURE_DOMAIN}"
      port: 443
    useTls: true
EOF

kubectl apply --filename - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: default
  namespace: gloo-system
spec:
  virtualHost:
    domains:
    - '*'
    routes:
    - matchers:
      - exact: /ws/countries.wsdl
        headers:
        - name: ver
          value: V1
      routeAction:
        single:
          kube:
            ref:
              name: soap-service-v1
              namespace: default
            port: 8080
      options:
        extauth:
          disable: true
        jwt:
          disable: true
    - matchers:
      - prefix: /ws
        headers:
        - name: ver
          value: V1
      routeAction:
        single:
          kube:
            ref:
              name: soap-service-v1
              namespace: default
            port: 8080
    - matchers:
      - exact: /ws/countries.wsdl
        headers:
        - name: ver
          value: V2
      routeAction:
        single:
          kube:
            ref:
              name: soap-service-v2
              namespace: default
            port: 8080
      options:
        extauth:
          disable: true
        jwt:
          disable: true
    - matchers:
      - prefix: /ws
      routeAction:
        single:
          kube:
            ref:
              name: soap-service-v2
              namespace: default
            port: 8080
    - matchers:
      - prefix: /hello
        headers:
        - name: ver
          value: V1
      routeAction:
        single:
          kube:
            ref:
              name: rest-service-v1
              namespace: default
            port: 8080
    - matchers:
      - prefix: /hello
      routeAction:
        single:
          kube:
            ref:
              name: rest-service-v2
              namespace: default
            port: 8080
    options:
      extauth:
        config_ref:
          name: "${OPA_AUTH_CONFIG}"
          namespace: "${GLOO_NAMESPACE}"
      jwt:
        providers:
          azure:
            issuer: "https://${AZURE_DOMAIN}/${AZURE_TENANT}/v2.0"
            audiences:
            - "${OAUTH_CLIENT_ID}"
            keep_token: true
            jwks:
              remote:
                url: "https://${AZURE_DOMAIN}/${AZURE_TENANT}/discovery/v2.0/keys"
                upstream_ref:
                  name: "${AZURE_UPSTREAM}"
                  namespace: "${GLOO_NAMESPACE}"
EOF

sleep 5

# Create localhost port-forward of Gloo Proxy as this works with kind and other Kubernetes clusters
port_forward_deployment "${GLOO_NAMESPACE}" 'gateway-proxy' '8080'

sleep 30

# Authenticate with to get Access Token
ACCESS_TOKEN=$(curl --silent --request POST \
  --url "https://${AZURE_DOMAIN}/${AZURE_TENANT}/oauth2/v2.0/token" \
  --form 'grant_type=client_credentials' \
  --form "scope=${OAUTH_AUDIENCE}/.default" \
  --form "client_id=${OAUTH_CLIENT_ID}" \
  --form "client_secret=${OUATH_CLIENT_SECRET}" | jq --raw-output '.access_token'
)

printf "\nAccess Token '%s'\n" "${ACCESS_TOKEN}"

ACCESS_TOKEN_2=$(curl --silent --request POST \
  --url "https://${AZURE_DOMAIN}/${AZURE_TENANT}/oauth2/v2.0/token" \
  --form 'grant_type=client_credentials' \
  --form "scope=${OAUTH_AUDIENCE}/.default" \
  --form "client_id=${OAUTH_CLIENT_ID_2}" \
  --form "client_secret=${OUATH_CLIENT_SECRET_2}" | jq --raw-output '.access_token'
)

printf "\nAccess Token 2 '%s'\n" "${ACCESS_TOKEN_2}"

# PROXY_URL=$(glooctl proxy url)
PROXY_URL='http://localhost:8080'

# Headers
# - ver -- service version to route request
# - authorization -- 'Bearer <jwt access token>'

printf "\nSOAP V2 WSDL\n"
curl --silent \
  --header "ver: V2" \
  --output "${SCRIPT_DIR}/soap-v2.wsdl" \
  "${PROXY_URL}/ws/countries.wsdl"

printf "\nSOAP V1 WSDL\n"
curl --silent \
  --header "ver: V1" \
  --output "${SCRIPT_DIR}/soap-v1.wsdl" \
  "${PROXY_URL}/ws/countries.wsdl"

printf "\nUser 1 (%s)\n" "${OAUTH_CLIENT_ID}"

printf "\nSOAP V2 - Succeed 200\n"
curl --silent \
  --header "content-type: text/xml" \
  --header "authorization: Bearer ${ACCESS_TOKEN}" \
  --header "ver: V2" \
  --write-out "\nHTTP Code: %{http_code}\n" \
  --data @"${SCRIPT_DIR}/soap-service/request.xml" \
  "${PROXY_URL}/ws"

printf "\nSOAP V1 - Succeed 200\n"
curl --silent \
  --header "content-type: text/xml" \
  --header "authorization: Bearer ${ACCESS_TOKEN}" \
  --header "ver: V1" \
  --write-out "\nHTTP Code: %{http_code}\n" \
  --data @"${SCRIPT_DIR}/soap-service/request.xml" \
  "${PROXY_URL}/ws"

printf "\nREST V2 - Succeed 200\n"
curl --silent \
  --header "authorization: Bearer ${ACCESS_TOKEN}" \
  --header "ver: V2" \
  --write-out "\nHTTP Code: %{http_code}\n" \
  "${PROXY_URL}/hello?name=Swagger"

printf "\nREST V1 - Fail 403\n"
curl --silent \
  --header "authorization: Bearer ${ACCESS_TOKEN}" \
  --header "ver: V1" \
  --write-out "\nHTTP Code: %{http_code}\n" \
  "${PROXY_URL}/hello?name=Swagger"

printf "\nUser 2 (%s)\n" "${OAUTH_CLIENT_ID_2}"

printf "\nSOAP V2 - Succeed 200\n"
curl --silent \
  --header "content-type: text/xml" \
  --header "authorization: Bearer ${ACCESS_TOKEN_2}" \
  --header "ver: V2" \
  --write-out "\nHTTP Code: %{http_code}\n" \
  --data @"${SCRIPT_DIR}/soap-service/request.xml" \
  "${PROXY_URL}/ws"

printf "\nSOAP V1 - Fail 403\n"
curl --silent \
  --header "content-type: text/xml" \
  --header "authorization: Bearer ${ACCESS_TOKEN_2}" \
  --header "ver: V1" \
  --write-out "\nHTTP Code: %{http_code}\n" \
  --data @"${SCRIPT_DIR}/soap-service/request.xml" \
  "${PROXY_URL}/ws"

printf "\nREST V2 - Succeed 200\n"
curl --silent \
  --header "authorization: Bearer ${ACCESS_TOKEN_2}" \
  --header "ver: V2" \
  --write-out "\nHTTP Code: %{http_code}\n" \
  "${PROXY_URL}/hello?name=Swagger"

printf "\nREST V1 - Succeed 200\n"
curl --silent \
  --header "authorization: Bearer ${ACCESS_TOKEN_2}" \
  --header "ver: V1" \
  --write-out "\nHTTP Code: %{http_code}\n" \
  "${PROXY_URL}/hello?name=Swagger"
