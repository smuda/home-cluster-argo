#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SECRET_FILE=$1
SEALED_FILE=$2
CERT_FILE=${SCRIPT_DIR}/../kubeseal.pem

echo "Secret file: ${SECRET_FILE}"
echo "Certificate: ${CERT_FILE}"
kubeseal \
  --cert "${CERT_FILE}" \
  -o yaml \
  < "${SECRET_FILE}" \
  > "${SEALED_FILE}"
