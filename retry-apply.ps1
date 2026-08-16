<#
.SYNOPSIS
    Keeps running `terraform apply` on an interval until it succeeds.

.DESCRIPTION
    Terraform itself does NOT retry "out of host capacity" errors — a
    failed apply just exits. This script is the actual retry loop: it
    re-runs `terraform apply -auto-approve`, and if that fails (almost
    always because the shape is out of capacity right now), waits and
    tries again.

.PARAMETER IntervalMinutes
    How long to wait between attempts. Default: 15.

.PARAMETER MaxAttempts
    Give up after this many tries. Default: 0 (unlimited).

.EXAMPLE
    .\retry-apply.ps1
    Retry every 15 minutes, forever.

.EXAMPLE
    .\retry-apply.ps1 -IntervalMinutes 30

.EXAMPLE
    .\retry-apply.ps1 -IntervalMinutes 15 -MaxAttempts 20
#>
param(
    [int]$IntervalMinutes = 15,
    [int]$MaxAttempts = 0
)

$attempt = 0
while ($true) {
    $attempt++
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] Attempt ${attempt}: running terraform apply..."

    terraform apply -auto-approve
    if ($LASTEXITCODE -eq 0) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$timestamp] Success on attempt ${attempt}."
        exit 0
    }

    if ($MaxAttempts -gt 0 -and $attempt -ge $MaxAttempts) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$timestamp] Reached max attempts ($MaxAttempts) without success. Giving up."
        exit 1
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] Attempt ${attempt} failed (most likely out of capacity). Retrying in $IntervalMinutes minute(s)..."
    Start-Sleep -Seconds ($IntervalMinutes * 60)
}
