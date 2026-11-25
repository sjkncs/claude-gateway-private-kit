param()
$ErrorActionPreference = 'Stop'
$client = Get-Command claude -ErrorAction Stop
$endpoint = [Uri](Read-Host 'HTTPS gateway base URL')
if ($endpoint.Scheme -ne 'https' -or $endpoint.UserInfo -or $endpoint.Query -or $endpoint.Fragment) {
    throw 'Use an HTTPS base URL without embedded credentials, query or fragment.'
}
$model = Read-Host 'Gateway model ID'
if ([string]::IsNullOrWhiteSpace($model)) { throw 'Model ID is required.' }
$secureToken = Read-Host 'Your gateway token' -AsSecureString
if ($secureToken.Length -eq 0) { throw 'Token is required.' }
$names = @('ANTHROPIC_BASE_URL','ANTHROPIC_AUTH_TOKEN','ANTHROPIC_MODEL','ANTHROPIC_API_KEY')
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$pointer = [IntPtr]::Zero
try {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $env:ANTHROPIC_BASE_URL = $endpoint.AbsoluteUri.TrimEnd('/')
    $env:ANTHROPIC_AUTH_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    $env:ANTHROPIC_MODEL = $model
    [Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', $null, 'Process')
    & $client.Source
    if ($LASTEXITCODE -ne 0) { throw 'Claude Code exited unsuccessfully.' }
} finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
    if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    $secureToken.Dispose()
}
