#!/bin/bash
set -euo pipefail

VALID_USERS="administrator admin windows_local_admin jumpbox jsmith edavis rpatel akumar"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <user>"
  echo "Valid users: $VALID_USERS"
  exit 1
fi

USER="$1"

case "$USER" in
  administrator)       OUTPUT="administrator_password" ;;
  admin)               OUTPUT="admin_domain_password" ;;
  windows_local_admin) OUTPUT="windows_local_admin_password" ;;
  jumpbox)             OUTPUT="jumpbox_admin_password" ;;
  jsmith)              OUTPUT="jsmith_password" ;;
  edavis)              OUTPUT="edavis_password" ;;
  rpatel)              OUTPUT="rpatel_password" ;;
  akumar)              OUTPUT="akumar_password" ;;
  *)
    echo "ERROR: Unknown user '$USER'"
    echo "Valid users: $VALID_USERS"
    exit 1
    ;;
esac

PASSWORD=$(cd 01-directory && terraform output -raw "$OUTPUT" 2>/dev/null)
DNS_ZONE=$(cd 01-directory && terraform output -raw dns_zone 2>/dev/null)

if [ -z "$PASSWORD" ]; then
  echo "ERROR: could not read $OUTPUT from tfstate — has 01-directory been applied?"
  exit 1
fi

case "$USER" in
  administrator)       echo "Username : Administrator (built-in local/domain)" ;;
  windows_local_admin) echo "Username : windows_local_admin (local account on DC)" ;;
  jumpbox)             echo "Username : windows_local_admin (jump box local)" ;;
  *)                   echo "Username : ${USER}@${DNS_ZONE}" ;;
esac
echo "Password : ${PASSWORD}"
