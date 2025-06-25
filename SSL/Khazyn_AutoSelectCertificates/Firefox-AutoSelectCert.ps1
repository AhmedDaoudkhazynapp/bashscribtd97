# Close Firefox if running
Get-Process firefox -ErrorAction SilentlyContinue | Stop-Process -Force

# Wait for Firefox to fully terminate
do {
    Start-Sleep -Seconds 1
} while (Get-Process firefox -ErrorAction SilentlyContinue)

Start-Sleep -Seconds 1  # Additional delay to ensure processes are fully terminated

$firefoxProfilePath = "$env:APPDATA\Mozilla\Firefox\Profiles\"
$profileDirs = Get-ChildItem -Path $firefoxProfilePath -Directory

$retryCount = 5
$retryDelay = 1  # Delay in seconds

foreach ($dir in $profileDirs) {
    $prefsFile = "$($dir.FullName)\prefs.js"
    
    if (Test-Path $prefsFile) {
        # Backup the original prefs.js
        Copy-Item -Path $prefsFile -Destination "$prefsFile.bak" -Force

        # Read existing prefs.js content, excluding any old "security.default_personal_cert" entry
        $prefsContent = Get-Content $prefsFile | Where-Object { $_ -notmatch "security.default_personal_cert" }

        # Add the new setting
        $prefsContent += 'user_pref("security.default_personal_cert", "Select Automatically");'

        # Retry mechanism for writing to the file
        $retry = 0
        while ($retry -lt $retryCount) {
            try {
                $prefsContent | Set-Content -Path $prefsFile -Encoding UTF8 -Force -ErrorAction Stop
                Write-Host "Updated: $prefsFile"
                break  # Exit the retry loop if successful
            } catch {
                $retry++
                Write-Host "Attempt ${retry}: File is locked, retrying in ${retryDelay} seconds..."
                Start-Sleep -Seconds $retryDelay
            }
        }

        if ($retry -eq $retryCount) {
            Write-Host "Failed to update: $prefsFile (file is still locked)"
        }
    }
}

Write-Host "Firefox certificate selection set to 'Select Automatically'."