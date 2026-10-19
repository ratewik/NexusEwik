Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

# NexusEwik icon generator (PowerShell/GDI+). Brand mark: near-black rounded tile,
# four rounded diamonds (vertical gradient with a bright "waterline", lavender border),
# lavender dots in the top-left and bottom-right corners.
# Outputs every icon format the app ships: shared/icon, windows/assets, linux/assets,
# mac/assets, android mipmaps, windows/installer/icon.ico, .github/assets/icon.png.

$SS = 4
$U = 1024 * $SS
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

$BG     = [System.Drawing.Color]::FromArgb(255, 17, 17, 19)
$BORDER = [System.Drawing.Color]::FromArgb(255, 229, 220, 248)
$RINGC  = [System.Drawing.Color]::FromArgb(255, 74, 60, 124)

$D = @(
  @{ cx = 528; cy = 294 },
  @{ cx = 309; cy = 562 },
  @{ cx = 749; cy = 562 },
  @{ cx = 528; cy = 828 }
)
$HALFDIAG = 181
$SIDE = 257
$DR = 70
$BORDERW = 22
$WATER = 0.44

$DOTS = @(
  @{ x = 257; y = 155; r = 27; kind = 'ring' },
  @{ x = 176; y = 214; r = 21; kind = 'ring' },
  @{ x = 180; y = 300; r = 15; kind = 'solid' },
  @{ x = 293; y = 269; r = 13; kind = 'solid' },
  @{ x = 846; y = 728; r = 23; kind = 'ring' },
  @{ x = 974; y = 727; r = 18; kind = 'ring' },
  @{ x = 1103; y = 790; r = 16; kind = 'solid' },
  @{ x = 1167; y = 930; r = 26; kind = 'ring' }
)

function C([int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb(255, $r, $g, $b) }

function New-RoundRectPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = [System.Drawing.Drawing2D.GraphicsPath]::new()
  if ($r -lt 1 -or (2 * $r) -ge $w) {
    $p.AddRectangle([System.Drawing.RectangleF]::new($x, $y, $w, $h))
    return $p
  }
  $p.AddLine($x + $r, $y, $x + $w - $r, $y)
  $p.AddArc($x + $w - $r, $y, $r, $r, 270, 90)
  $p.AddLine($x + $w, $y + $r, $x + $w, $y + $h - $r)
  $p.AddArc($x + $w - $r, $y + $h - $r, $r, $r, 0, 90)
  $p.AddLine($x + $r, $y + $h, $x + $w - $r, $y + $h)
  $p.AddArc($x, $y + $h - $r, $r, $r, 90, 90)
  $p.AddLine($x, $y + $h - $r, $x, $y + $r)
  $p.AddArc($x, $y, $r, $r, 180, 90)
  $p.CloseFigure()
  return $p
}

function New-DiamondPath($c) {
  $path = New-RoundRectPath (-($SIDE / 2)) (-($SIDE / 2)) $SIDE $SIDE $DR
  # translate the path to its centre first, then rotate about its own origin
  $m = [System.Drawing.Drawing2D.Matrix]::new()
  $m.Translate($c.cx, $c.cy)
  $m.Rotate(45)
  $path.Transform($m)
  $m.Dispose()
  return $path
}

function Fill-DiamondGradient($g, $dia, $inner, $c) {
  # gradient + waterline, clipped to the inner rounded diamond, screen-space vertical
  $state = $g.Save()
  $g.SetClip($inner)
  $topY = $c.cy - $HALFDIAG
  $wlY = $topY + ($WATER * 2 * $HALFDIAG)
  $rect = [System.Drawing.RectangleF]::new(0, $topY, 1024, (2 * $HALFDIAG))
  $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rect, (C 201 188 236), (C 37 29 72), 90.0)
  $blend = [System.Drawing.Drawing2D.ColorBlend]::new(6)
  $blend.Positions = [float[]]@(0.0, 0.42, 0.455, 0.52, 0.78, 1.0)
  $blend.Colors = [System.Drawing.Color[]]@(
    (C 201 188 236),
    (C 162 146 212),
    (C 214 199 242),
    (C 104 89 172),
    (C 48 39 92),
    (C 30 23 58)
  )
  $brush.InterpolationColors = $blend
  $g.FillPath($brush, $dia)
  $brush.Dispose()
  # waterline glow + core line
  $glow = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(24, 178, 168, 220))
  $g.FillRectangle($glow, ($c.cx - $HALFDIAG * 0.92), ($wlY - 9), ($HALFDIAG * 1.84), 18)
  $glow.Dispose()
  $core = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(70, 230, 224, 248), 3.5)
  $g.DrawLine($core, ($c.cx - $HALFDIAG * 0.92), $wlY, ($c.cx + $HALFDIAG * 0.92), $wlY)
  $core.Dispose()
  $g.Restore($state)
}

