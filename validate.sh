#!/bin/bash
set -euo pipefail

# ================================================================================
# 01-directory outputs
# ================================================================================

DC_IP=$(cd 01-directory && terraform output -raw dc_private_ip 2>/dev/null || echo "")
BASTION_ID=$(cd 01-directory && terraform output -raw bastion_id 2>/dev/null || echo "")
DNS_ZONE=$(cd 01-directory && terraform output -raw dns_zone 2>/dev/null || echo "")

# ================================================================================
# 02-servers outputs
# ================================================================================

LINUX_IP=$(cd 02-servers && terraform output -raw linux_public_ip 2>/dev/null || echo "")
WINDOWS_IP=$(cd 02-servers && terraform output -raw windows_public_ip 2>/dev/null || echo "")

# ================================================================================
# Summary banner
# ================================================================================

echo ""
echo "============================================================================"
echo "Windows AD - Deployment Summary"
echo "============================================================================"
echo ""
echo "  Domain Controller (private)"
echo "    IP       : ${DC_IP:-not deployed}"
echo "    Connect  : ./connect.sh  (opens RDP tunnel to localhost:13389)"
echo ""
echo "  Linux Client (public)"
echo "    IP       : ${LINUX_IP:-not deployed}"
echo "    Connect  : ssh -i 01-directory/keys/Private_Key ubuntu@${LINUX_IP:-<ip>}"
echo "    AD login : ssh Administrator@${LINUX_IP:-<ip>}"
echo ""
echo "  Windows Client (public)"
echo "    IP       : ${WINDOWS_IP:-not deployed}"
echo "    Connect  : RDP to ${WINDOWS_IP:-<ip>} as ${DNS_ZONE%%.*}\\\\Administrator"
echo ""
echo "  Passwords  : ./get_password.sh <user>"
echo "               users: admin jsmith edavis rpatel akumar windows_local_admin"
echo ""
echo "============================================================================"
echo ""
