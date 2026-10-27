# Generates the Play Store feature graphic (1024x500) from the brand artwork.
# Run from the repository root:
#
#   powershell -ExecutionPolicy Bypass -File tool/generate_feature_graphic.ps1
#
# Composition: light plate background, Inter wordmark on the left, the brand
# mark on the right. The launcher icon uses the same artwork, so the store
# listing and the home-screen icon stay recognisably the same brand.

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$width = 1024
$height = 500

$artworkPath = Join-Path $root 'assets/app_icon_source.png'
$interPath = Join-Path $root 'assets/fonts/Inter-Variable.ttf'
if (-not (Test-Path $artworkPath)) { throw "Brand asset not found: $artworkPath" }

# Palette mirrors lib/app/theme/app_colors.dart.
$plate = [System.Drawing.Color]::FromArgb(251, 252, 254)
$ink = [System.Drawing.Color]::FromArgb(15, 23, 42)
$inkSoft = [System.Drawing.Color]::FromArgb(71, 85, 105)
$slate = [System.Drawing.Color]::FromArgb(100, 116, 139)
$emerald = [System.Drawing.Color]::FromArgb(4, 120, 87)
$emeraldSoft = [System.Drawing.Color]::FromArgb(236, 253, 245)

# Use the app's own typeface when GDI+ can load it; fall back to Segoe UI so
# the script still works on machines without the font file.
$families = New-Object System.Drawing.Text.PrivateFontCollection
$fontFamily = 'Segoe UI'
if (Test-Path $interPath) {
    try {
        $families.AddFontFile($interPath)
        if ($families.Families.Count -gt 0) { $fontFamily = $families.Families[0].Name }
    } catch {
        Write-Warning "Could not load Inter; falling back to Segoe UI."
    }
}

function New-RoundedPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $r * 2
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc(($x + $w - $diameter), $y, $diameter, $diameter, 270, 90)
    $path.AddArc(($x + $w - $diameter), ($y + $h - $diameter), $diameter, $diameter, 0, 90)
    $path.AddArc($x, ($y + $h - $diameter), $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.Clear($plate)

# --- Illustration on the right ----------------------------------------------

$artwork = [System.Drawing.Bitmap]::FromFile($artworkPath)
$artHeight = 452
$artWidth = [int]($artHeight * $artwork.Width / $artwork.Height)
$artX = $width - $artWidth - 44
$artY = [int](($height - $artHeight) / 2)
$graphics.DrawImage($artwork, $artX, $artY, $artWidth, $artHeight)

# --- Copy on the left --------------------------------------------------------

$left = 72

$pillFont = New-Object System.Drawing.Font($fontFamily, [single]20, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$pillText = 'VERIFIED ATTENDANCE'
$pillSize = $graphics.MeasureString($pillText, $pillFont)
$pillWidth = [single]($pillSize.Width + 44)
$pillPath = New-RoundedPath $left 76 $pillWidth 44 22
$pillBrush = New-Object System.Drawing.SolidBrush($emeraldSoft)
$graphics.FillPath($pillBrush, $pillPath)
$pillBrush.Dispose()
$pillPath.Dispose()

$dotBrush = New-Object System.Drawing.SolidBrush($emerald)
$graphics.FillEllipse($dotBrush, ($left + 18), 92, 12, 12)
$dotBrush.Dispose()

$pillTextBrush = New-Object System.Drawing.SolidBrush($emerald)
$graphics.DrawString($pillText, $pillFont, $pillTextBrush, ($left + 38), 87)
$pillTextBrush.Dispose()
$pillFont.Dispose()

$titleFont = New-Object System.Drawing.Font($fontFamily, [single]92, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$titleBrush = New-Object System.Drawing.SolidBrush($ink)
$graphics.DrawString('Attendly', $titleFont, $titleBrush, ($left - 4), 142)
$titleBrush.Dispose()
$titleFont.Dispose()

$taglineFont = New-Object System.Drawing.Font($fontFamily, [single]30, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$taglineBrush = New-Object System.Drawing.SolidBrush($inkSoft)
$graphics.DrawString('One-tap check-in your team can trust.', $taglineFont, $taglineBrush, $left, 276)
$taglineBrush.Dispose()
$taglineFont.Dispose()

$detailFont = New-Object System.Drawing.Font($fontFamily, [single]22, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$detailBrush = New-Object System.Drawing.SolidBrush($slate)
$dot = [string][char]0x00B7
$graphics.DrawString("GPS geofence  $dot  QR punch  $dot  Owner reports", $detailFont, $detailBrush, $left, 330)
$detailBrush.Dispose()
$detailFont.Dispose()

# Small emerald rule under the copy, anchoring the block above the fold.
$ruleBrush = New-Object System.Drawing.SolidBrush($emerald)
$graphics.FillRectangle($ruleBrush, $left, 396, 64, 4)
$ruleBrush.Dispose()

$graphics.Dispose()
$artwork.Dispose()

$storeDir = Join-Path $root 'docs/store'
if (-not (Test-Path $storeDir)) { New-Item -ItemType Directory -Path $storeDir | Out-Null }
$path = Join-Path $storeDir 'feature-graphic-1024x500.png'
$bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()
Write-Host "wrote $path"