function Draw-Art([System.Drawing.Graphics]$g) {
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  # design space: everything below is in 1024 units, rasters at SSx supersampling
  $g.ScaleTransform($SS, $SS)

  # background tile
  $bgPath = New-RoundRectPath 0 0 1024 1024 130
  $bgBrush = [System.Drawing.SolidBrush]::new($BG)
  $g.FillPath($bgBrush, $bgPath)
  $bgBrush.Dispose()
  $bgPath.Dispose()

  foreach ($c in $D) {
    $dia = New-DiamondPath $c
    # border first (whole diamond), then gradient inside
    $bBrush = [System.Drawing.SolidBrush]::new($BORDER)
    $g.FillPath($bBrush, $dia)
    $bBrush.Dispose()
    $innerRaw = New-RoundRectPath (-($SIDE / 2) + $BORDERW) (-($SIDE / 2) + $BORDERW) ($SIDE - 2 * $BORDERW) ($SIDE - 2 * $BORDERW) ([Math]::Max(($DR - $BORDERW), 1))
    $mi = [System.Drawing.Drawing2D.Matrix]::new()
    $mi.Translate($c.cx, $c.cy)
    $mi.Rotate(45)
    $innerRaw.Transform($mi)
    Fill-DiamondGradient $g $dia $innerRaw $c
    $dia.Dispose(); $innerRaw.Dispose(); $mi.Dispose()
  }

  foreach ($d in $DOTS) {
    $r = $d.r
    if ($d.kind -eq 'solid') {
      $b = [System.Drawing.SolidBrush]::new($BORDER)
      $g.FillEllipse($b, ($d.x - $r), ($d.y - $r), 2 * $r, 2 * $r)
      $b.Dispose()
    } else {
      $b = [System.Drawing.SolidBrush]::new($BORDER)
      $g.FillEllipse($b, ($d.x - $r), ($d.y - $r), 2 * $r, 2 * $r)
      $b.Dispose()
      $ir = $r * 0.56
      $b2 = [System.Drawing.SolidBrush]::new($RINGC)
      $g.FillEllipse($b2, ($d.x - $ir), ($d.y - $ir), 2 * $ir, 2 * $ir)
      $b2.Dispose()
    }
  }
}

