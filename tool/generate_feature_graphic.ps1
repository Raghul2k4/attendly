# Generates the Play Store feature graphic (1024x500). Run from the repo root:
#   powershell -ExecutionPolicy Bypass -File tool/generate_feature_graphic.ps1
# Replace with a designed asset before publishing if one is available.

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$width = 1024
$height = 500

$bmp = New-Object System.Drawing.Bitmap($width, $height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# AppColors.emerald600 background, emerald700 band for depth.
$bg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(4, 120, 87))
$g.FillRectangle($bg, 0, 0, $width, $height)
$band = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(6, 95, 70))
$g.FillRectangle($band, 0, 380, $width, 120)

$titleFont = New-Object System.Drawing.Font(
    'Segoe UI', [single]92, [System.Drawing.FontStyle]::Bold,
    [System.Drawing.GraphicsUnit]::Pixel
)
$tagFont = New-Object System.Drawing.Font(
    'Segoe UI', [single]34, [System.Drawing.FontStyle]::Regular,
    [System.Drawing.GraphicsUnit]::Pixel
)

$title = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$tag = New-Object System.Drawing.SolidBrush(
    [System.Drawing.Color]::FromArgb(230, 255, 255, 255)
)

$g.DrawString('Attendance', $titleFont, $title, 96, 160)
$g.DrawString(
    'GPS check-in  |  QR punch  |  Owner reports',
    $tagFont, $tag, 100, 286
)

$g.Dispose()

$storeDir = Join-Path $root 'docs/store'
if (-not (Test-Path $storeDir)) { New-Item -ItemType Directory -Path $storeDir | Out-Null }
$path = Join-Path $storeDir 'feature-graphic-1024x500.png'
$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "wrote $path"
