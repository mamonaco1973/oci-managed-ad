# OCI Managed Active Directory

This project deploys a production-grade **Windows Server 2022 Active Directory** environment on OCI using Terraform and automated configuration scripts. It provides a fully functional AD forest — domain controller, DNS, Kerberos, LDAP, Group Policy — without relying on a managed directory service.

![diagram](oci-managed-ad.png)

A Windows Server 2022 instance acts as both a Domain Controller and DNS server, integrated into a custom VCN with secure networking and OCI Bastion Service for private instance access. Windows and Linux client instances are also deployed and automatically domain-join at boot, enabling seamless AD authentication across platforms.

---

## Why Not a Managed Directory Service?

OCI Directory Service and similar managed offerings abstract away control. This solution gives you a real Windows AD DS forest — full Group Policy, schema extensions, POSIX attributes, native PowerShell AD cmdlets, and no vendor lock-in on directory semantics. You own the domain.

---

## Why We Did Not Use OCI Vault

OCI KMS Vault was the natural choice for storing generated AD passwords securely, and we did implement it initially. Each AD account password was stored as a versioned secret in a DEFAULT vault, and the Linux client retrieved its domain-join credential at boot using OCI instance principal authentication — so no plaintext password ever appeared in instance metadata or Terraform outputs.

However, OCI imposes a **mandatory 30-day pending-deletion hold** on KMS vaults after they are destroyed. During this hold the vault still counts against the tenancy service limit, which defaults to one vault per tenancy even on pay-as-you-go accounts. This makes the vault fundamentally incompatible with IaC destroy/rebuild workflows: every fresh `apply` after a `destroy` fails with `LimitExceeded` because the previous vault is still in `PENDING_DELETION`. The only workaround — cancelling the deletion and importing the vault back into Terraform state — is a manual operation that defeats repeatable automation.

AWS Secrets Manager and Azure Key Vault both handle deletion gracefully and do not block re-creation. This is an OCI platform deficiency.

**Current approach:** Passwords are stored as sensitive outputs in `terraform.tfstate`. Use `./get_password.sh` to retrieve any credential directly from Terraform state.

---

## Prerequisites

- An OCI account with sufficient compute quota for 3 x VM.Standard.E4.Flex instances
- [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm) configured with a DEFAULT profile in `~/.oci/config`
- [Terraform](https://developer.hashicorp.com/terraform/install) (latest)
- `jq` installed in PATH

---

## Download this Repository

```bash
git clone https://github.com/mamonaco1973/oci-managed-ad.git
cd oci-managed-ad
```

---

## Build the Code

Run `check_env.sh` to validate your environment, then run `apply.sh` to provision the infrastructure.

```bash
export OCI_COMPARTMENT_ID=<your-compartment-ocid>   # optional; falls back to tenancy OCID
./apply.sh
```

The deploy runs in two phases:

1. **01-directory** — VCN, subnets, bastion, and the Windows Server 2022 DC. Terraform blocks until the DC writes a `dc-ready` sentinel to OCI Object Storage, confirming AD is fully initialized before DHCP options are updated.
2. **02-servers** — Windows and Linux client instances that domain-join automatically at first boot.

Total build time is approximately 20–30 minutes end to end.

---

## Build Results

When the deployment completes, the following resources are created:

**Networking:**
- VCN with a public vm-subnet and a private ad-subnet
- Internet Gateway and NAT Gateway for controlled outbound access
- Route tables for public and private subnets
- OCI Network Security Group with all required AD/DC port rules

**Active Directory:**
- Windows Server 2022 instance (VM.Standard.E4.Flex) as a Domain Controller
- Private subnet placement — no public IP
- VCN DHCP options updated to point DNS at the DC after the sentinel confirms readiness

**Credentials:**
- All account passwords generated randomly and stored as sensitive outputs in `terraform.tfstate`
- Retrieved via `./get_password.sh` — no external secret store required

**Bastion:**
- OCI Bastion Service for SSH and RDP port-forwarding to the private DC

**Client Instances:**
- Ubuntu 24.04 Linux instance (VM.Standard.E4.Flex) joined to the domain via SSSD
- Windows Server 2022 instance (VM.Standard.E4.Flex) joined to the domain

---

## Users and Groups

The following users and groups are created automatically during provisioning.

### Groups

| Group Name   | gidNumber |
|--------------|-----------|
| mcloud-users | 10001     |
| us           | 10002     |
| india        | 10003     |
| linux-admins | 10004     |

### Users

| Username | Full Name   | uidNumber | gidNumber | Groups                            |
|----------|-------------|-----------|-----------|-----------------------------------|
| jsmith   | John Smith  | 10001     | 10001     | mcloud-users, us, linux-admins    |
| edavis   | Emily Davis | 10002     | 10001     | mcloud-users, us                  |
| rpatel   | Raj Patel   | 10003     | 10001     | mcloud-users, india, linux-admins |
| akumar   | Amit Kumar  | 10004     | 10001     | mcloud-users, india               |

All users carry POSIX attributes (`uidNumber`, `gidNumber`). Linux clients use `ldap_id_mapping = False` so directory-assigned IDs are used directly.

### Admin Accounts

| Account | Type | Notes |
|---------|------|-------|
| `Administrator` | Built-in local/domain | Primary DC access. Password never expires. |
| `Admin` | Domain admin | Secondary domain admin. DO NOT DELETE. |
| `windows_local_admin` | Local | Fallback local account on the DC and Windows client. |

---

## Connecting to the DC

The DC has no public IP. Use `connect.sh` to create an OCI Bastion port-forwarding session and open an SSH shell. The Administrator password is printed before the prompt:

```bash
./connect.sh            # connects to the DC
./connect.sh 10.0.0.x   # connects to any private IP
```

For RDP access, use `rdp-connect.sh` to open a tunnel to `localhost:3389`, then connect with your RDP client:

```bash
./rdp-connect.sh
```

---

## Retrieving Passwords

Passwords are read directly from Terraform state:

```bash
./get_password.sh administrator       # Built-in Administrator (SSH/RDP into DC)
./get_password.sh admin               # Admin domain account
./get_password.sh windows_local_admin # Local fallback account
./get_password.sh jsmith
./get_password.sh edavis
./get_password.sh rpatel
./get_password.sh akumar
```

Output:
```
Username : jsmith@mcloud.mikecloud.com
Password : <generated-password>
```

---

## Connecting to the Linux Instance

The Linux client has a public IP. SSH directly using the generated key:

```bash
ssh -i 01-directory/keys/Private_Key -o StrictHostKeyChecking=no ubuntu@<linux_public_ip>
```

Run `./validate.sh` to print the DC IP, bastion ID, and connection hints.

---

## Connecting to the Windows Instance

RDP to the Windows client public IP using domain credentials:

- **Username:** `MCLOUD\Admin` or any domain user from the table above
- **Password:** retrieved via `./get_password.sh <user>`

---

## Clean Up

```bash
./destroy.sh
```

Destroys 02-servers first, then 01-directory. All OCI resources are deleted immediately — no retention periods.
