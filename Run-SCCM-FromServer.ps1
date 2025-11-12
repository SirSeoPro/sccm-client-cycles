# =============================================
# Script: Trigger SCCM actions via WMI (NO PS REMOTING)
# Works on ALL clients with admin rights
# Full logging, all cycles
# =============================================

$ScriptPath   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClientsFile  = "$ScriptPath\clients.txt"
$LogFile      = "$ScriptPath\SCCM-Trigger-Log.txt"
$MaxJobs      = 10

# === SCCM Actions ===
$Actions = @(
    @{ GUID = "{00000000-0000-0000-0000-000000000001}"; Name = "Hardware Inventory" }
    @{ GUID = "{00000000-0000-0000-0000-000000000002}"; Name = "Software Inventory" }
    @{ GUID = "{00000000-0000-0000-0000-000000000003}"; Name = "Discovery Data" }
    @{ GUID = "{00000000-0000-0000-0000-000000000010}"; Name = "File Collection" }
    @{ GUID = "{00000000-0000-0000-0000-000000000021}"; Name = "Machine Policy Retrieval" }
    @{ GUID = "{00000000-0000-0000-0000-000000000022}"; Name = "Machine Policy Evaluation" }
    @{ GUID = "{00000000-0000-0000-0000-000000000023}"; Name = "Refresh Default MP" }
    @{ GUID = "{00000000-0000-0000-0000-000000000024}"; Name = "LS Refresh" }
    @{ GUID = "{00000000-0000-0000-0000-000000000025}"; Name = "LS Timeout" }
    @{ GUID = "{00000000-0000-0000-0000-000000000031}"; Name = "Software Metering" }
    @{ GUID = "{00000000-0000-0000-0000-000000000032}"; Name = "Source Update" }
    @{ GUID = "{00000000-0000-0000-0000-000000000042}"; Name = "Software Updates Scan" }
    @{ GUID = "{00000000-0000-0000-0000-000000000108}"; Name = "App Global Eval" }
    @{ GUID = "{00000000-0000-0000-0000-000000000113}"; Name = "Power Mgmt" }
    @{ GUID = "{00000000-0000-0000-0000-000000000121}"; Name = "State Message Upload" }
)

# === Job ScriptBlock (WMI) ===
$JobScript = {
    param($Computer, $Actions, $LogFile)

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

    # Check WMI access
    try {
        $WMI = [wmiclass]"\\$Computer\root\ccm:SMS_Client"
        Log "WMI connected"
    }
    catch {
        Log "WMI FAILED: $($_.Exception.Message.Split("`n")[0])"
        return
    }

    $Triggered = @()
    foreach ($Action in $Actions) {
        try {
            $WMI.TriggerSchedule($Action.GUID) | Out-Null
            $Triggered += $Action.Name
            Log "Triggered: $($Action.Name)"
        }
        catch {
            # Some GUIDs may not exist
        }
    }

    if ($Triggered.Count -eq 0) {
        Log "No actions triggered"
    } else {
        Log "SUCCESS: $($Triggered.Count) actions"
    }
}

# =============================================
# === MAIN ===
# =============================================

$StartTime = Get-Date
$Header = "$StartTime - === SCCM Mass Trigger (WMI) Started ==="
$Header | Out-File -FilePath $LogFile -Encoding UTF8
Write-Host $Header

if (-not (Test-Path $ClientsFile)) {
    $Err = "ERROR: clients.txt not found"
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
    $Job = Start-Job -ScriptBlock $JobScript -ArgumentList $Client, $Actions, $LogFile
    $Jobs += $Job
}

$Jobs | Wait-Job | Out-Null
$Jobs | Receive-Job | Out-Null
$Jobs | Remove-Job

$EndTime = Get-Date
$Duration = ($EndTime - $StartTime).ToString("mm\:ss")
$Footer = "$EndTime - === All done in $Duration ==="
$Footer | Out-File -FilePath $LogFile -Append
Write-Host "`n$Footer" -ForegroundColor Green

pause
