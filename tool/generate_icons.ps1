# Generates the launcher icon set (legacy + adaptive layers), the round icon
# and the 512px Play Store icon from the single brand asset in `assets/`.
# Run from the repository root:
#
#   powershell -ExecutionPolicy Bypass -File tool/generate_icons.ps1
#
# Source artwork: a rounded-square plate holding a blue-to-teal "A" with a
# navy person-and-check counter-form. Nothing is measured by hand: the script
# keys the mark against the artwork's own plate colour, trims to the ink's
# bounding box, and re-composes it for each Android density. Replacing the
# artwork with another mark-on-plate drawing therefore needs no code changes.
#
# Composition notes:
#   * Legacy/round/Play icons use a flat plate + the mark (the artwork's plate
#     is a near-uniform very light blue, so this reads identically and keeps the
#     PDF/Play output free of transparency).
#   * The adaptive foreground is transparent with the mark inside Android's
#     66dp safe circle, so any launcher mask (circle, squircle, teardrop) keeps
#     the mark whole.
#   * The Android 13 themed layer is an alpha silhouette (mark shape only).

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $root 'assets/app_icon_source.png'
$resDir = Join-Path $root 'android/app/src/main/res'
$storeDir = Join-Path $root 'docs/store'

if (-not (Test-Path $sourcePath)) {
    throw "Brand asset not found: $sourcePath"
}

$source = [System.Drawing.Bitmap]::FromFile($sourcePath)