function Save-Scaled([System.Drawing.Bitmap]$master, [string]$path, [int]$px) {
  $bmp = [System.Drawing.Bitmap]::new($px, $px)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $g.DrawImage($master, 0, 0, $px, $px)
  $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

function Save-Mac([System.Drawing.Bitmap]$master, [string]$path) {
  # macOS app icon: art inset to 824/1024, own squircle radius 185, soft drop shadow
  $bmp = [System.Drawing.Bitmap]::new($U, $U)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $shPath = New-RoundRectPath (100 * $SS) (112 * $SS) (824 * $SS) (824 * $SS) (185 * $SS)
  $tmp = [System.Drawing.Bitmap]::new($U, $U)
  $tg = [System.Drawing.Graphics]::FromImage($tmp)
  $tg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $shBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(110, 6, 4, 14))
  $tg.FillPath($shBrush, $shPath)
  $tg.Dispose()
  $blurred = [System.Drawing.Bitmap]::new($U, $U)
  $bg2 = [System.Drawing.Graphics]::FromImage($blurred)
  $bg2.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $bg2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $bg2.DrawImage($tmp, -24, -20, ($U + 48), ($U + 40))
  $bg2.DrawImage($tmp, -8, -16, ($U + 16), ($U + 32))
  $bg2.Dispose()
  $g.DrawImage($blurred, 0, 0, $U, $U)
  $blurred.Dispose(); $tmp.Dispose(); $shBrush.Dispose()
  $shPath.Dispose()
  $inset = [Math]::Round($U * 824 / 1024)
  $off = [Math]::Round(100 * $SS)
  $macPath = New-RoundRectPath $off $off $inset $inset (185 * ($inset / 824))
  $st = $g.Save()
  $g.SetClip($macPath)
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($master, $off, $off, $inset, $inset)
  $g.Restore($st)
  $macPath.Dispose()
  $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

function Save-Glyph([string]$path, [int]$px, [byte]$rr, [byte]$gg, [byte]$bb) {
  # tray glyph: the brand lattice at small size вЂ” four solid diamonds in a 2x2 grid
  $s = $px * 10
  $bmp = [System.Drawing.Bitmap]::new($s, $s)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $col = [System.Drawing.Color]::FromArgb(255, $rr, $gg, $bb)
  $width = 0.36 * $s
  $side = $width / ([Math]::Sqrt(2))
  foreach ($cpos in @(
    @{ x = 0.5;  y = 0.26 },
    @{ x = 0.26; y = 0.5 },
    @{ x = 0.74; y = 0.5 },
    @{ x = 0.5;  y = 0.74 }
  )) {
    $gp = New-RoundRectPath (-$side / 2) (-$side / 2) $side $side ($side * 0.18)
    $m = [System.Drawing.Drawing2D.Matrix]::new()
    $m.Translate($cpos.x * $s, $cpos.y * $s)
    $m.Rotate(45)
    $gp.Transform($m)
    $b = [System.Drawing.SolidBrush]::new($col)
    $g.FillPath($b, $gp)
    $b.Dispose()
    $gp.Dispose(); $m.Dispose()
  }
  $g.Dispose()
  $small = [System.Drawing.Bitmap]::new($px, $px)
  $g2 = [System.Drawing.Graphics]::FromImage($small)
  $g2.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $g2.DrawImage($bmp, 0, 0, $px, $px)
  $g2.Dispose()
  $bmp.Dispose()
  $small.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $small.Dispose()
}

function Write-Ico($items, [string]$path) {
  $ms = [System.IO.MemoryStream]::new()
  $bw = [System.IO.BinaryWriter]::new($ms)
  $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$items.Count)
  $offset = 6 + 16 * $items.Count
  foreach ($it in $items) {
    $sz = $it.size
    $wb = if ($sz -ge 256) { 0 } else { $sz }
    $bw.Write([byte]$wb); $bw.Write([byte]$wb)
    $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$it.png.Length)
    $bw.Write([uint32]$offset)
    $offset += $it.png.Length
  }
  foreach ($it in $items) { $bw.Write($it.png) }
  $bw.Flush()
  [System.IO.File]::WriteAllBytes($path, $ms.ToArray())
  $bw.Dispose(); $ms.Dispose()
}

function Write-Icns($items, [string]$path) {
  $total = 8
  foreach ($it in $items) { $total += 8 + $it.png.Length }
  $ms = [System.IO.MemoryStream]::new()
  $bw = [System.IO.BinaryWriter]::new($ms)
  $bw.Write([byte[]]@(0x69, 0x63, 0x6E, 0x73))
  $big = [BitConverter]::GetBytes([uint32]$total); [Array]::Reverse($big); $bw.Write($big)
  foreach ($it in $items) {
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes($it.type))
    $len = [BitConverter]::GetBytes([uint32](8 + $it.png.Length)); [Array]::Reverse($len); $bw.Write($len)
    $bw.Write($it.png)
  }
  $bw.Flush()
  [System.IO.File]::WriteAllBytes($path, $ms.ToArray())
  $bw.Dispose(); $ms.Dispose()
}

function Read-Bytes([string]$p) { [System.IO.File]::ReadAllBytes($p) }

# ============ render ============
$master = [System.Drawing.Bitmap]::new($U, $U)
$master.SetResolution(96, 96)
$g = [System.Drawing.Graphics]::FromImage($master)
Draw-Art $g
$g.Dispose()

$iconDir = Join-Path $root 'shared\icon'
$outTmp = Join-Path $env:TEMP 'nxw-icons'
New-Item -ItemType Directory -Force -Path $outTmp | Out-Null

# full-size + size variants (light = brand tile; dark = same tile for theme slots)
foreach ($base in @('nexusewik', 'nexusewik-dark')) {
  Save-Scaled $master (Join-Path $iconDir "$base.png") 1024
  foreach ($n in @(512, 256, 128, 64, 48, 32, 16)) {
    Save-Scaled $master (Join-Path $iconDir "$base-$n.png") $n
  }
  Save-Mac $master (Join-Path $iconDir "$base-mac.png")
}

