#!/usr/bin/env bash
# shellcheck disable=SC2034

# Get directory this script is located in to access script local files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${SCRIPT_DIR}/common_scripts.sh"
source "${SCRIPT_DIR}/working_environment.sh"

cleanup_port_forward_deployment 'gateway-proxy'

kubectl --namespace='gloo-system' delete \
  --ignore-not-found='true' \
  virtualservice/default \
  upstream/azure-oauth

# Delete SOAP Service
( cd soap-service && skaffold delete )

# Delete REST Service
( cd rest-service && skaffold delete )

rm -f "${SCRIPT_DIR}/soap-v1.wsdl" "${SCRIPT_DIR}/soap-v2.wsdl"
