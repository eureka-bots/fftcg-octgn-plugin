[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
	[Parameter(Mandatory = $true)]
	[string]$TopImage,
	[Parameter(Mandatory = $true)]
	[string]$BottomImage,
	[ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]*$')]
	[string]$Name = 'dissidia',
	[string]$OutputDirectory,
	[ValidateRange(1, 100)]
	[int]$ArtworkOpacity = 70,
	[string]$DamageZoneImage,
	[string]$TopDamageZoneImage,
	[string]$BottomDamageZoneImage,
	[switch]$Force
)

$ErrorActionPreference = 'Stop'

if ($Name -ieq 'solid') {
	throw "The output name 'solid' is reserved for the source templates."
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$gameDirectories = @(Get-ChildItem -LiteralPath $repositoryRoot -Directory | Where-Object {
	Test-Path -LiteralPath (Join-Path $_.FullName 'definition.xml') -PathType Leaf
})
if ($gameDirectories.Count -ne 1) {
	throw "Expected exactly one OCTGN game directory under '$repositoryRoot'; found $($gameDirectories.Count)."
}

$backgroundRoot = Join-Path $gameDirectories[0].FullName 'resources\backgrounds'
$templatePaths = @(
	(Join-Path $backgroundRoot 'solid_1.png'),
	(Join-Path $backgroundRoot 'solid_2.png')
)
foreach ($templatePath in $templatePaths) {
	if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
		throw "Playmat template not found: '$templatePath'."
	}
}

foreach ($imagePath in @($TopImage, $BottomImage)) {
	if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
		throw "Artwork image not found: '$imagePath'."
	}
}
$topImagePath = (Resolve-Path -LiteralPath $TopImage).Path
$bottomImagePath = (Resolve-Path -LiteralPath $BottomImage).Path
$sharedDamageZoneImagePath = $null
if (-not [string]::IsNullOrWhiteSpace($DamageZoneImage)) {
	if (-not (Test-Path -LiteralPath $DamageZoneImage -PathType Leaf)) {
		throw "Damage zone image not found: '$DamageZoneImage'."
	}
	$sharedDamageZoneImagePath = (Resolve-Path -LiteralPath $DamageZoneImage).Path
}
$topDamageZoneImagePath = $sharedDamageZoneImagePath
if (-not [string]::IsNullOrWhiteSpace($TopDamageZoneImage)) {
	if (-not (Test-Path -LiteralPath $TopDamageZoneImage -PathType Leaf)) {
		throw "Top damage zone image not found: '$TopDamageZoneImage'."
	}
	$topDamageZoneImagePath = (Resolve-Path -LiteralPath $TopDamageZoneImage).Path
}
$bottomDamageZoneImagePath = $sharedDamageZoneImagePath
if (-not [string]::IsNullOrWhiteSpace($BottomDamageZoneImage)) {
	if (-not (Test-Path -LiteralPath $BottomDamageZoneImage -PathType Leaf)) {
		throw "Bottom damage zone image not found: '$BottomDamageZoneImage'."
	}
	$bottomDamageZoneImagePath = (Resolve-Path -LiteralPath $BottomDamageZoneImage).Path
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
	$outputDirectory = $backgroundRoot
}
elseif (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
	throw "Output directory not found: '$OutputDirectory'."
}
else {
	$outputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
}

