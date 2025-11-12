# =============================================
# Script: Start msiserver on remote clients via WMI
# Author: For junior sysadmin
# Clients: clients.txt (same folder)
# Logs: MSI-Start-Log.txt
# =============================================

$ScriptPath  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClientsFile = "$ScriptPath\clients.txt"
$LogFile     = "$ScriptPath\MSI-Start-Log.txt"
$MaxJobs     = 10

# === Job ScriptBlock ===
$JobScript = {
    param($Computer, $LogFile)

    function Log {
        param($Msg)
        $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$Time - [$Computer] $Msg" | Out-File -FilePath $LogFile -Append -Encoding UTF8
        Write-Host "[$Computer] $Msg"
    }

    # Check online
    if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
        Log "OFFLINE"
        return
    }

    try {
        # Connect to WMI
        $Service = Get-WmiObject -ComputerName $Computer -Class Win32_Service -Filter "Name='msiserver'" -ErrorAction Stop

        if ($Service.State -eq "Running") {
            Log "ALREADY RUNNING"
            return
        }

        if ($Service.State -eq "Stopped") {
            $Result = $Service.StartService()
            if ($Result.ReturnValue -eq 0) {
                Log "STARTED successfully"
            } else {
                Log "FAILED to start (Code: $($Result.ReturnValue))"
            }
            return
        }

        Log "State: $($Service.State)"
    }
    catch {
        Log "WMI ERROR: $($_.Exception.Message.Split("`n")[0])"
    }
}

# =============================================
# === MAIN ===
# =============================================

$StartTime = Get-Date
$Header = "$StartTime - === MSI Service Start Started ==="
$Header | Out-File -FilePath $LogFile -Encoding UTF8
Write-Host $Header

if (-not (Test-Path $ClientsFile)) {
    $Err = "ERROR: clients.txt not found in $ScriptPath"
    $Err | Out-File -FilePath $LogFile -Append
    Write-Host $Err -ForegroundColor Red
    pause
    exit
}

$Clients = Get-Content $ClientsFile | Where-Object { $_.Trim() -ne "" -and $_.Trim() -notmatch "^#" }
$LoadMsg = "$StartTime - Loaded $($Clients.Count) clients"
$LoadMsg | Out-File -FilePath $LogFile -Append
Write-Host "Loaded $($Clients.Count) clients"

$Jobs = @()
foreach ($Client in $Clients) {
    while ((Get-Job -State Running).Count -ge $MaxJobs) { Start-Sleep -Milliseconds 500 }
    $Job = Start-Job -ScriptBlock $JobScript -ArgumentList $Client, $LogFile
    $Jobs += $Job
}

$Jobs | Wait-Job | Out-Null
$Jobs | Receive-Job | Out-Null
$Jobs | Remove-Job

$EndTime = Get-Date
$Duration = ($EndTime - $StartTime).ToString("mm\:ss")
$Footer = "$EndTime - === All done in $Duration. See $LogFile ==="
$Footer | Out-File -FilePath $LogFile -Append
Write-Host "`n$Footer" -ForegroundColor Green

pause
