param([string]$ExpectedSid)
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if ($ExpectedSid -and $ExpectedSid -ne $identity.User.Value) {
    throw 'Windows selected a different administrator account. Use the Desktop gateway setup screen under your own account.'
}
function Read-Config($path) {
    if (Test-Path -LiteralPath $path) {
        try { Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json }
        catch { throw 'An existing configuration file is unreadable. Check it before running setup again.' }
    }
}
$desktop = Get-StartApps | Where-Object { $_.AppID -eq 'Claude_pzs8sxrjxfjjc!Claude' -or $_.AppID -eq 'com.squirrel.AnthropicClaude.claude' } | Sort-Object { $_.AppID -notlike '*!Claude' } | Select-Object -First 1
if (-not $desktop) { Start-Process 'https://claude.com/download'; throw 'Install Claude Desktop, then reopen this launcher.' }
function Open-Desktop { Start-Process explorer.exe -ArgumentList ("shell:AppsFolder\" + $desktop.AppID) }
$cli = (Read-Config (Join-Path $env:USERPROFILE '.claude\settings.json')).env
function Use-Existing($config) {
    $models = $config.inferenceModels
    if ($models -is [string]) { try { $models = ConvertFrom-Json $models } catch { throw 'Review existing Desktop model settings.' } }
    if ($config.inferenceProvider -ne 'gateway' -or !$config.inferenceGatewayBaseUrl -or !$models -or
        (!$config.inferenceGatewayApiKey -and $config.inferenceGatewayAuthScheme -ne 'oidc')) { throw 'Existing Desktop settings require review in Claude Desktop.' }
    if (($cli.ANTHROPIC_BASE_URL -and $cli.ANTHROPIC_BASE_URL.TrimEnd('/') -cne $config.inferenceGatewayBaseUrl.TrimEnd('/')) -or
        ($cli.ANTHROPIC_MODEL -and $cli.ANTHROPIC_MODEL -cnotin @($models | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.name } }))) {
        throw 'Desktop and CLI select different gateways or models. Review the active Desktop configuration.'
    }
    Write-Host 'Existing Desktop gateway recognized. Opening Claude Desktop.'
    Open-Desktop
}
$policy = 'HKCU:\Software\Policies\Claude'
foreach ($key in @('HKLM:\Software\Policies\Claude', $policy)) {
    if ((Test-Path $key) -and (Get-Item $key).GetValueNames().Count) {
        Use-Existing (Get-ItemProperty -LiteralPath $key)
        return
    }
}
$profileRoot = Join-Path $env:LOCALAPPDATA 'Claude-3p'
$mode = Read-Config (Join-Path $profileRoot 'claude_desktop_config.json')
$meta = Read-Config (Join-Path $profileRoot 'configLibrary\_meta.json')
if ($mode.deploymentMode -eq '3p' -and $meta.appliedId) {
    $id = [guid]::ParseExact($meta.appliedId, 'D')
    Use-Existing (Read-Config (Join-Path $profileRoot "configLibrary\$id.json"))
    return
}
# Request elevation only if this user's policy key cannot be opened for writing.
try {
    $handle = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Policies\Claude')
    $handle.Close()
} catch {
    if ($ExpectedSid) { throw 'Windows policy is managed. Use Desktop gateway setup or contact the policy owner.' }
    Write-Host 'Windows requires administrator approval to create your user policy.'
    $worker = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList ('-NoProfile -File "' + $PSCommandPath + '" -ExpectedSid ' + $identity.User.Value)
    if ($worker.ExitCode) { throw 'Desktop setup did not finish. Check administrator approval and use the same Windows account.' }
    Open-Desktop
    return
}
$endpoint = if ($cli.ANTHROPIC_BASE_URL) { [uri]$cli.ANTHROPIC_BASE_URL } else { [uri](Read-Host 'HTTPS gateway base URL') }
if (-not $endpoint.IsAbsoluteUri -or $endpoint.Scheme -ne 'https' -or $endpoint.UserInfo -or $endpoint.Query -or $endpoint.Fragment) { throw 'Invalid HTTPS URL.' }
$model = if ($cli.ANTHROPIC_MODEL) { $cli.ANTHROPIC_MODEL } else { (Read-Host 'Gateway model ID').Trim() }
if (-not $model) { throw 'Model ID is required.' }
$secret = if ($cli.ANTHROPIC_BASE_URL -and $cli.ANTHROPIC_AUTH_TOKEN) { ConvertTo-SecureString $cli.ANTHROPIC_AUTH_TOKEN -AsPlainText -Force } else { Read-Host 'Gateway token (saved in your Windows user registry policy)' -AsSecureString }
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
if (!$ExpectedSid) { Open-Desktop }
