[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
	[Parameter(Mandatory = $true)]
	[string[]]$SetNames
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$setSourceRoot = Join-Path $repositoryRoot 'sets'
$maskAssetPath = Join-Path $PSScriptRoot 'assets\english-card-alpha-mask.png'
if (-not (Test-Path -LiteralPath $maskAssetPath -PathType Leaf)) {
	throw "English card alpha mask not found: '$maskAssetPath'."
}

$processorType = 'FftcgImageMaskProcessor' -as [type]
if ($null -eq $processorType) {
	Add-Type -AssemblyName System.Drawing
	$typeDefinition = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class FftcgImageMaskProcessor
{
    private static int GetBytesPerPixel(PixelFormat format)
    {
        if (format == PixelFormat.Format24bppRgb) return 3;
        if (format == PixelFormat.Format32bppArgb || format == PixelFormat.Format32bppRgb) return 4;
        throw new InvalidOperationException("Unsupported card image pixel format: " + format);
    }

    public static byte[] ReadMask(Bitmap reference)
    {
        if (reference.PixelFormat != PixelFormat.Format32bppArgb)
            throw new InvalidOperationException("The alpha mask must use Format32bppArgb.");

        var rect = new Rectangle(0, 0, reference.Width, reference.Height);
        var data = reference.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try
        {
            if (data.Stride <= 0) throw new InvalidOperationException("Unsupported reference image stride.");
            var alpha = new byte[reference.Width * reference.Height];
            var row = new byte[data.Stride];
            for (int y = 0; y < reference.Height; y++)
            {
                Marshal.Copy(IntPtr.Add(data.Scan0, y * data.Stride), row, 0, data.Stride);
                for (int x = 0; x < reference.Width; x++)
                    alpha[y * reference.Width + x] = row[x * 4 + 3];
            }
            return alpha;
        }
        finally { reference.UnlockBits(data); }
    }

    public static void Apply(string sourcePath, string outputPath, byte[] alphaMask, int width, int height)
    {
        using (var source = new Bitmap(sourcePath))
        {
            if (source.Width != width || source.Height != height)
                throw new InvalidOperationException("Image dimensions do not match the reference mask.");
            int sourceBytesPerPixel = GetBytesPerPixel(source.PixelFormat);
            using (var output = new Bitmap(width, height, PixelFormat.Format32bppArgb))
            {
                var rect = new Rectangle(0, 0, width, height);
                BitmapData sourceData = null;
                BitmapData outputData = null;
                try
                {
                    sourceData = source.LockBits(rect, ImageLockMode.ReadOnly, source.PixelFormat);
                    outputData = output.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                    if (sourceData.Stride <= 0 || outputData.Stride <= 0)
                        throw new InvalidOperationException("Unsupported card image stride.");

                    var sourceRow = new byte[sourceData.Stride];
                    var outputRow = new byte[outputData.Stride];
                    for (int y = 0; y < height; y++)
                    {
                        Marshal.Copy(IntPtr.Add(sourceData.Scan0, y * sourceData.Stride), sourceRow, 0, sourceData.Stride);
                        Array.Clear(outputRow, 0, outputRow.Length);
                        for (int x = 0; x < width; x++)
                        {
                            int sourceIndex = x * sourceBytesPerPixel;
                            int outputIndex = x * 4;
                            outputRow[outputIndex] = sourceRow[sourceIndex];
                            outputRow[outputIndex + 1] = sourceRow[sourceIndex + 1];
                            outputRow[outputIndex + 2] = sourceRow[sourceIndex + 2];
                            outputRow[outputIndex + 3] = alphaMask[y * width + x];
                        }
                        Marshal.Copy(outputRow, 0, IntPtr.Add(outputData.Scan0, y * outputData.Stride), outputData.Stride);
                    }
                }
                finally
                {
                    if (outputData != null) output.UnlockBits(outputData);
                    if (sourceData != null) source.UnlockBits(sourceData);
                }
                output.Save(outputPath, ImageFormat.Png);
            }
        }
    }

    public static bool Validate(string sourcePath, string outputPath, byte[] alphaMask, int width, int height)
    {
        using (var source = new Bitmap(sourcePath))
        using (var output = new Bitmap(outputPath))
        {
            if (source.Width != width || source.Height != height ||
                output.Width != width || output.Height != height ||
                output.PixelFormat != PixelFormat.Format32bppArgb)
                return false;

            int sourceBytesPerPixel = GetBytesPerPixel(source.PixelFormat);
            var rect = new Rectangle(0, 0, width, height);
            BitmapData sourceData = null;
            BitmapData outputData = null;
            try
            {
                sourceData = source.LockBits(rect, ImageLockMode.ReadOnly, source.PixelFormat);
                outputData = output.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                var sourceRow = new byte[sourceData.Stride];
                var outputRow = new byte[outputData.Stride];
                for (int y = 0; y < height; y++)
                {
                    Marshal.Copy(IntPtr.Add(sourceData.Scan0, y * sourceData.Stride), sourceRow, 0, sourceData.Stride);
                    Marshal.Copy(IntPtr.Add(outputData.Scan0, y * outputData.Stride), outputRow, 0, outputData.Stride);
                    for (int x = 0; x < width; x++)
                    {
                        int sourceIndex = x * sourceBytesPerPixel;
                        int outputIndex = x * 4;
                        if (sourceRow[sourceIndex] != outputRow[outputIndex] ||
                            sourceRow[sourceIndex + 1] != outputRow[outputIndex + 1] ||
                            sourceRow[sourceIndex + 2] != outputRow[outputIndex + 2] ||
                            alphaMask[y * width + x] != outputRow[outputIndex + 3])
                            return false;
                    }
                }
                return true;
            }
            finally
            {
                if (outputData != null) output.UnlockBits(outputData);
                if (sourceData != null) source.UnlockBits(sourceData);
            }
        }
    }
}
'@
	Add-Type -TypeDefinition $typeDefinition -ReferencedAssemblies 'System.Drawing'
	$processorType = 'FftcgImageMaskProcessor' -as [type]
}

$maskBitmap = [System.Drawing.Bitmap]::FromFile($maskAssetPath)
try {
	if ($maskBitmap.Width -le 0 -or $maskBitmap.Height -le 0) {
		throw "Invalid alpha mask dimensions: '$maskAssetPath'."
	}
	$maskWidth = $maskBitmap.Width
	$maskHeight = $maskBitmap.Height
	$alphaMask = [FftcgImageMaskProcessor]::ReadMask($maskBitmap)
}
finally {
	$maskBitmap.Dispose()
}

$setDirectories = @{}
foreach ($directory in Get-ChildItem -LiteralPath $setSourceRoot -Directory) {
	$setDirectories[$directory.Name] = $directory.FullName
}

$imageFiles = @()
$selectedSetNames = @()
foreach ($requestedSetName in $SetNames) {
	if ([string]::IsNullOrWhiteSpace($requestedSetName) -or -not $setDirectories.ContainsKey($requestedSetName)) {
		throw "Set directory not found under '$setSourceRoot': '$requestedSetName'."
	}
	if ($selectedSetNames -contains $requestedSetName) {
		throw "Set directory was specified more than once: '$requestedSetName'."
	}

	$setPath = $setDirectories[$requestedSetName]
	$setFile = Join-Path $setPath 'set.xml'
	if (-not (Test-Path -LiteralPath $setFile -PathType Leaf)) {
		throw "Set metadata not found: '$setFile'."
	}
	[xml]$set = Get-Content -LiteralPath $setFile -Raw
	$cardIds = @{}
	foreach ($card in @($set.set.cards.card)) {
		$cardGuid = [guid]::Empty
		if (-not [guid]::TryParse($card.id, [ref]$cardGuid)) {
			throw "Invalid card UUID '$($card.id)' in '$setFile'."
		}
		$cardIds[$cardGuid.ToString()] = $true
	}

	$cardsPath = Join-Path (Join-Path $setPath 'Cards') 'en'
	if (-not (Test-Path -LiteralPath $cardsPath -PathType Container)) {
		throw "English card image directory not found: '$cardsPath'."
	}
	if (@(Get-ChildItem -LiteralPath $cardsPath -Directory -Force).Count -gt 0) {
		throw "Expected UUID-named PNGs directly under '$cardsPath'; nested directories were found."
	}
	$setImages = @(Get-ChildItem -LiteralPath $cardsPath -File -Force)
	if ($setImages.Count -eq 0) {
		throw "No English card images found in '$cardsPath'."
	}
	$nonPngFiles = @($setImages | Where-Object { $_.Extension -ine '.png' })
	if ($nonPngFiles.Count -gt 0) {
		throw "Expected PNG files only in '$cardsPath'; found: $($nonPngFiles.Name -join ', ')."
	}

	foreach ($image in $setImages) {
		$imageGuid = [guid]::Empty
		if (-not [guid]::TryParse($image.BaseName, [ref]$imageGuid) -or -not $cardIds.ContainsKey($imageGuid.ToString())) {
			throw "Image filename does not match a card UUID in '$setFile': $($image.Name)"
		}

		$bitmap = [System.Drawing.Bitmap]::FromFile($image.FullName)
		try {
			if ($bitmap.Width -ne $maskWidth -or $bitmap.Height -ne $maskHeight) {
				throw "Image '$($image.FullName)' is $($bitmap.Width)x$($bitmap.Height); expected ${maskWidth}x${maskHeight} to match the reference."
			}
			if ($bitmap.PixelFormat.ToString() -notin @('Format24bppRgb', 'Format32bppRgb', 'Format32bppArgb')) {
				throw "Image '$($image.FullName)' has unsupported pixel format '$($bitmap.PixelFormat)'."
			}
		}
		finally {
			$bitmap.Dispose()
		}

		$imageFiles += [pscustomobject]@{
			SetName = $requestedSetName
			Name = $image.Name
			Path = $image.FullName
		}
	}
	$selectedSetNames += $requestedSetName
}

if ($imageFiles.Count -eq 0) {
	throw 'Select at least one set directory name with -SetNames.'
}

$targetSummary = "$($imageFiles.Count) English PNGs in $($selectedSetNames -join ', ')"
if (-not $PSCmdlet.ShouldProcess($targetSummary, 'Apply rounded-corner alpha mask')) {
	return
}

$temporaryRoot = Join-Path $repositoryRoot 'tmp'
if (-not (Test-Path -LiteralPath $temporaryRoot -PathType Container)) {
	[void](New-Item -ItemType Directory -Path $temporaryRoot)
}
$stageRoot = Join-Path $temporaryRoot ('round-card-images-' + [guid]::NewGuid().ToString('N'))
$stagedImages = Join-Path $stageRoot 'masked'
$originalImages = Join-Path $stageRoot 'originals'
[void](New-Item -ItemType Directory -Path $stagedImages -Force)
[void](New-Item -ItemType Directory -Path $originalImages -Force)

$attemptedImages = [System.Collections.Generic.List[object]]::new()
$preserveStage = $false
try {
	foreach ($image in $imageFiles) {
		$stagedSetPath = Join-Path $stagedImages $image.SetName
		$originalSetPath = Join-Path $originalImages $image.SetName
		if (-not (Test-Path -LiteralPath $stagedSetPath -PathType Container)) {
			[void](New-Item -ItemType Directory -Path $stagedSetPath -Force)
			[void](New-Item -ItemType Directory -Path $originalSetPath -Force)
		}

		$stagedPath = Join-Path $stagedSetPath $image.Name
		[ FftcgImageMaskProcessor ]::Apply($image.Path, $stagedPath, $alphaMask, $maskWidth, $maskHeight)
		if (-not [FftcgImageMaskProcessor]::Validate($image.Path, $stagedPath, $alphaMask, $maskWidth, $maskHeight)) {
			throw "Staged image failed pixel validation: '$($image.Path)'."
		}
		[System.IO.File]::Copy($image.Path, (Join-Path $originalSetPath $image.Name), $false)
	}

	foreach ($image in $imageFiles) {
		$stagedPath = Join-Path (Join-Path $stagedImages $image.SetName) $image.Name
		$attemptedImages.Add($image)
		[System.IO.File]::Copy($stagedPath, $image.Path, $true)
	}

	foreach ($image in $imageFiles) {
		$originalPath = Join-Path (Join-Path $originalImages $image.SetName) $image.Name
		if (-not [FftcgImageMaskProcessor]::Validate($originalPath, $image.Path, $alphaMask, $maskWidth, $maskHeight)) {
			throw "Installed image failed pixel validation: '$($image.Path)'."
		}
	}

	Write-Host "Applied and validated the reference alpha mask to $($imageFiles.Count) English card images across $($selectedSetNames.Count) set(s)."
	Write-Host "Reference dimensions: ${maskWidth}x${maskHeight}; RGB pixels preserved."
}
catch {
	$failure = $_
	$restoreErrors = @()
	foreach ($image in $attemptedImages) {
		$originalPath = Join-Path (Join-Path $originalImages $image.SetName) $image.Name
		if (Test-Path -LiteralPath $originalPath -PathType Leaf) {
			try {
				[System.IO.File]::Copy($originalPath, $image.Path, $true)
			}
			catch {
				$restoreErrors += "$($image.Path): $($_.Exception.Message)"
			}
		}
	}
	if ($restoreErrors.Count -gt 0) {
		$preserveStage = $true
		throw "$($failure.Exception.Message) Rollback failed for: $($restoreErrors -join '; '). Backups are preserved at '$stageRoot'."
	}
	throw $failure
}
finally {
	if (-not $preserveStage -and (Test-Path -LiteralPath $stageRoot -PathType Container)) {
		try {
			Remove-Item -LiteralPath $stageRoot -Recurse -Force
		}
		catch {
			Write-Warning "Could not remove temporary staging data at '$stageRoot': $($_.Exception.Message)"
		}
	}
}
