#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$TargetUrl = "http://host.docker.internal:5255/openapi/v1.json",
    [switch]$Execute,
    [switch]$AcknowledgeLocalTestTarget
)

$ErrorActionPreference = "Stop"
Import-Module (Join-Path $PSScriptRoot "zap-scan-policy.psm1") -Force
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))
$plan = New-BankingZapPlan -TargetUrl $TargetUrl -RepositoryRoot $repositoryRoot

# Preview is deliberately before Docker, HTTP, directory creation or report writes.
if (-not $Execute) {
    $plan
    return
}
if (-not $AcknowledgeLocalTestTarget) {
    throw "Execution requires explicit approval and -AcknowledgeLocalTestTarget. Preview made no requests."
}

# Only an already installed image may run; resolve the local tag to immutable ID.
$imageId = & docker image inspect $plan.Image --format '{{.Id}}' 2>$null
if ($LASTEXITCODE -ne 0 -or $imageId -notmatch '^sha256:[a-f0-9]{64}$') {
    throw "A local ZAP image is required. No image was downloaded; request separate installation approval."
}

# Check the same local service/port that Docker will target, without redirects,
# proxy routing, credentials, or certificate-validation bypasses.
$handler = [Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect = $false
$handler.UseProxy = $false
$client = [Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromSeconds(5)
try {
    $response = $client.GetAsync($plan.ProbeUrl).GetAwaiter().GetResult()
    try {
        if ([int]$response.StatusCode -ne 200) { throw "Local diagnostic preflight must return 200 without redirecting." }
        if ($response.Content.Headers.ContentType.MediaType -ne "application/json") {
            throw "Local diagnostic preflight must return JSON."
        }
    }
    finally { $response.Dispose() }
}
finally { $client.Dispose() }

Assert-BankingZapReportPath -Path $plan.ReportDirectory -RepositoryRoot $repositoryRoot
# Unique leaf directories prevent overwriting old reports. Never mount the repo or Docker socket.
$null = New-Item -ItemType Directory -Path $plan.ReportDirectory
[IO.File]::WriteAllText((Join-Path $plan.ReportDirectory "readonly-openapi.json"),
    ($plan.Definition | ConvertTo-Json -Depth 12))
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "zap-rules.tsv") -Destination (Join-Path $plan.ReportDirectory "zap-rules.tsv")

$arguments = @($plan.DockerArguments)
$arguments[[Array]::IndexOf($arguments, $plan.Image)] = $imageId
& docker @arguments
$scanExitCode = $LASTEXITCODE
$status = Get-BankingZapExitStatus -Code $scanExitCode
$reportsPresent = (Test-Path -LiteralPath (Join-Path $plan.ReportDirectory "zap-report.html") -PathType Leaf) -and
    (Test-Path -LiteralPath (Join-Path $plan.ReportDirectory "zap-report.json") -PathType Leaf)
if (-not $reportsPresent) {
    $status = "Operational failure: expected report files were not produced."
    $scanExitCode = 3
}
# This is an execution record, never a substitute for reviewing actual findings.
[ordered]@{
    Mode = "Read-only diagnostic passive scan"
    ImageId = $imageId
    Target = $plan.ScanUrl
    ExitCode = $scanExitCode
    Status = $status
    ReportsPresent = $reportsPresent
    CompletedAtUtc = [DateTime]::UtcNow.ToString("o")
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $plan.ReportDirectory "execution.json")
Write-Host $status
Write-Host "Output: $($plan.ReportDirectory)"
if ($scanExitCode -notin 0, 1, 2, 3) { $scanExitCode = 3 }
exit $scanExitCode
