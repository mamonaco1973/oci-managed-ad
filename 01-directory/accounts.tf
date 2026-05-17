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
  length           = 24
  special          = true
  # Restrict specials — password is interpolated into PS1 template strings
  override_special = "_-"
}

resource "random_password" "admin_domain_password" {
  length           = 24
  special          = true
  override_special = "_-"
}

resource "random_password" "windows_local_admin_password" {
  length           = 24
  special          = true
  override_special = "_-"
}

# ==============================================================================
# Domain User Passwords
# Generated here and passed to the DC post-reboot account creation script.
# Stored as sensitive outputs so they can be retrieved from tfstate.
# ==============================================================================

resource "random_password" "jsmith_password" {
  length           = 24
  special          = true
  # $ breaks PS1 double-quoted string interpolation — exclude it
  override_special = "!@#%"
}

resource "random_password" "edavis_password" {
  length           = 24
  special          = true
  override_special = "!@#%"
}

resource "random_password" "rpatel_password" {
  length           = 24
  special          = true
  override_special = "!@#%"
}

resource "random_password" "akumar_password" {
  length           = 24
  special          = true
  override_special = "!@#%"
}
