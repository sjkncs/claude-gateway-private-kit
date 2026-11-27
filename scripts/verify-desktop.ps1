function Test-GatewayReply([uri]$Endpoint, [string]$Model, [string]$Token) {
    if ($Endpoint.Scheme -ne 'https' -or $Endpoint.UserInfo -or $Endpoint.Query -or $Endpoint.Fragment -or !$Token -or !$Model) {
        throw 'An HTTPS gateway, model and authorized Bearer token are required.'
    }
    $marker = 'OK' + [guid]::NewGuid().ToString('N').Substring(0,8)
    $body = @{model=$Model; max_tokens=96; messages=@(@{role='user'; content="Return exactly $marker"})} | ConvertTo-Json -Depth 4
    try {
        $reply = Invoke-RestMethod -Method Post -Uri ($Endpoint.AbsoluteUri.TrimEnd('/') + '/v1/messages') -MaximumRedirection 0 -TimeoutSec 75 -Headers @{Authorization="Bearer $Token"; 'anthropic-version'='2023-06-01'} -ContentType 'application/json' -Body $body
    } catch { throw 'Gateway validation failed. Check network, endpoint, token and model access.' }
    if ($marker -cnotin @($reply.content | Where-Object type -eq 'text' | ForEach-Object {$_.text.Trim()})) { throw 'The gateway did not return the requested check value.' }
    Write-Host 'Gateway replied using the selected model.'
}

function Confirm-DesktopWorkspace {
    Add-Type -AssemblyName System.Drawing,System.Runtime.WindowsRuntime
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class KitDesktopWindow {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
    [void][KitDesktopWindow]::SetProcessDPIAware()
    $null = [Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime]
    $null = [Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
    $null = [Windows.Graphics.Imaging.SoftwareBitmap,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
    $null = [Windows.Media.Ocr.OcrResult,Windows.Foundation,ContentType=WindowsRuntime]
    $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
    function Await-Result($operation, $type) {
        $task = $asTask.MakeGenericMethod($type).Invoke($null,@($operation))
        $task.GetAwaiter().GetResult()
    }
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    if (!$engine) { throw 'Install Windows OCR for your display language to verify the Desktop window.' }
    $deadline = [datetime]::UtcNow.AddSeconds(40)
    do {
        Start-Sleep -Seconds 2
        $app = Get-Process Claude -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -eq 'Claude'} | Select-Object -First 1
        if (!$app) { continue }
        $rect = New-Object KitDesktopWindow+Rect
        [void][KitDesktopWindow]::GetWindowRect($app.MainWindowHandle,[ref]$rect)
        if ($rect.Right -le $rect.Left -or $rect.Bottom -le $rect.Top) { continue }
        $bitmap = New-Object Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $dc = $graphics.GetHdc()
        try { $captured = [KitDesktopWindow]::PrintWindow($app.MainWindowHandle,$dc,2) }
        finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
        $stream = New-Object IO.MemoryStream
        try {
            if (!$captured) { continue }
            # Inspect the footer only. Avoid recognizing conversation history.
            $height = [Math]::Max(1,[int]($bitmap.Height * 0.24))
            $area = New-Object Drawing.Rectangle 0,($bitmap.Height-$height),$bitmap.Width,$height
            $footer = $bitmap.Clone($area,$bitmap.PixelFormat)
            try { $footer.Save($stream,[Drawing.Imaging.ImageFormat]::Png) } finally { $footer.Dispose() }
            $stream.Position = 0
            $random = [System.IO.WindowsRuntimeStreamExtensions]::AsRandomAccessStream($stream)
            $decoder = Await-Result ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($random)) ([Windows.Graphics.Imaging.BitmapDecoder])
            $software = Await-Result ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
            try { $result = Await-Result ($engine.RecognizeAsync($software)) ([Windows.Media.Ocr.OcrResult]) }
            finally { $software.Dispose() }
            if ($result.Text -match '(?i)gateway' -and $result.Text -match '(?i)commands|message Claude|ask anything|ask a question|reply|send a message|\u547d\u4ee4|\u53d1\u9001\u6d88\u606f') {
                Write-Host 'Claude Desktop gateway workspace verified.'
                return
            }
        } finally { $bitmap.Dispose(); $stream.Dispose() }
    } while ([datetime]::UtcNow -lt $deadline)
    throw 'Desktop gateway workspace could not be verified. Check the visible sign-in, approval, or setup screen.'
}
