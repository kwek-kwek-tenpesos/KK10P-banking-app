#requires -Version 7.0
# Offline policy/regression checks: no Docker, HTTP, files written or scanner needed.
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'zap-scan-policy.psm1') -Force
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$script:checks = 0
function Assert-Check([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAILED: $Message" }
    $script:checks++
}
function Assert-Rejected([scriptblock]$Action, [string]$Message, [string]$ExpectedError = '') {
    $rejected = $false
    try { $null = & $Action } catch {
        $rejected = $true
        if ($ExpectedError -and $_.Exception.Message -notmatch $ExpectedError) { throw }
    }
    Assert-Check $rejected $Message
}

foreach ($scheme in 'http', 'https') {
    foreach ($localName in 'localhost', '127.0.0.1', 'host.docker.internal') {
        $plan = New-BankingZapPlan -TargetUrl "${scheme}://${localName}:5255/openapi/v1.json" -RepositoryRoot $repositoryRoot
        Assert-Check ($plan.ScanUrl -eq "${scheme}://host.docker.internal:5255/api/v1/system/info") 'Container origin mapping'
        Assert-Check ($plan.ProbeUrl -eq "${scheme}://localhost:5255/api/v1/system/info") 'Matching probe port/scheme/route'
    }
}
foreach ($invalid in @(
    'https://example.com:5255/openapi/v1.json',
    'http://192.168.1.10:5255/openapi/v1.json',
    'http://100.64.0.1:5255/openapi/v1.json',
    'http://localhost.evil.test:5255/openapi/v1.json',
    'http://localhost@evil.test:5255/openapi/v1.json',
    'http://name:password@localhost:5255/openapi/v1.json',
    'http://localhost:5255/openapi/v1.json?token=secret',
    'http://localhost:5255/openapi/v1.json#fragment',
    'http://localhost:5255/openapi/v1.json;Write-Host injected',
    'http://localhost:5255/openapi/%76%31.json',
    'http://localhost:5255/openapi/../openapi/v1.json',
    'http://localhost:5255/api/v1/auth/login',
    'file:///openapi/v1.json',
    'http://localhost/openapi/v1.json',
    'http://localhost:0/openapi/v1.json',
    'http://localhost:65536/openapi/v1.json'
)) {
    Assert-Rejected { New-BankingZapPlan -TargetUrl $invalid -RepositoryRoot $repositoryRoot } 'Unsafe target rejected'
}
$plan = New-BankingZapPlan -TargetUrl 'http://localhost:5255/openapi/v1.json' -RepositoryRoot $repositoryRoot
$arguments = $plan.DockerArguments
Assert-Check ($arguments -contains '-S') 'Active scanning disabled'
Assert-Check ($arguments -contains '-silent') 'ZAP automatic updates disabled'
Assert-Check ($arguments -contains '--pull=never') 'Automatic image pulls disabled'
Assert-Check (($arguments -contains '-T') -and ($arguments -notcontains '-m')) 'Correct API timeout flag'
Assert-Check ($arguments -notcontains '--privileged') 'No privileged container'
Assert-Check ($arguments -contains '--cap-drop=ALL') 'Container capabilities dropped'
Assert-Check ($plan.Definition.paths.Count -eq 1) 'Exactly one route'
Assert-Check ($plan.Definition.paths['/api/v1/system/info'].Count -eq 1) 'Exactly one method'
Assert-Check ($plan.Definition.paths['/api/v1/system/info'].ContainsKey('get')) 'GET only'
Assert-Check (($plan.Definition | ConvertTo-Json -Depth 12) -notmatch '\$ref|/auth/') 'No external references or authentication operations'
Assert-Check (-not (Test-Path -LiteralPath $plan.ReportDirectory)) 'Planning creates no output folder'
foreach ($outside in @(
    $repositoryRoot,
    (Join-Path $repositoryRoot 'banking-lab/reports/zap'),
    (Join-Path $repositoryRoot 'banking-lab/reports/zap/../../backend'),
    (Join-Path $repositoryRoot 'banking-lab/reports/zap-escape/run'),
    (Join-Path $repositoryRoot 'banking-lab/reports/zap/bad,mount')
)) {
    Assert-Rejected { Assert-BankingZapReportPath -Path $outside -RepositoryRoot $repositoryRoot } 'Unsafe report mount rejected'
}
Assert-Check ((Get-BankingZapExitStatus 0) -match 'not security certification') 'Zero is not security certification'
Assert-Check ((Get-BankingZapExitStatus 1) -match 'FAIL') 'Findings exit status'
Assert-Check ((Get-BankingZapExitStatus 2) -match 'WARN') 'Warnings not hidden'
Assert-Check ((Get-BankingZapExitStatus 125) -match 'Operational failure') 'Docker failure not a scan pass'

# Shadow Docker in this process. Even the incomplete-execution tests cannot launch it.
$global:BankingZapTestDockerCalls = 0
function docker {
    $global:BankingZapTestDockerCalls++
    $global:LASTEXITCODE = 1
}
$runner = Join-Path $PSScriptRoot 'run-zap-scan.ps1'
$preview = & $runner
Assert-Check ($global:BankingZapTestDockerCalls -eq 0) 'Default preview never calls Docker'
Assert-Check (-not (Test-Path -LiteralPath $preview.ReportDirectory)) 'Runner preview creates no files'
Assert-Rejected { & $runner -Execute } 'Acknowledgement required before any Docker/network call' 'Execution requires explicit approval'
Assert-Check ($global:BankingZapTestDockerCalls -eq 0) 'Missing acknowledgement has no Docker side effect'
Assert-Rejected { & $runner -Execute -AcknowledgeLocalTestTarget } 'Missing local image stops execution before HTTP' 'A local ZAP image is required'
Assert-Check ($global:BankingZapTestDockerCalls -eq 1) 'Only mocked image inspection attempted'

foreach ($file in @($runner, (Join-Path $PSScriptRoot 'zap-scan-policy.psm1'), $PSCommandPath)) {
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$parseErrors)
    Assert-Check ($parseErrors.Count -eq 0) 'PowerShell syntax valid'
    $unsafe = $ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -in 'Invoke-Expression', 'iex'
    }, $true)
    Assert-Check ($unsafe.Count -eq 0) 'No string-evaluated shell commands'
}
Write-Output "Passed $script:checks offline scanner safety checks. No scanner, Docker daemon or API contacted."
