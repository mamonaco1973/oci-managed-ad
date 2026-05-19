<powershell>
$ErrorActionPreference = 'Stop'
$ProgressPreference   = 'SilentlyContinue'

$Log = 'C:\ProgramData\userdata.log'
New-Item -Path $Log -ItemType File -Force | Out-Null
Start-Transcript -Path $Log -Append -Force

try {
    Write-Output "Starting PowerShell user-data at $(Get-Date -Format o)"

    # ----------------------------------------------------------------------
    # OS baseline
    # ----------------------------------------------------------------------
    Write-Output "Setting local windows_local_admin account for RDP fallback"
    $localPassword = "${windows_local_admin_password}" | ConvertTo-SecureString -AsPlainText -Force
    New-LocalUser -Name "windows_local_admin" -Password $localPassword `
        -PasswordNeverExpires -ErrorAction SilentlyContinue
    # Set-LocalUser ensures the password is applied even if the account already exists
    Set-LocalUser -Name "windows_local_admin" -Password $localPassword -PasswordNeverExpires $true
    Add-LocalGroupMember -Group "Administrators"         -Member "windows_local_admin" -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group "Remote Desktop Users"   -Member "windows_local_admin" -ErrorAction SilentlyContinue

    Write-Output "Enabling NLA so MSTSC prompts for credentials before session starts"
    Set-ItemProperty `
        -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
        -Name "UserAuthentication" -Value 1

    Write-Output "Disabling IPv6 — OCI subnets are IPv4-only"
    Get-NetAdapterBinding -ComponentID ms_tcpip6 | Disable-NetAdapterBinding

    Write-Output "Disabling Windows Update — prevents download contention during provisioning"
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Set-Service wuauserv -StartupType Disabled

    Write-Output "Installing AD management Windows features"
    Install-WindowsFeature -Name GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server | Out-Null

    # ----------------------------------------------------------------------
    # Wait for domain DNS — DC bootstrap takes up to 20 minutes
    # ----------------------------------------------------------------------
    Write-Output "Waiting for DNS to resolve ${domain_fqdn}..."
    $dnsReady = $false
    for ($i = 1; $i -le 40; $i++) {
        try {
            Resolve-DnsName "${domain_fqdn}" -ErrorAction Stop | Out-Null
            Write-Output "DNS ready after $($i * 30)s"
            $dnsReady = $true
            break
        } catch {
            Write-Output "DNS not ready ($i/40), retrying in 30s..."
            Start-Sleep -Seconds 30
        }
    }
    if (-not $dnsReady) { throw "DNS did not resolve ${domain_fqdn} after 20 minutes" }

    # ----------------------------------------------------------------------
    # Domain join (idempotent)
    # ----------------------------------------------------------------------
    $adminPassword = "${admin_password}" | ConvertTo-SecureString -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential `
        ("${netbios}\Admin", $adminPassword)

    $didJoin = $false
    $cs = Get-CimInstance Win32_ComputerSystem

    if ($cs.PartOfDomain -and $cs.Domain -ieq "${domain_fqdn}") {
        Write-Output "Already joined to ${domain_fqdn}"
    } else {
        Write-Output "Joining domain ${domain_fqdn}"
        Add-Computer -DomainName "${domain_fqdn}" -Credential $cred -Force
        $didJoin = $true
    }

    # ----------------------------------------------------------------------
    # AD group helper (idempotent)
    # ----------------------------------------------------------------------
    function New-AdGroupIfMissing {
        param ($Name, $Gid)
        try {
            New-ADGroup -Name $Name -GroupCategory Security -GroupScope Global `
                -Credential $cred `
                -OtherAttributes @{ gidNumber = $Gid } `
                -ErrorAction Stop | Out-Null
            Write-Output "Created group: $Name (gid=$Gid)"
        } catch {
            if ($_.Exception.Message -match "already exists") {
                Write-Output "Group already exists: $Name"
            } else { throw }
        }
    }

    Write-Output "Ensuring AD groups exist"
    New-AdGroupIfMissing "${lower(netbios)}-users"  10001
    New-AdGroupIfMissing "india"         10002
    New-AdGroupIfMissing "us"            10003
    New-AdGroupIfMissing "linux-admins"  10004

    # ----------------------------------------------------------------------
    # AD user helper (idempotent)
    # ----------------------------------------------------------------------
    function New-AdUserIfMissing {
        param ($Username, $GivenName, $Surname, $DisplayName, $Email, $PlainPass, $UidNumber, $Groups)

        $secPass = $PlainPass | ConvertTo-SecureString -AsPlainText -Force
        try {
            New-ADUser `
                -Name              $Username `
                -GivenName         $GivenName `
                -Surname           $Surname `
                -DisplayName       $DisplayName `
                -EmailAddress      $Email `
                -UserPrincipalName "$Username@${domain_fqdn}" `
                -SamAccountName    $Username `
                -AccountPassword   $secPass `
                -Enabled           $true `
                -Credential        $cred `
                -PasswordNeverExpires $true `
                -OtherAttributes   @{ gidNumber = 10001; uidNumber = $UidNumber; uid = $Username } `
                -ErrorAction Stop | Out-Null
            Write-Output "Created user: $Username (uid=$UidNumber)"
        } catch {
            if ($_.Exception.Message -match "already exists") {
                Write-Output "User already exists: $Username"
            } else { throw }
        }

        # Ensure POSIX attributes are set even if user pre-existed
        Set-ADUser -Identity $Username -Credential $cred `
            -Replace @{ uidNumber = $UidNumber; gidNumber = 10001; uid = $Username }

        foreach ($group in $Groups) {
            try {
                Add-ADGroupMember -Identity $group -Members $Username `
                    -Credential $cred -ErrorAction Stop
            } catch {
                if ($_.Exception.Message -match "already a member") {
                    Write-Output "$Username already in $group"
                } else { throw }
            }
        }
    }

    Write-Output "Ensuring AD users exist"
    New-AdUserIfMissing "jsmith"  "John"  "Smith" "John Smith"  "jsmith@${domain_fqdn}"  "${jsmith_password}"  10001 @("${lower(netbios)}-users","us","linux-admins","Domain Admins")
    New-AdUserIfMissing "edavis" "Emily" "Davis" "Emily Davis" "edavis@${domain_fqdn}" "${edavis_password}" 10002 @("${lower(netbios)}-users","us")
    New-AdUserIfMissing "rpatel" "Raj"   "Patel" "Raj Patel"   "rpatel@${domain_fqdn}"  "${rpatel_password}"  10003 @("${lower(netbios)}-users","india","linux-admins","Domain Admins")
    New-AdUserIfMissing "akumar" "Amit"  "Kumar" "Amit Kumar"  "akumar@${domain_fqdn}"  "${akumar_password}"  10004 @("${lower(netbios)}-users","india")

    # ----------------------------------------------------------------------
    # RDP access for domain users (idempotent)
    # ----------------------------------------------------------------------
    Write-Output "Ensuring RDP access for ${lower(netbios)}-users"
    try {
        Add-LocalGroupMember -Group "Remote Desktop Users" `
            -Member "${netbios}\${lower(netbios)}-users" -ErrorAction Stop
    } catch {
        if ($_.Exception.Message -match "already a member") {
            Write-Output "${lower(netbios)}-users already in Remote Desktop Users"
        } else { throw }
    }

    # ----------------------------------------------------------------------
    # Fix DNS suffix — OCI DHCP assigns mikecloud.com which mangles FQDNs.
    # Registry SearchList overrides DHCP and survives the domain join reboot.
    # ----------------------------------------------------------------------
    Write-Output "Setting DNS suffix search list to ${domain_fqdn}"
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' `
        -Name 'SearchList' -Value "${domain_fqdn}"
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    Set-DnsClient -InterfaceIndex $adapter.InterfaceIndex `
        -ConnectionSpecificSuffix "${domain_fqdn}"

    # ----------------------------------------------------------------------
    # Reboot only if we just joined
    # ----------------------------------------------------------------------
    if ($didJoin) {
        Write-Output "Rebooting to finalize domain join"
        shutdown /r /t 5 /c "Initial OCI reboot to join domain" /f /d p:4:1
    } else {
        Write-Output "No reboot required"
    }
}
finally {
    Write-Output "User-data finishing at $(Get-Date -Format o)"
    Stop-Transcript | Out-Null
}
</powershell>
