# =============================================
# Script: Trigger all SCCM client actions (CIM method)
# Author: For junior sysadmin
# Domain: sobeautiful.ru (not used)
# =============================================

Write-Host "Triggering all SCCM actions..." -ForegroundColor Green

# List of all standard SCCM action GUIDs
$Actions = @(
    "{00000000-0000-0000-0000-000000000001}"  # Hardware Inventory
    "{00000000-0000-0000-0000-000000000002}"  # Software Inventory
    "{00000000-0000-0000-0000-000000000003}"  # Discovery Data
    "{00000000-0000-0000-0000-000000000010}"  # File Collection
    "{00000000-0000-0000-0000-000000000011}"  # IDMIF Collection
    "{00000000-0000-0000-0000-000000000012}"  # Client Machine Authentication
    "{00000000-0000-0000-0000-000000000021}"  # Request Machine Assignments
    "{00000000-0000-0000-0000-000000000022}"  # Evaluate Machine Policies
    "{00000000-0000-0000-0000-000000000023}"  # Refresh Default MP Task
    "{00000000-0000-0000-0000-000000000024}"  # LS (Location Service) Refresh
    "{00000000-0000-0000-0000-000000000025}"  # LS Timeout Refresh
    "{00000000-0000-0000-0000-000000000026}"  # Policy Agent Request Assignment (SID)
    "{00000000-0000-0000-0000-000000000027}"  # Policy Agent Evaluate Assignment (SID)
    "{00000000-0000-0000-0000-000000000031}"  # Software Metering Generating Usage Report
    "{00000000-0000-0000-0000-000000000032}"  # Source Update Message
    "{00000000-0000-0000-0000-000000000037}"  # AMT Provisioning
    "{00000000-0000-0000-0000-000000000041}"  # Software Updates Assignments Evaluation
    "{00000000-0000-0000-0000-000000000042}"  # Software Updates Scan
    "{00000000-0000-0000-0000-000000000063}"  # Compliance Evaluation
    "{00000000-0000-0000-0000-000000000071}"  # Application Manager Policy Action
    "{00000000-0000-0000-0000-000000000108}"  # Application Manager Global Evaluation Action
    "{00000000-0000-0000-0000-000000000113}"  # Power Management Start Summarizer
    "{00000000-0000-0000-0000-000000000121}"  # State Message Upload
    "{00000000-0000-0000-0000-000000000221}"  # CCR Retry
)

# Check if SCCM client is installed
if (-not (Test-Path "C:\Windows\CCM\CCMExec.exe")) {
    Write-Host "Error: SCCM client not found! Make sure the agent is installed." -ForegroundColor Red
    pause
    exit
}

# Trigger each action using CIM (more reliable than WMI)
foreach ($Action in $Actions) {
    $ActionName = switch ($Action) {
        "{00000000-0000-0000-0000-000000000001}" { "Hardware Inventory" }
        "{00000000-0000-0000-0000-000000000002}" { "Software Inventory" }
        "{00000000-0000-0000-0000-000000000003}" { "Discovery Data" }
        "{00000000-0000-0000-0000-000000000021}" { "Machine Policy Retrieval" }
        "{00000000-0000-0000-0000-000000000022}" { "Machine Policy Evaluation" }
        "{00000000-0000-0000-0000-000000000041}" { "Software Updates Assignments" }
        "{00000000-0000-0000-0000-000000000042}" { "Software Updates Scan" }
        default { $Action }
    }

    Write-Host "Triggering: $ActionName" -ForegroundColor Yellow

    try {
        Invoke-CimMethod -Namespace "root\ccm" -ClassName "SMS_Client" -MethodName "TriggerSchedule" -Arguments @{ sScheduleID = $Action } -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "Failed: $ActionName (Error: $($_.Exception.Message))" -ForegroundColor Red
    }
}

Write-Host "`nAll SCCM actions triggered (or attempted)!" -ForegroundColor Green
Write-Host "Check progress in 'Configuration Manager' control panel → Actions tab." -ForegroundColor Cyan

# Open SCCM control panel
Start-Process "control.exe" -ArgumentList "smscfgrc" -ErrorAction SilentlyContinue

pause