# ico (native app icons + installer)
$icoItems = @()
foreach ($n in @(16, 24, 32, 48, 64, 128, 256)) {
  $p = Join-Path $outTmp ("i-$n.png")
  Save-Scaled $master $p $n
  $icoItems += @{ size = $n; png = [System.IO.File]::ReadAllBytes($p) }
}
Write-Ico $icoItems (Join-Path $iconDir 'nexusewik.ico')
Copy-Item (Join-Path $iconDir 'nexusewik.ico') (Join-Path $iconDir 'nexusewik-dark.ico') -Force
Write-Ico $icoItems (Join-Path $root 'windows\installer\icon.ico')

# icns (macOS)
$icnsItems = @(
  @{ type = 'ic07'; png = [System.IO.File]::ReadAllBytes((Join-Path $iconDir 'nexusewik-128.png')) },
  @{ type = 'ic11'; png = [System.IO.File]::ReadAllBytes((Join-Path $iconDir 'nexusewik-32.png')) },
  @{ type = 'ic12'; png = [System.IO.File]::ReadAllBytes((Join-Path $iconDir 'nexusewik-64.png')) },
  @{ type = 'ic08'; png = [System.IO.File]::ReadAllBytes((Join-Path $iconDir 'nexusewik-256.png')) },
  @{ type = 'ic09'; png = [System.IO.File]::ReadAllBytes((Join-Path $iconDir 'nexusewik-512.png')) },
  @{ type = 'ic10'; png = [System.IO.File]::ReadAllBytes((Join-Path $iconDir 'nexusewik.png')) }
)
Write-Icns $icnsItems (Join-Path $iconDir 'nexusewik.icns')
Write-Icns $icnsItems (Join-Path $iconDir 'nexusewik-dark.icns')

# window icons + in-app sidebar mark + README icon
Save-Scaled $master (Join-Path $root 'windows\assets\icon.png') 256
Save-Scaled $master (Join-Path $root 'linux\assets\icon.png') 512
foreach ($scaleDir in @('windows\assets', 'linux\assets', 'mac\assets')) {
  Save-Scaled $master (Join-Path $root "$scaleDir\sidebar-icon@1x.png") 60
  Save-Scaled $master (Join-Path $root "$scaleDir\sidebar-icon@2x.png") 120
  Save-Scaled $master (Join-Path $root "$scaleDir\sidebar-icon@3x.png") 180
  Save-Scaled $master (Join-Path $root "$scaleDir\sidebar-icon@4x.png") 240
}
Save-Scaled $master (Join-Path $root '.github\assets\icon.png') 1024

# android launchers + in-app logo
$andr = Join-Path $root 'android\app\src\main\res'
Save-Scaled $master (Join-Path $andr 'mipmap-mdpi\ic_launcher.png') 48
Save-Scaled $master (Join-Path $andr 'mipmap-hdpi\ic_launcher.png') 72
Save-Scaled $master (Join-Path $andr 'mipmap-xhdpi\ic_launcher.png') 96
Save-Scaled $master (Join-Path $andr 'mipmap-xxhdpi\ic_launcher.png') 144
Save-Scaled $master (Join-Path $andr 'mipmap-xxxhdpi\ic_launcher.png') 192
Save-Scaled $master (Join-Path $andr 'drawable-nodpi\nexusewik_logo.png') 240

$master.Dispose()

# ============ tray glyphs ============
$winAssets = Join-Path $root 'windows\assets'
$linAssets = Join-Path $root 'linux\assets'
foreach ($spec in @(
  @{ f = 'tray-white.png'; px = 16; c = 255 },
  @{ f = 'tray-black.png'; px = 16; c = 0 },
  @{ f = 'tray.png'; px = 16; c = 255 },
  @{ f = 'tray-white@2x.png'; px = 32; c = 255 },
  @{ f = 'tray-black@2x.png'; px = 32; c = 0 },
  @{ f = 'tray@2x.png'; px = 32; c = 255 }
)) {
  Save-Glyph (Join-Path $winAssets $spec.f) $spec.px $spec.c $spec.c $spec.c
}
Save-Glyph (Join-Path $linAssets 'tray.png') 16 255 255 255
Save-Glyph (Join-Path $linAssets 'tray@2x.png') 32 255 255 255
Save-Glyph (Join-Path $iconDir 'trayTemplate.png') 18 0 0 0
Save-Glyph (Join-Path $iconDir 'trayTemplate@2x.png') 36 0 0 0
Save-Glyph (Join-Path $root 'mac\assets\trayTemplate.png') 18 0 0 0
Save-Glyph (Join-Path $root 'mac\assets\trayTemplate@2x.png') 36 0 0 0

'icons done'
