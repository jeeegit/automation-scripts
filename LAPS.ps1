# Ensure script can run even if user's execution policy is restrictive
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
} catch {
    Write-Warning "Unable to set execution policy for this session. Script may still fail if blocked."
}

# Detect if running as Administrator
$IsAdmin = $false
try {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $IsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    $IsAdmin = $false
}

if (-not $IsAdmin) {
    Write-Host "Elevation required. Prompting for UAC..." -ForegroundColor Yellow
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Process -id $PID).Path
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"

    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($proc) { exit }
    } catch {
        Write-Host "Failed to start elevated process."
        Write-Error "UAC elevation was canceled or failed. Exiting."
        exit 1
    }
}

# Prompt for hostname
$Hostname = Read-Host "Enter the hostname"

# Ask how many minutes from now to set the new expiration
$DefaultMinutes = 30
$MinutesFromNow = Read-Host "Set new expiration time how many minutes from now? (Default: $DefaultMinutes)"
if (-not $MinutesFromNow) { $MinutesFromNow = $DefaultMinutes }
if ($MinutesFromNow -match "^\d+$") {
    $MinutesFromNow = [int]$MinutesFromNow
} else {
    $MinutesFromNow = $DefaultMinutes
}

# Calculate the effective time
$WhenEffective = (Get-Date).AddMinutes($MinutesFromNow)

# Create the expiration time
try {
    Set-LapsPasswordExpirationTime -Identity $Hostname -WhenEffective $WhenEffective -ErrorAction Stop
    Write-Host "Successfully updated LAPS expiration for $Hostname." -ForegroundColor Green
} catch {
    Write-Error "Failed to set expiration for $Hostname. Errors: $($_.Exception.Message)"
}

# Get LAPS password and expiration
try {
    $LAPSInfo = Get-LapsPassword -Identity $Hostname -AsPlainText -ErrorAction Stop
    Write-Host "Press Enter to exit"
} catch {
    Write-Error "Failed to retrieve LAPS password for $Hostname."
}

# Display results
Write-Host "Password: $($LAPSInfo.Password)"
Write-Host "Expiration Date: $($LAPSInfo.ExpirationTimestamp)"

Read-Host "Press Enter to exit"