# Work from an 800px copy: the largest generated layer is 432px, and keying a
# 1.5M-pixel bitmap pixel-by-pixel in PowerShell takes minutes rather than
# seconds. High-quality bicubic keeps the mark's edges clean at every size.
$side = 800
$work = New-Object System.Drawing.Bitmap(
    $side, $side, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
$workGraphics = [System.Drawing.Graphics]::FromImage($work)
$workGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$workGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$workGraphics.DrawImage($source, 0, 0, $side, $side)
$workGraphics.Dispose()

# --- 1. Sample the artwork's plate colour ------------------------------------
# Modal quantised colour, averaged over the pixels close to it. This is the
# background the mark is drawn on in every generated icon.
$counts = @{}
for ($y = 0; $y -lt $work.Height; $y += 3) {
    for ($x = 0; $x -lt $work.Width; $x += 3) {
        $pixel = $work.GetPixel($x, $y)
        $key = '{0},{1},{2}' -f `
            [int]([Math]::Floor($pixel.R / 4)), `
            [int]([Math]::Floor($pixel.G / 4)), `
            [int]([Math]::Floor($pixel.B / 4))
        if ($counts.ContainsKey($key)) { $counts[$key]++ } else { $counts[$key] = 1 }
    }
}
$mode = ($counts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
$modeParts = $mode.Split(',')
$probeR = [int]$modeParts[0] * 4
$probeG = [int]$modeParts[1] * 4
$probeB = [int]$modeParts[2] * 4

$sumR = 0; $sumG = 0; $sumB = 0; $sumN = 0
for ($y = 0; $y -lt $work.Height; $y += 2) {
    for ($x = 0; $x -lt $work.Width; $x += 2) {
        $pixel = $work.GetPixel($x, $y)
        $delta = [Math]::Max(
            [Math]::Abs($pixel.R - $probeR),
            [Math]::Max([Math]::Abs($pixel.G - $probeG), [Math]::Abs($pixel.B - $probeB))
        )
        if ($delta -le 10) {
            $sumR += $pixel.R; $sumG += $pixel.G; $sumB += $pixel.B; $sumN++
        }
    }
}
if ($sumN -eq 0) { throw 'Could not sample the artwork plate colour.' }
$bg = [System.Drawing.Color]::FromArgb(
    [int][Math]::Round($sumR / $sumN),
    [int][Math]::Round($sumG / $sumN),
    [int][Math]::Round($sumB / $sumN)
)
Write-Host ("plate colour: #{0:X2}{1:X2}{2:X2}" -f $bg.R, $bg.G, $bg.B)

function Get-Delta([System.Drawing.Color]$color) {
    return [Math]::Max(
        [Math]::Abs($color.R - $bg.R),
        [Math]::Max([Math]::Abs($color.G - $bg.G), [Math]::Abs($color.B - $bg.B))
    )
}

# --- 2. Key the mark and trim it ---------------------------------------------
# The plate gradient is within ~12 levels of the sample; the mark is
# saturated/dark (delta > 60). The alpha ramp keeps antialiased edges smooth
# without picking up the plate.
function Get-Alpha([System.Drawing.Color]$color) {
    $delta = Get-Delta $color
    return [int][Math]::Round(
        [Math]::Min(1.0, [Math]::Max(0.0, ($delta - 16) / 44.0)) * 255
    )
}

$minX = $work.Width
$minY = $work.Height
$maxX = -1
$maxY = -1

for ($y = 0; $y -lt $work.Height; $y++) {
    for ($x = 0; $x -lt $work.Width; $x++) {
        $pixel = $work.GetPixel($x, $y)
        if ((Get-Alpha $pixel) -gt 140) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}
if ($maxX -lt 0) { throw 'Could not find the mark inside the brand asset.' }

# Grow the box by the antialiased fringe so no edge is shaved.
$pad = 4
$crop = New-Object System.Drawing.Rectangle(
    [Math]::Max(0, ($minX - $pad)),
    [Math]::Max(0, ($minY - $pad)),
    0, 0
)
$crop.Width = [Math]::Min($work.Width - $crop.X, ($maxX - $minX + 1) + 2 * $pad)
$crop.Height = [Math]::Min($work.Height - $crop.Y, ($maxY - $minY + 1) + 2 * $pad)

# Opaque mark (for flat icons): the cropped artwork is already on the plate.
$mark = $work.Clone($crop, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

# Transparent mark (for adaptive layers): same crop with the keyed alpha.
$markAlpha = New-Object System.Drawing.Bitmap(
    $crop.Width, $crop.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
for ($y = 0; $y -lt $crop.Height; $y++) {
    for ($x = 0; $x -lt $crop.Width; $x++) {
        $pixel = $mark.GetPixel($x, $y)
        $a = Get-Alpha $work.GetPixel(($crop.X + $x), ($crop.Y + $y))
        $markAlpha.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $pixel.R, $pixel.G, $pixel.B))
    }
}

# Single-colour silhouette for the Android 13 themed layer.
$markSolid = New-Object System.Drawing.Bitmap(
    $crop.Width, $crop.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
for ($y = 0; $y -lt $crop.Height; $y++) {
    for ($x = 0; $x -lt $crop.Width; $x++) {
        $markSolid.SetPixel(
            $x, $y,
            [System.Drawing.Color]::FromArgb($markAlpha.GetPixel($x, $y).A, 0, 0, 0)
        )
    }
}

$markAspect = $mark.Width / $mark.Height

# --- 3. Composition helpers --------------------------------------------------

function New-Graphics([System.Drawing.Bitmap]$bitmap) {
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    return $graphics
}

function Get-MarkRect([int]$size, [double]$heightRatio) {
    $height = $size * $heightRatio
    $width = $height * $markAspect
    return New-Object System.Drawing.RectangleF(
        ([single](($size - $width) / 2)),
        ([single](($size - $height) / 2)),
        ([single]$width),
        ([single]$height)
    )
}

function New-FlatIcon {
    param(
        [int]$Size,
        [double]$MarkHeightRatio,
        [switch]$Round
    )
    $bitmap = New-Object System.Drawing.Bitmap(
        $Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = New-Graphics $bitmap
    $plate = New-Object System.Drawing.SolidBrush($bg)
    if ($Round) {
        $graphics.FillEllipse($plate, 0, 0, $Size, $Size)
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddEllipse(0, 0, $Size, $Size)
        $graphics.SetClip($path)
    } else {
        $graphics.FillRectangle($plate, 0, 0, $Size, $Size)
    }
    $plate.Dispose()
    # Keyed mark, not the opaque crop: the crop still carries a slice of the
    # artwork's own plate, which would show as a lighter rectangle on the flat
    # plate at icon sizes.
    $graphics.DrawImage($markAlpha, (Get-MarkRect $Size $MarkHeightRatio))
    $graphics.Dispose()
    return $bitmap
}

# Adaptive foreground: transparent, mark inside the 66dp safe circle of the
# 108dp canvas. 60/108 keeps the widest points of the A just inside it.
function New-AdaptiveForeground([int]$Size) {
    $bitmap = New-Object System.Drawing.Bitmap(
        $Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = New-Graphics $bitmap
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.DrawImage($markAlpha, (Get-MarkRect $Size (60.0 / 108.0)))
    $graphics.Dispose()
    return $bitmap
}

function New-MonochromeLayer([int]$Size) {
    $bitmap = New-Object System.Drawing.Bitmap(
        $Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = New-Graphics $bitmap
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.DrawImage($markSolid, (Get-MarkRect $Size (60.0 / 108.0)))
    $graphics.Dispose()
    return $bitmap
}

function Save-Png([System.Drawing.Bitmap]$bitmap, [string]$path) {
    $folder = Split-Path -Parent $path
    if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    Write-Host "wrote $path"
}

# --- 4. Write the Android resources -----------------------------------------

# Legacy (API 24-25) and fallback bitmaps. 48dp ... 192dp.
$densities = [ordered]@{
    'mipmap-mdpi'    = 48
    'mipmap-hdpi'    = 72
    'mipmap-xhdpi'   = 96
    'mipmap-xxhdpi'  = 144
    'mipmap-xxxhdpi' = 192
}

foreach ($entry in $densities.GetEnumerator()) {
    $folder = Join-Path $resDir $entry.Key
    Save-Png (New-FlatIcon $entry.Value 0.70) (Join-Path $folder 'ic_launcher.png')
    Save-Png (New-FlatIcon $entry.Value 0.66 -Round) (Join-Path $folder 'ic_launcher_round.png')
}

# Adaptive layers are authored at 108dp. Android scales the foreground by the
# same 1.5x factor it uses for the legacy bitmaps, so each density gets its
# own pre-rendered PNG.
$adaptiveDensities = [ordered]@{
    'mipmap-mdpi'    = 108
    'mipmap-hdpi'    = 162
    'mipmap-xhdpi'   = 216
    'mipmap-xxhdpi'  = 324
    'mipmap-xxxhdpi' = 432
}

foreach ($entry in $adaptiveDensities.GetEnumerator()) {
    $folder = Join-Path $resDir $entry.Key
    $size = $entry.Value
    Save-Png (New-AdaptiveForeground $size) (Join-Path $folder 'ic_launcher_foreground.png')
    Save-Png (New-MonochromeLayer $size) (Join-Path $folder 'ic_launcher_monochrome.png')
}

# --- 5. Store listing icon (512x512, no transparency) -----------------------

Save-Png (New-FlatIcon 512 0.70) (Join-Path $storeDir 'play-icon-512.png')

$mark.Dispose()
$markAlpha.Dispose()
$markSolid.Dispose()
$work.Dispose()
$source.Dispose()