$outputPaths = @(
	(Join-Path $outputDirectory "${Name}_1.png"),
	(Join-Path $outputDirectory "${Name}_2.png")
)
if (-not $Force) {
	$existingOutputs = @($outputPaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
	if ($existingOutputs.Count -gt 0) {
		throw "Output already exists: '$($existingOutputs -join "', '")'. Pass -Force to replace it."
	}
}

if (-not $PSCmdlet.ShouldProcess(($outputPaths -join ', '), 'Generate playmat backgrounds')) {
	return
}

$builderType = 'FftcgPlaymatBackgroundBuilderV5' -as [type]
if ($null -eq $builderType) {
	Add-Type -AssemblyName System.Drawing
	$typeDefinition = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class FftcgPlaymatBackgroundBuilderV5
{
    private const int CanvasWidth = 1800;
    private const int CanvasHeight = 800;
    // Both solid templates share these player panels; solid_2 adds damage zones outside them.
    private static readonly Rectangle TopPanel = new Rectangle(276, 30, 1248, 350);
    private static readonly Rectangle BottomPanel = new Rectangle(276, 420, 1248, 350);
    private static readonly Rectangle TopDamageZone = new Rectangle(1548, 30, 222, 350);
    private static readonly Rectangle BottomDamageZone = new Rectangle(30, 420, 222, 350);
    private static readonly Rectangle TopDamageZoneLogo = new Rectangle(1570, 160, 178, 100);
    private static readonly Rectangle BottomDamageZoneLogo = new Rectangle(52, 550, 178, 100);
    private static readonly Rectangle TopDamageZoneLabelShadow = new Rectangle(1597, 54, 124, 30);
    private static readonly Rectangle BottomDamageZoneLabelShadow = new Rectangle(79, 716, 124, 30);
    private static readonly int[] BarCenterRows = new int[] { 42, 209, 589, 756 };
    private const byte PlaceholderBlackThreshold = 5;
    private const byte DamageZoneOverlayDarkThreshold = 60;
    private const byte BarShadowMaximum = 40;
    private const byte BarHaloOpacityScale = 2;
    private const int BarShadowRadius = 6;
    private const int ShadowNeighborRadius = 1;

    public static void Build(string templatePath, string topImagePath, string bottomImagePath, string topDamageZoneImagePath, string bottomDamageZoneImagePath, string outputPath, int opacityPercent)
    {
        using (var template = new Bitmap(templatePath))
        using (var topImage = new Bitmap(topImagePath))
        using (var bottomImage = new Bitmap(bottomImagePath))
        using (var topDamageZoneImage = string.IsNullOrEmpty(topDamageZoneImagePath) ? null : new Bitmap(topDamageZoneImagePath))
        using (var bottomDamageZoneImage = string.IsNullOrEmpty(bottomDamageZoneImagePath) ? null : new Bitmap(bottomDamageZoneImagePath))
        {
            ValidateTemplate(template, templatePath);
            if (topImage.Width <= 0 || topImage.Height <= 0 || bottomImage.Width <= 0 || bottomImage.Height <= 0)
                throw new InvalidOperationException("Artwork images must have non-zero dimensions.");
            if (topDamageZoneImage != null && (topDamageZoneImage.Width <= 0 || topDamageZoneImage.Height <= 0))
                throw new InvalidOperationException("Top damage zone image must have non-zero dimensions.");
            if (bottomDamageZoneImage != null && (bottomDamageZoneImage.Width <= 0 || bottomDamageZoneImage.Height <= 0))
                throw new InvalidOperationException("Bottom damage zone image must have non-zero dimensions.");

            using (var artwork = new Bitmap(CanvasWidth, CanvasHeight, PixelFormat.Format32bppArgb))
            {
                using (var graphics = Graphics.FromImage(artwork))
                {
                    graphics.Clear(Color.Transparent);
                    graphics.CompositingMode = CompositingMode.SourceOver;
                    graphics.CompositingQuality = CompositingQuality.HighQuality;
                    graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;

                    DrawCover(graphics, topImage, TopPanel, true);
                    DrawCover(graphics, bottomImage, BottomPanel, false);
                    if (topDamageZoneImage != null)
                        DrawCover(graphics, topDamageZoneImage, TopDamageZone, true);
                    if (bottomDamageZoneImage != null)
                        DrawCover(graphics, bottomDamageZoneImage, BottomDamageZone, false);
                }

                bool includeTopDamageZone = topDamageZoneImage != null;
                bool includeBottomDamageZone = bottomDamageZoneImage != null;
                ApplyTemplateMask(artwork, template, opacityPercent, includeTopDamageZone, includeBottomDamageZone);
                using (var overlay = CreateTemplateOverlay(template, includeTopDamageZone, includeBottomDamageZone))
                using (var result = new Bitmap(CanvasWidth, CanvasHeight, PixelFormat.Format32bppArgb))
                {
                    using (var graphics = Graphics.FromImage(result))
                    {
                        graphics.Clear(Color.Transparent);
                        graphics.CompositingMode = CompositingMode.SourceOver;
                        graphics.DrawImageUnscaled(artwork, 0, 0);
                        graphics.DrawImageUnscaled(overlay, 0, 0);
                    }
                    result.Save(outputPath, ImageFormat.Png);
                }
            }
        }

        using (var generated = new Bitmap(outputPath))
        {
            if (generated.Width != CanvasWidth || generated.Height != CanvasHeight)
                throw new InvalidOperationException("Generated playmat dimensions are invalid: " + outputPath);
        }
    }

    private static void DrawCover(Graphics graphics, Bitmap source, Rectangle destination, bool rotate180)
    {
        using (var oriented = new Bitmap(source))
        {
            if (rotate180)
                oriented.RotateFlip(RotateFlipType.Rotate180FlipNone);

            float sourceWidth = oriented.Width;
            float sourceHeight = oriented.Height;
            float sourceAspect = sourceWidth / sourceHeight;
            float targetAspect = (float)destination.Width / destination.Height;
            float sourceX = 0;
            float sourceY = 0;

            if (sourceAspect > targetAspect)
            {
                sourceWidth = sourceHeight * targetAspect;
                sourceX = (oriented.Width - sourceWidth) / 2f;
            }
            else if (sourceAspect < targetAspect)
            {
                sourceHeight = sourceWidth / targetAspect;
                sourceY = (oriented.Height - sourceHeight) / 2f;
            }

            graphics.DrawImage(
                oriented,
                destination,
                sourceX,
                sourceY,
                sourceWidth,
                sourceHeight,
                GraphicsUnit.Pixel);
        }
    }

    private static void ApplyTemplateMask(Bitmap artwork, Bitmap template, int opacityPercent, bool includeTopDamageZone, bool includeBottomDamageZone)
    {
        var rect = new Rectangle(0, 0, CanvasWidth, CanvasHeight);
        BitmapData artworkData = null;
        BitmapData templateData = null;
        try
        {
            artworkData = artwork.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            templateData = template.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            if (artworkData.Stride <= 0 || templateData.Stride <= 0)
                throw new InvalidOperationException("Unsupported playmat image stride.");

            var artworkRow = new byte[artworkData.Stride];
            var templateRow = new byte[templateData.Stride];
            for (int y = 0; y < CanvasHeight; y++)
            {
                Marshal.Copy(IntPtr.Add(artworkData.Scan0, y * artworkData.Stride), artworkRow, 0, artworkData.Stride);
                Marshal.Copy(IntPtr.Add(templateData.Scan0, y * templateData.Stride), templateRow, 0, templateData.Stride);
                for (int x = 0; x < CanvasWidth; x++)
                {
                    if (IsArtworkRegion(x, y, includeTopDamageZone, includeBottomDamageZone))
                    {
                        int index = x * 4 + 3;
                        int opacityAlpha = (artworkRow[index] * opacityPercent + 50) / 100;
                        artworkRow[index] = (byte)((opacityAlpha * templateRow[index] + 127) / 255);
                    }
                }
                Marshal.Copy(artworkRow, 0, IntPtr.Add(artworkData.Scan0, y * artworkData.Stride), artworkData.Stride);
            }
        }
        finally
        {
            if (templateData != null) template.UnlockBits(templateData);
            if (artworkData != null) artwork.UnlockBits(artworkData);
        }
    }

    private static Bitmap CreateTemplateOverlay(Bitmap template, bool includeTopDamageZone, bool includeBottomDamageZone)
    {
        var overlay = new Bitmap(CanvasWidth, CanvasHeight, PixelFormat.Format32bppArgb);
        var rect = new Rectangle(0, 0, CanvasWidth, CanvasHeight);
        BitmapData templateData = null;
        BitmapData overlayData = null;
        bool completed = false;
        try
        {
            templateData = template.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            overlayData = overlay.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            if (templateData.Stride <= 0 || overlayData.Stride <= 0)
                throw new InvalidOperationException("Unsupported playmat image stride.");

            var templatePixels = new byte[templateData.Stride * CanvasHeight];
            var overlayRow = new byte[overlayData.Stride];
            Marshal.Copy(templateData.Scan0, templatePixels, 0, templatePixels.Length);
            for (int y = 0; y < CanvasHeight; y++)
            {
                Array.Copy(templatePixels, y * templateData.Stride, overlayRow, 0, templateData.Stride);
                for (int x = 0; x < CanvasWidth; x++)
                {
                    if (IsArtworkRegion(x, y, includeTopDamageZone, includeBottomDamageZone))
                    {
                        int index = x * 4;
                        bool isDamageZoneLogo =
                            (includeTopDamageZone && TopDamageZoneLogo.Contains(x, y)) ||
                            (includeBottomDamageZone && BottomDamageZoneLogo.Contains(x, y));
                        bool isCustomDamageZone =
                            (includeTopDamageZone && TopDamageZone.Contains(x, y)) ||
                            (includeBottomDamageZone && BottomDamageZone.Contains(x, y));
                        bool isDamageZoneLabelShadow =
                            (includeTopDamageZone && TopDamageZoneLabelShadow.Contains(x, y)) ||
                            (includeBottomDamageZone && BottomDamageZoneLabelShadow.Contains(x, y));
                        int maximumColor = Math.Max(overlayRow[index], Math.Max(overlayRow[index + 1], overlayRow[index + 2]));
                        bool preserveDamageLabelShadow =
                            isDamageZoneLabelShadow &&
                            maximumColor <= PlaceholderBlackThreshold &&
                            HasVisibleNeighbor(templatePixels, templateData.Stride, x, y);
                        if (isDamageZoneLogo ||
                            (isCustomDamageZone &&
                                maximumColor <= DamageZoneOverlayDarkThreshold &&
                                !preserveDamageLabelShadow))
                        {
                            ClearPixel(overlayRow, index);
                        }
                        else if (IsBarRegion(x, y))
                        {
                            bool isBarLinePixel = x >= 296 && x < 1504;
                            if (isBarLinePixel && IsBarCenterRow(y) && maximumColor <= PlaceholderBlackThreshold)
                            {
                                overlayRow[index] = 0;
                                overlayRow[index + 1] = 0;
                                overlayRow[index + 2] = 0;
                            }
                            else if (isBarLinePixel && IsBarHaloRow(y) && maximumColor > 0 && maximumColor <= BarShadowMaximum)
                            {
                                overlayRow[index] = 255;
                                overlayRow[index + 1] = 255;
                                overlayRow[index + 2] = 255;
                                overlayRow[index + 3] = (byte)(maximumColor * BarHaloOpacityScale);
                            }
                            else
                            {
                                ClearPixel(overlayRow, index);
                            }
                        }
                        else if (maximumColor <= PlaceholderBlackThreshold &&
                            !HasVisibleNeighbor(templatePixels, templateData.Stride, x, y))
                        {
                            ClearPixel(overlayRow, index);
                        }
                    }
                }
                Marshal.Copy(overlayRow, 0, IntPtr.Add(overlayData.Scan0, y * overlayData.Stride), overlayData.Stride);
            }
            completed = true;
        }
        finally
        {
            try
            {
                if (overlayData != null) overlay.UnlockBits(overlayData);
            }
            finally
            {
                try
                {
                	if (templateData != null) template.UnlockBits(templateData);
                }
                finally
                {
                	if (!completed) overlay.Dispose();
                }
            }
        }
        return overlay;
    }

    private static void ClearPixel(byte[] row, int index)
    {
        row[index] = 0;
        row[index + 1] = 0;
        row[index + 2] = 0;
        row[index + 3] = 0;
    }

    private static bool IsBarRegion(int x, int y)
    {
        if (x < BottomPanel.Left || x >= BottomPanel.Right)
            return false;
        foreach (int centerRow in BarCenterRows)
        {
            if (centerRow - BarShadowRadius <= y && y <= centerRow + 1 + BarShadowRadius)
                return true;
        }
        return false;
    }

    private static bool IsBarCenterRow(int y)
    {
        foreach (int centerRow in BarCenterRows)
        {
            if (y == centerRow || y == centerRow + 1)
                return true;
        }
        return false;
    }

    private static bool IsBarHaloRow(int y)
    {
        foreach (int centerRow in BarCenterRows)
        {
            if (centerRow - BarShadowRadius <= y && y < centerRow ||
                centerRow + 2 <= y && y <= centerRow + 1 + BarShadowRadius)
                return true;
        }
        return false;
    }

    private static bool HasVisibleNeighbor(byte[] pixels, int stride, int x, int y)
    {
        int top = Math.Max(0, y - ShadowNeighborRadius);
        int bottom = Math.Min(CanvasHeight - 1, y + ShadowNeighborRadius);
        int left = Math.Max(0, x - ShadowNeighborRadius);
        int right = Math.Min(CanvasWidth - 1, x + ShadowNeighborRadius);
        for (int neighborY = top; neighborY <= bottom; neighborY++)
        {
            for (int neighborX = left; neighborX <= right; neighborX++)
            {
                if (neighborX == x && neighborY == y)
                    continue;
                int index = neighborY * stride + neighborX * 4;
                if (pixels[index] > PlaceholderBlackThreshold ||
                    pixels[index + 1] > PlaceholderBlackThreshold ||
                    pixels[index + 2] > PlaceholderBlackThreshold)
                    return true;
            }
        }
        return false;
    }

    private static bool IsArtworkRegion(int x, int y, bool includeTopDamageZone, bool includeBottomDamageZone)
    {
        if (TopPanel.Contains(x, y) || BottomPanel.Contains(x, y))
            return true;
        return (includeTopDamageZone && TopDamageZone.Contains(x, y)) ||
            (includeBottomDamageZone && BottomDamageZone.Contains(x, y));
    }

    private static void ValidateTemplate(Bitmap template, string path)
    {
        if (template.Width != CanvasWidth || template.Height != CanvasHeight)
            throw new InvalidOperationException("Template must be 1800x800 pixels: " + path);
        if (template.PixelFormat != PixelFormat.Format32bppArgb)
            throw new InvalidOperationException("Template must be a 32-bit RGBA PNG: " + path);
    }
}
'@
	Add-Type -TypeDefinition $typeDefinition -ReferencedAssemblies 'System.Drawing'
	$builderType = 'FftcgPlaymatBackgroundBuilderV5' -as [type]
}

$stagingDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("FFTCG-PlaymatBackgrounds-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stagingDirectory | Out-Null
try {
	$stagedPaths = @(
		(Join-Path $stagingDirectory "${Name}_1.png"),
		(Join-Path $stagingDirectory "${Name}_2.png")
	)
	for ($index = 0; $index -lt 2; $index++) {
		[FftcgPlaymatBackgroundBuilderV5]::Build(
			$templatePaths[$index],
			$topImagePath,
			$bottomImagePath,
			$topDamageZoneImagePath,
			$bottomDamageZoneImagePath,
			$stagedPaths[$index],
			$ArtworkOpacity
		)
	}

	for ($index = 0; $index -lt 2; $index++) {
		if ((Test-Path -LiteralPath $outputPaths[$index]) -and -not $Force) {
			throw "Output already exists: '$($outputPaths[$index])'. Pass -Force to replace it."
		}
		if ($Force) {
			Copy-Item -LiteralPath $stagedPaths[$index] -Destination $outputPaths[$index] -Force
		}
		else {
			Copy-Item -LiteralPath $stagedPaths[$index] -Destination $outputPaths[$index]
		}
		Write-Output "Created $($outputPaths[$index])"
	}
}
finally {
	if (Test-Path -LiteralPath $stagingDirectory -PathType Container) {
		Remove-Item -LiteralPath $stagingDirectory -Recurse -Force
	}
}
