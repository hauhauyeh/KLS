$ErrorActionPreference = 'Stop'

$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $packageRoot '..\..\..')
$manifestPath = Join-Path $packageRoot 'bootstrap-general-mapping.csv'
$sourceRoot = Join-Path $packageRoot 'source'
$itemsRoot = Join-Path $repoRoot 'KLS.API\wwwroot\Images\items'

Add-Type -AssemblyName System.Drawing

function Save-Resized {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][int]$Size
    )

    $image = [System.Drawing.Image]::FromFile($SourcePath)
    try {
        $ratio = [Math]::Min($Size / [double]$image.Width, $Size / [double]$image.Height)
        $width = [Math]::Max(1, [int][Math]::Round($image.Width * $ratio))
        $height = [Math]::Max(1, [int][Math]::Round($image.Height * $ratio))
        $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::White)
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $x = [int](($Size - $width) / 2)
                $y = [int](($Size - $height) / 2)
                $graphics.DrawImage($image, $x, $y, $width, $height)
            }
            finally {
                $graphics.Dispose()
            }

            $bitmap.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $bitmap.Dispose()
        }
    }
    finally {
        $image.Dispose()
    }
}

New-Item -ItemType Directory -Force -Path $itemsRoot | Out-Null

$rows = Import-Csv $manifestPath
foreach ($row in $rows) {
    $sourcePath = Join-Path $sourceRoot "$($row.ImageKey).png"
    if (-not (Test-Path $sourcePath)) {
        throw "Missing source image: $sourcePath"
    }

    $itemFolder = Join-Path $itemsRoot $row.ItemId
    New-Item -ItemType Directory -Force -Path $itemFolder | Out-Null

    Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $itemFolder '101-org.png') -Force
    Save-Resized -SourcePath $sourcePath -DestinationPath (Join-Path $itemFolder '101-300.png') -Size 300
    Save-Resized -SourcePath $sourcePath -DestinationPath (Join-Path $itemFolder '101-1200.png') -Size 1200
}

Write-Host "Generated bootstrap images for $($rows.Count) GUS items."
