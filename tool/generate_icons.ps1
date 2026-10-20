# Generates the launcher icon and the 512px Play Store icon from one source
# of truth. Run from the repository root:
#
#   powershell -ExecutionPolicy Bypass -File tool/generate_icons.ps1
#
# The mark is deliberately simple: an emerald field with a white "A". Replace
# the drawing block (not the sizes) when a designed brand asset is available.

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$sizes = [ordered]@{
    'mipmap-mdpi'    = 48
    'mipmap-hdpi'    = 72
    'mipmap-xhdpi'   = 96
    'mipmap-xxhdpi'  = 144
    'mipmap-xxxhdpi' = 192
}

function New-Icon([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    # AppColors.emerald600
    $bg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(4, 120, 87))
    $g.FillRectangle($bg, 0, 0, $size, $size)

    $font = New-Object System.Drawing.Font(
        'Segoe UI',
        [single]($size * 0.60),
        [System.Drawing.FontStyle]::Bold,
        [System.Drawing.GraphicsUnit]::Pixel
    )
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
    $g.DrawString('A', $font, [System.Drawing.Brushes]::White, $rect, $format)

    $g.Dispose()
    return $bmp
}

foreach ($entry in $sizes.GetEnumerator()) {
    $dir = Join-Path $root ('android/app/src/main/res/' + $entry.Key)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $path = Join-Path $dir 'ic_launcher.png'
    $icon = New-Icon $entry.Value
    $icon.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $icon.Dispose()
    Write-Host "wrote $path"
}

$storeDir = Join-Path $root 'docs/store'
if (-not (Test-Path $storeDir)) { New-Item -ItemType Directory -Path $storeDir | Out-Null }
$playIcon = New-Icon 512
$playPath = Join-Path $storeDir 'play-icon-512.png'
$playIcon.Save($playPath, [System.Drawing.Imaging.ImageFormat]::Png)
$playIcon.Dispose()
Write-Host "wrote $playPath"
