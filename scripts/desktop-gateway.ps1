$ErrorActionPreference = 'Stop'
$policy = 'HKCU:\Software\Policies\Claude'
foreach ($key in @('HKLM:\Software\Policies\Claude', $policy)) {
    if ((Test-Path $key) -and (Get-Item $key).GetValueNames().Count) {
        throw 'Existing Claude policy found. Review it with its owner before changing gateway settings.'
    }
}
$desktop = Get-StartApps | Where-Object { $_.AppID -eq 'Claude_pzs8sxrjxfjjc!Claude' -or $_.AppID -eq 'com.squirrel.AnthropicClaude.claude' } | Sort-Object { $_.AppID -notlike '*!Claude' } | Select-Object -First 1
if (-not $desktop) { Start-Process 'https://claude.com/download'; throw 'Install Claude Desktop, then reopen this launcher.' }
$endpoint = [uri](Read-Host 'HTTPS gateway base URL')
if (-not $endpoint.IsAbsoluteUri -or $endpoint.Scheme -ne 'https' -or $endpoint.UserInfo -or $endpoint.Query -or $endpoint.Fragment) { throw 'Invalid HTTPS URL.' }
$model = (Read-Host 'Gateway model ID').Trim()
if (-not $model) { throw 'Model ID is required.' }
$secret = Read-Host 'Gateway token (saved in your Windows user registry policy)' -AsSecureString
if (-not $secret.Length) { throw 'Token is required.' }
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
$written = @()
try {
    $settings = [ordered]@{
        inferenceGatewayBaseUrl = $endpoint.AbsoluteUri.TrimEnd('/')
        inferenceModels = ConvertTo-Json -InputObject @(@{name=$model}) -Compress
        inferenceGatewayAuthScheme = 'bearer'
        inferenceGatewayApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        inferenceProvider = 'gateway'
    }
    if (-not (Test-Path $policy)) { New-Item $policy | Out-Null }
    foreach ($name in $settings.Keys) {
        New-ItemProperty -Path $policy -Name $name -Value $settings[$name] -PropertyType String | Out-Null
        $written += $name
    }
} catch {
    foreach ($name in $written) { Remove-ItemProperty -LiteralPath $policy -Name $name }
    throw
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    $secret.Dispose()
}
Write-Host 'Gateway configured. If Desktop was already running, fully quit it and reopen it.'
Start-Process explorer.exe -ArgumentList ("shell:AppsFolder\" + $desktop.AppID)
