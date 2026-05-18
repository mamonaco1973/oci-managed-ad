# ==============================================================================
# SSH Key Pair
# Generated fresh each deploy — private key written to keys/ (gitignored)
# ==============================================================================

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "./keys/Private_Key"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content         = tls_private_key.ssh.public_key_openssh
  filename        = "./keys/Private_Key.pub"
  file_permission = "0644"
}

# ==============================================================================
# AD Account Passwords
# Passed to the DC via module user_data and output (sensitive) for 02-servers.
# ==============================================================================

resource "random_password" "administrator_password" {
  length           = 23
  special          = true
  min_numeric      = 2
  min_special      = 2
  # Restrict specials — password is interpolated into PS1 template strings
  override_special = "_-"
}

resource "random_password" "admin_domain_password" {
  length           = 23
  special          = true
  min_numeric      = 2
  min_special      = 2
  override_special = "_-"
}

resource "random_password" "windows_local_admin_password" {
  length           = 23
  special          = true
  min_numeric      = 2
  min_special      = 2
  override_special = "_-"
}

# ==============================================================================
# Domain User Passwords
# Generated here and passed to the DC post-reboot account creation script.
# Stored as sensitive outputs so they can be retrieved from tfstate.
# ==============================================================================

resource "random_password" "jsmith_password" {
  length           = 23
  special          = true
  min_numeric      = 2
  min_special      = 2
  # $ breaks PS1 double-quoted string interpolation — exclude it
  override_special = "!@#%"
}

resource "random_password" "edavis_password" {
  length           = 23
  special          = true
  min_numeric      = 2
  min_special      = 2
  override_special = "!@#%"
}

resource "random_password" "rpatel_password" {
  length           = 23
  special          = true
  min_numeric      = 2
  min_special      = 2
  override_special = "!@#%"
}

resource "random_password" "akumar_password" {
  length           = 23
  special          = true
  min_numeric      = 2
  min_special      = 2
  override_special = "!@#%"
}

# ==============================================================================
# Safe password locals
# Prepend "A" so the first character is always a known-safe uppercase letter.
# Guarantees no password starts with "-" and satisfies Windows complexity.
# ==============================================================================

locals {
  administrator_password       = "A${random_password.administrator_password.result}"
  admin_domain_password        = "A${random_password.admin_domain_password.result}"
  windows_local_admin_password = "A${random_password.windows_local_admin_password.result}"
  jsmith_password              = "A${random_password.jsmith_password.result}"
  edavis_password              = "A${random_password.edavis_password.result}"
  rpatel_password              = "A${random_password.rpatel_password.result}"
  akumar_password              = "A${random_password.akumar_password.result}"
}
