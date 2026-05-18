# oci-managed-ad

Two-phase Terraform deployment of a Windows Server 2022 Active Directory environment on OCI.

## Structure

```
01-directory/   VCN, DC (via module), bastion, all account passwords
02-servers/     Windows and Linux client instances (domain-join at boot)
```

## Two-Phase Deploy

Phase 1 (`01-directory`) must complete before phase 2 (`02-servers`). The DC bootstrap
takes 20–30 minutes — Terraform blocks until the `dc-ready` sentinel appears in Object Storage.
`02-servers` reads DC IP, passwords, and networking from `01-directory` remote state.

`apply.sh` and `destroy.sh` handle both phases in the correct order.

## AD User and Group Creation

Users and groups are created on the **Windows client** (`02-servers/scripts/userdata.ps1`),
NOT on the DC. The client waits for DNS to resolve, joins the domain, then runs
`New-ADUser` / `New-ADGroup` with full POSIX attributes. This matches the AWS/Azure/GCP pattern.

Never add AD account creation logic to the DC userdata or sentinel.

## POSIX Attributes

All AD groups must have `gidNumber`. All AD users must have `gidNumber` and `uidNumber`.
`ldap_id_mapping` in SSSD config must always be `False` — Linux clients use directory-assigned
IDs, not auto-mapped ones. Do not change this.

Current ID assignments:
- Groups: {netbios_lower}-users=10001, us=10002, india=10003, linux-admins=10004
- Users: jsmith=10001, edavis=10002, rpatel=10003, akumar=10004

## Account Passwords

Three separate password resources in `01-directory/accounts.tf`:
- `administrator_password` — built-in Administrator on DC (SSH/RDP access)
- `admin_domain_password` — `Admin` domain admin account (created in sentinel post-promotion)
- `windows_local_admin_password` — local fallback on DC and Windows client

Domain user passwords (`jsmith`, `edavis`, `rpatel`, `akumar`) use `override_special = "!@#%"`.
Admin account passwords use `override_special = "_-"` — these are interpolated into PS templates.

## Scripts

- `connect.sh` — SSH to DC via OCI Bastion port-forward. Falls back to OCI CLI lookup if
  terraform output is empty (useful when apply is still running or state is missing).
  Prints Administrator password before prompting. Forces password auth (`PubkeyAuthentication=no`).
- `rdp-connect.sh` — Same pattern but forwards port 3389. Holds tunnel open until Ctrl+C.
- `get_password.sh <user>` — Reads any password from tfstate.
  Valid users: `administrator`, `admin`, `windows_local_admin`, `jsmith`, `edavis`, `rpatel`, `akumar`
  `windows_local_admin` works for both the DC and the jumpbox.

## Module Source

`01-directory/ad.tf` sources the module from `github.com/mamonaco1973/module-oci-managed-ad`.
For local development, change the source to a relative path:
```hcl
source = "../../module-oci-managed-ad"
```

## OCI Vault — Why It Is Not Used

OCI KMS Vault imposes a mandatory 30-day pending-deletion hold that counts against the tenancy
vault limit (default: 1). This makes it incompatible with destroy/rebuild workflows — every
re-apply after a destroy fails with `LimitExceeded`. Passwords live in Terraform state instead.
