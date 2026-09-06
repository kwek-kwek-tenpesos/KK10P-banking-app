Set-StrictMode -Version Latest

function Assert-BankingZapReportPath {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$RepositoryRoot)
    $root = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot 'banking-lab/reports/zap'))
    $full = [IO.Path]::GetFullPath($Path)
    $prefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or $full -match '[,\r\n]') {
        throw 'Reports must be a child directory of banking-lab/reports/zap; unsafe mount paths are rejected.'
    }
    # Reject existing junctions/symlinks in every ancestor, including the repository.
    $ancestor = $full
    while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
            $item = Get-Item -LiteralPath $ancestor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw 'Report paths must not traverse symlinks or junctions.'
            }
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
}

function New-BankingZapPlan {
    param([Parameter(Mandatory)][string]$TargetUrl, [Parameter(Mandatory)][string]$RepositoryRoot)
    # Match the original spelling before URI normalization; reject credentials,
    # encoded paths, queries, fragments, alternate hosts and command metacharacters.
    if ($TargetUrl -cnotmatch '^https?://(localhost|127\.0\.0\.1|host\.docker\.internal):([0-9]{1,5})/openapi/v1\.json$') {
        throw 'Use an explicit local host/port and /openapi/v1.json; remote targets and extra URL components are not allowed.'
    }
    $uri = [Uri]$TargetUrl
    if ($uri.Port -lt 1 -or $uri.Port -gt 65535) { throw 'Invalid local port.' }
    $scanOrigin = '{0}://host.docker.internal:{1}' -f $uri.Scheme, $uri.Port
    # The original OpenAPI URL supplies the local origin only. Its contents are
    # never imported: servers, external refs and POST operations cannot broaden scope.
    $definition = [ordered]@{
        openapi = '3.0.3'
        info = @{ title = 'Banking Lab diagnostic-only scan'; version = '1.0.0' }
        servers = @(@{ url = $scanOrigin })
        paths = @{
            '/api/v1/system/info' = @{
                get = @{
                    operationId = 'ReadSystemInfo'
                    responses = @{ '200' = @{ description = 'Diagnostic JSON response' } }
                }
            }
        }
    }
    $directory = Join-Path $RepositoryRoot ('banking-lab/reports/zap/run-' + [Guid]::NewGuid().ToString('N'))
    Assert-BankingZapReportPath -Path $directory -RepositoryRoot $RepositoryRoot
    $image = 'ghcr.io/zaproxy/zaproxy:stable'
    [pscustomobject]@{
        Mode = 'Preview only unless -Execute is explicitly supplied'
        Scope = 'GET /api/v1/system/info only; no auth or state-changing operations'
        ProbeUrl = ('{0}://localhost:{1}/api/v1/system/info' -f $uri.Scheme, $uri.Port)
        ScanUrl = $scanOrigin + '/api/v1/system/info'
        ReportDirectory = [IO.Path]::GetFullPath($directory)
        Image = $image
        Definition = $definition
        DockerArguments = @(
            'run', '--rm', '--pull=never', '--cap-drop=ALL', '--security-opt=no-new-privileges',
            '--mount', ('type=bind,source={0},target=/zap/wrk' -f [IO.Path]::GetFullPath($directory)),
            $image, 'zap-api-scan.py', '-t', 'readonly-openapi.json', '-f', 'openapi',
            '-S', '-T', '5', '-z', '-silent', '-c', 'zap-rules.tsv',
            '-r', 'zap-report.html', '-J', 'zap-report.json'
        )
    }
}

function Get-BankingZapExitStatus {
    param([int]$Code)
    switch ($Code) {
        0 { 'Completed: no configured WARN/FAIL findings; this is not security certification.' }
        1 { 'Completed with FAIL findings: review required.' }
        2 { 'Completed with WARN findings: review required.' }
        default { 'Operational failure: scan incomplete; no passing result may be claimed.' }
    }
}

Export-ModuleMember -Function New-BankingZapPlan, Assert-BankingZapReportPath, Get-BankingZapExitStatus
