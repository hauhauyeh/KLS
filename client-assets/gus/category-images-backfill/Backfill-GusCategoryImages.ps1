param(
    [switch]$Apply,
    [int]$Limit = 0,
    [string]$Server = 'lpc:(local)\SQLEXPRESS',
    [string]$Database = 'GUS_2026',
    [string]$SqlCmdPath = 'C:\Users\Howard Yeh\AppData\Local\sqlcmd\sqlcmd.exe',
    [string]$SqlUser = 'sa',
    [string]$SqlPassword = 'ketchup88'
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot '..\..\..')
$categoryRoot = Join-Path $repoRoot 'KLS.API\wwwroot\Images\category'
$dryRun = -not $Apply

Add-Type -AssemblyName System.Drawing

function Invoke-KlsSqlLines {
    param([Parameter(Mandatory = $true)][string]$Query)

    & $SqlCmdPath -S $Server -d $Database -U $SqlUser -P $SqlPassword -N -C -b -h -1 -W -Q $Query
}

function Invoke-KlsSqlFile {
    param([Parameter(Mandatory = $true)][string]$Sql)

    $tempFile = Join-Path ([IO.Path]::GetTempPath()) ("kls-category-image-backfill-{0}.sql" -f ([Guid]::NewGuid().ToString('N')))
    try {
        Set-Content -LiteralPath $tempFile -Value $Sql -Encoding ascii
        & $SqlCmdPath -S $Server -d $Database -U $SqlUser -P $SqlPassword -N -C -b -i $tempFile
    }
    finally {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force
        }
    }
}

function ConvertTo-SqlString {
    param([string]$Value)

    if ($null -eq $Value) { return 'NULL' }
    return "N'$($Value.Replace("'", "''"))'"
}

function Get-LegacyImageFileName {
    param([Parameter(Mandatory = $true)][string]$ImageUrl)

    $pathPart = $ImageUrl.Split('?')[0]
    return [IO.Path]::GetFileName($pathPart)
}

function Save-ResizedPng {
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

        $bitmap = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::Transparent)
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

function Get-ImageMaxDimension {
    param([Parameter(Mandatory = $true)][string]$SourcePath)

    $image = [System.Drawing.Image]::FromFile($SourcePath)
    try {
        return [Math]::Max($image.Width, $image.Height)
    }
    finally {
        $image.Dispose()
    }
}

function Update-CategoryImageMetadata {
    param(
        [Parameter(Mandatory = $true)][int]$CategoryId,
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][bool]$Has300,
        [Parameter(Mandatory = $true)][bool]$Has1200
    )

    $imageUrl = if ($Has1200) {
        "/Images/category/$CategoryId/1-1200.png"
    }
    elseif ($Has300) {
        "/Images/category/$CategoryId/1-300.png"
    }
    else {
        $null
    }

    $sql = @"
SET XACT_ABORT ON;

UPDATE dbo.ItemCategory
SET OriginalImageExtension = $(ConvertTo-SqlString $Extension),
    IsImageProcessed = 0,
    IsImageProcessing = 0,
    HasImage300 = $(if ($Has300) { 1 } else { 0 }),
    HasImage1200 = $(if ($Has1200) { 1 } else { 0 }),
    HasNoBg300 = 0,
    HasNoBg1200 = 0,
    ImageUrl = COALESCE($(ConvertTo-SqlString $imageUrl), ImageUrl),
    UpdatedAt = GETUTCDATE()
WHERE CategoryId = $CategoryId;
"@

    Invoke-KlsSqlFile -Sql $sql
}

if (-not (Test-Path -LiteralPath $SqlCmdPath)) {
    throw "sqlcmd not found: $SqlCmdPath"
}

if (-not (Test-Path -LiteralPath $categoryRoot)) {
    throw "Category image root not found: $categoryRoot"
}

$query = @"
SET NOCOUNT ON;
SELECT CONCAT(CategoryId, CHAR(9), ImageUrl)
FROM dbo.ItemCategory
WHERE NULLIF(LTRIM(RTRIM(ImageUrl)), '') IS NOT NULL
  AND ISNULL(HasImage300, 0) = 0
  AND ISNULL(HasImage1200, 0) = 0
ORDER BY CategoryId;
"@

$rows = Invoke-KlsSqlLines -Query $query |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object {
        $parts = $_ -split "`t", 2
        [PSCustomObject]@{
            CategoryId = [int]$parts[0]
            ImageUrl = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        }
    }

if ($Limit -gt 0) {
    $rows = $rows | Select-Object -First $Limit
}

$summary = [ordered]@{
    DryRun = $dryRun
    Found = 0
    Converted = 0
    AlreadyVersioned = 0
    MissingSource = 0
    Unsupported = 0
    Failed = 0
}

$allowedExtensions = @('.jpg', '.jpeg', '.png', '.webp')

foreach ($row in $rows) {
    $summary.Found++

    $fileName = Get-LegacyImageFileName -ImageUrl $row.ImageUrl
    $extension = [IO.Path]::GetExtension($fileName).ToLowerInvariant()
    $sourcePath = Join-Path $categoryRoot $fileName
    $targetFolder = Join-Path $categoryRoot $row.CategoryId
    $orgPath = Join-Path $targetFolder "1-org$extension"
    $path300 = Join-Path $targetFolder '1-300.png'
    $path1200 = Join-Path $targetFolder '1-1200.png'

    if ((Test-Path -LiteralPath $path300) -or (Test-Path -LiteralPath $path1200)) {
        $summary.AlreadyVersioned++
        Write-Host "Category $($row.CategoryId): already has version files, skipping."
        continue
    }

    if ($allowedExtensions -notcontains $extension) {
        $summary.Unsupported++
        Write-Host "Category $($row.CategoryId): unsupported extension '$extension', skipping."
        continue
    }

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        $summary.MissingSource++
        Write-Host "Category $($row.CategoryId): missing source '$sourcePath', skipping."
        continue
    }

    try {
        $maxDimension = Get-ImageMaxDimension -SourcePath $sourcePath
        $will1200 = $maxDimension -ge 1200

        if ($dryRun) {
            $summary.Converted++
            Write-Host "DRY RUN Category $($row.CategoryId): $fileName -> 1-org$extension, 1-300.png$(if ($will1200) { ', 1-1200.png' } else { '' })"
            continue
        }

        New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null

        Copy-Item -LiteralPath $sourcePath -Destination $orgPath -Force
        Save-ResizedPng -SourcePath $sourcePath -DestinationPath $path300 -Size 300

        if ($will1200) {
            Save-ResizedPng -SourcePath $sourcePath -DestinationPath $path1200 -Size 1200
        }

        Update-CategoryImageMetadata `
            -CategoryId $row.CategoryId `
            -Extension $extension `
            -Has300 (Test-Path -LiteralPath $path300) `
            -Has1200 (Test-Path -LiteralPath $path1200)

        $summary.Converted++
        Write-Host "Category $($row.CategoryId): converted $fileName."
    }
    catch {
        $summary.Failed++
        Write-Host "Category $($row.CategoryId): FAILED - $($_.Exception.Message)"
    }
}

Write-Host ''
Write-Host 'Category image backfill summary:'
$summary.GetEnumerator() | ForEach-Object {
    Write-Host ("{0}: {1}" -f $_.Key, $_.Value)
}

if ($dryRun) {
    Write-Host ''
    Write-Host 'Dry-run only. Re-run with -Apply to create files and update ItemCategory metadata.'
}
