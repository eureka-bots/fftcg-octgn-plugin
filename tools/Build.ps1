[CmdletBinding()]
param(
	[string]$BuilderPath,
	[string]$Language = 'en',
	[switch]$ValidateOnly,
	[switch]$Install,
	[switch]$StageOnly
)

$ErrorActionPreference = 'Stop'

if ($ValidateOnly -and $Install) {
	throw 'Choose either -ValidateOnly or -Install, not both.'
}
if ($StageOnly -and ($ValidateOnly -or $Install)) {
	throw '-StageOnly cannot be combined with -ValidateOnly or -Install.'
}
if ($Language -notmatch '^[a-z]{2}(?:-[A-Z]{2})?$') {
	throw "Invalid language code '$Language'. Use a language code such as 'en' or 'ja-JP'."
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$localizationRoot = Join-Path $repositoryRoot 'localization'
$setDataRoot = Join-Path (Join-Path $localizationRoot 'sets') $Language
$menuMapPath = Join-Path $localizationRoot 'definition-menu-map.json'
$dynamicMapPath = Join-Path $localizationRoot 'dynamic-label-map.json'
$promptMapPath = Join-Path $localizationRoot 'dynamic-prompt-map.json'
$valueMapPath = Join-Path $localizationRoot 'dynamic-value-map.json'
$messageMapPath = Join-Path $localizationRoot 'user-message-map.json'
$catalogPath = Join-Path $localizationRoot "$Language.json"
if (-not (Test-Path -LiteralPath $menuMapPath -PathType Leaf)) {
	throw "Definition menu map not found: '$menuMapPath'."
}
if (-not (Test-Path -LiteralPath $dynamicMapPath -PathType Leaf)) {
	throw "Dynamic label map not found: '$dynamicMapPath'."
}
if (-not (Test-Path -LiteralPath $promptMapPath -PathType Leaf)) {
	throw "Dynamic prompt map not found: '$promptMapPath'."
}
if (-not (Test-Path -LiteralPath $valueMapPath -PathType Leaf)) {
	throw "Dynamic value map not found: '$valueMapPath'."
}
if (-not (Test-Path -LiteralPath $messageMapPath -PathType Leaf)) {
	throw "User message map not found: '$messageMapPath'."
}
if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
	throw "Localization catalog for '$Language' not found: '$catalogPath'."
}

$menuMapJson = Get-Content -LiteralPath $menuMapPath -Raw | ConvertFrom-Json
$dynamicMapJson = Get-Content -LiteralPath $dynamicMapPath -Raw | ConvertFrom-Json
$promptMapJson = Get-Content -LiteralPath $promptMapPath -Raw | ConvertFrom-Json
$valueMapJson = Get-Content -LiteralPath $valueMapPath -Raw | ConvertFrom-Json
$messageMapJson = Get-Content -LiteralPath $messageMapPath -Raw | ConvertFrom-Json
$catalogJson = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$menuKeysBySource = @{}
foreach ($property in $menuMapJson.PSObject.Properties) {
	$menuKeysBySource[$property.Name] = [string]$property.Value
}
$dynamicKeysByMarker = @{}
foreach ($property in $dynamicMapJson.PSObject.Properties) {
	$dynamicKeysByMarker[$property.Name] = [string]$property.Value
}
$promptKeysByMarker = @{}
foreach ($property in $promptMapJson.PSObject.Properties) {
	$promptKeysByMarker[$property.Name] = [string]$property.Value
}
$valueKeysByMarker = @{}
foreach ($property in $valueMapJson.PSObject.Properties) {
	$valueKeysByMarker[$property.Name] = [string]$property.Value
}
$messageKeysBySource = @{}
foreach ($property in $messageMapJson.PSObject.Properties) {
	$messageKeysBySource[$property.Name] = [string]$property.Value
}
$translationsByKey = @{}
foreach ($property in $catalogJson.PSObject.Properties) {
	$translationsByKey[$property.Name] = [string]$property.Value
}
if ($menuKeysBySource.Count -eq 0) {
	throw "Definition menu map is empty: '$menuMapPath'."
}
if ($dynamicKeysByMarker.Count -eq 0) {
	throw "Dynamic label map is empty: '$dynamicMapPath'."
}
if ($promptKeysByMarker.Count -eq 0) {
	throw "Dynamic prompt map is empty: '$promptMapPath'."
}
if ($valueKeysByMarker.Count -eq 0) {
	throw "Dynamic value map is empty: '$valueMapPath'."
}
if ($messageKeysBySource.Count -eq 0) {
	throw "User message map is empty: '$messageMapPath'."
}
foreach ($translationKey in (@($menuKeysBySource.Values) + @($dynamicKeysByMarker.Values) + @($promptKeysByMarker.Values) + @($valueKeysByMarker.Values) + @($messageKeysBySource.Values))) {
	if (-not $translationsByKey.ContainsKey($translationKey) -or [string]::IsNullOrWhiteSpace($translationsByKey[$translationKey])) {
		throw "Localization catalog '$catalogPath' has no non-empty translation for '$translationKey'."
	}
}

$gameDirectories = @(Get-ChildItem -LiteralPath $repositoryRoot -Directory | Where-Object {
	Test-Path -LiteralPath (Join-Path $_.FullName 'definition.xml') -PathType Leaf
})
if ($gameDirectories.Count -ne 1) {
	throw "Expected exactly one OCTGN game directory under '$repositoryRoot'; found $($gameDirectories.Count)."
}

$gameSource = $gameDirectories[0].FullName
$definitionPath = Join-Path $gameSource 'definition.xml'
[xml]$definition = Get-Content -LiteralPath $definitionPath -Raw
$gameId = [guid]::Empty
if (-not [guid]::TryParse($definition.game.id, [ref]$gameId)) {
	throw "The game ID in '$definitionPath' is not a valid UUID."
}
$gameId = $gameId.ToString()

$setSourceRoot = Join-Path $repositoryRoot 'sets'
if (-not (Test-Path -LiteralPath $setSourceRoot -PathType Container)) {
	throw "Set source directory not found: '$setSourceRoot'."
}
$setDirectories = @(Get-ChildItem -LiteralPath $setSourceRoot -Directory)
if ($setDirectories.Count -eq 0) {
	throw "No set source directories found under '$setSourceRoot'."
}

$setIds = @{}
$setSources = @()
foreach ($setDirectory in $setDirectories) {
	$setFile = Join-Path $setDirectory.FullName 'set.xml'
	if (-not (Test-Path -LiteralPath $setFile -PathType Leaf)) {
		throw "Missing set.xml in '$($setDirectory.FullName)'."
	}

	[xml]$set = Get-Content -LiteralPath $setFile -Raw
	$setId = [guid]::Empty
	if (-not [guid]::TryParse($set.set.id, [ref]$setId)) {
		throw "Invalid set UUID '$($set.set.id)' in '$setFile'."
	}
	$setId = $setId.ToString()

	$setGameId = [guid]::Empty
	if (-not [guid]::TryParse($set.set.gameId, [ref]$setGameId) -or $setGameId.ToString() -ne $gameId) {
		throw "Set '$($set.set.GetAttribute('name'))' has a missing or mismatched game ID in '$setFile'."
	}
	if ($setIds.ContainsKey($setId)) {
		throw "Duplicate set UUID '$setId' in '$($setIds[$setId])' and '$($setDirectory.FullName)'."
	}

	$setIds[$setId] = $setDirectory.FullName
	$setSources += [pscustomobject]@{
		Id = $setId
		Name = $set.set.GetAttribute('name')
		Path = $setDirectory.FullName
	}
}

if ([string]::IsNullOrWhiteSpace($env:TEMP)) {
	throw 'The TEMP environment variable is not set; cannot create a build staging directory.'
}
$stagePath = Join-Path $env:TEMP ("FFTCG-OCTGN-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stagePath | Out-Null

try {
	foreach ($item in Get-ChildItem -LiteralPath $gameSource -Force) {
		if ($item.Name -ne 'Sets') {
			Copy-Item -LiteralPath $item.FullName -Destination $stagePath -Recurse -Force
		}
	}

	$stagedShowRulesPath = Join-Path $stagePath 'scripts\script_showRules.py'
	if (-not (Test-Path -LiteralPath $stagedShowRulesPath -PathType Leaf)) {
		throw "Dynamic label script not found in staging: '$stagedShowRulesPath'."
	}
	$stagedShowRulesText = [System.IO.File]::ReadAllText($stagedShowRulesPath)
	$localizedDynamicLabelCount = 0
	foreach ($marker in $dynamicKeysByMarker.Keys) {
		$quotedMarker = '"' + $marker + '"'
		$markerCount = [System.Text.RegularExpressions.Regex]::Matches($stagedShowRulesText, [System.Text.RegularExpressions.Regex]::Escape($quotedMarker)).Count
		if ($markerCount -eq 0) {
			throw "Dynamic label marker '$marker' was not found in '$stagedShowRulesPath'."
		}
		$translationKey = $dynamicKeysByMarker[$marker]
		$pythonUnicodeLiteral = 'u' + (ConvertTo-Json -InputObject $translationsByKey[$translationKey] -Compress)
		$stagedShowRulesText = $stagedShowRulesText.Replace($quotedMarker, $pythonUnicodeLiteral)
		$localizedDynamicLabelCount += $markerCount
	}
	if ($stagedShowRulesText -match '__L10N_DYNAMIC_[A-Z0-9_]+__') {
		throw "Untranslated dynamic label marker remains in '$stagedShowRulesPath'."
	}
	[System.IO.File]::WriteAllText($stagedShowRulesPath, $stagedShowRulesText, (New-Object System.Text.UTF8Encoding($false)))

	$stagedCardLogicPath = Join-Path $stagePath 'scripts\script_cardLogic.py'
	if (-not (Test-Path -LiteralPath $stagedCardLogicPath -PathType Leaf)) {
		throw "Dynamic prompt script not found in staging: '$stagedCardLogicPath'."
	}
	$stagedCardLogicText = [System.IO.File]::ReadAllText($stagedCardLogicPath)
	$localizedPromptCount = 0
	foreach ($marker in $promptKeysByMarker.Keys) {
		$quotedMarker = '"' + $marker + '"'
		$markerCount = [System.Text.RegularExpressions.Regex]::Matches($stagedCardLogicText, [System.Text.RegularExpressions.Regex]::Escape($quotedMarker)).Count
		if ($markerCount -eq 0) {
			throw "Dynamic prompt marker '$marker' was not found in '$stagedCardLogicPath'."
		}
		$translationKey = $promptKeysByMarker[$marker]
		$pythonUnicodeLiteral = 'u' + (ConvertTo-Json -InputObject $translationsByKey[$translationKey] -Compress)
		$stagedCardLogicText = $stagedCardLogicText.Replace($quotedMarker, $pythonUnicodeLiteral)
		$localizedPromptCount += $markerCount
	}
	if ($stagedCardLogicText -match '__L10N_PROMPT_[A-Z0-9_]+__') {
		throw "Untranslated dynamic prompt marker remains in '$stagedCardLogicPath'."
	}
	[System.IO.File]::WriteAllText($stagedCardLogicPath, $stagedCardLogicText, (New-Object System.Text.UTF8Encoding($false)))

	$valueScriptNames = @('script_cardLogic.py', 'script_gameLogic.py')
	$localizedDynamicValueCount = 0
	$stagedValueScripts = @{}
	foreach ($valueScriptName in $valueScriptNames) {
		$stagedValueScriptPath = Join-Path (Join-Path $stagePath 'scripts') $valueScriptName
		if (-not (Test-Path -LiteralPath $stagedValueScriptPath -PathType Leaf)) {
			throw "Dynamic value script not found in staging: '$stagedValueScriptPath'."
		}
		$stagedValueScripts[$valueScriptName] = [System.IO.File]::ReadAllText($stagedValueScriptPath)
	}
	foreach ($marker in $valueKeysByMarker.Keys) {
		$quotedMarker = '"' + $marker + '"'
		$markerFound = $false
		$translationKey = $valueKeysByMarker[$marker]
		$pythonUnicodeLiteral = 'u' + (ConvertTo-Json -InputObject $translationsByKey[$translationKey] -Compress)
		foreach ($valueScriptName in $valueScriptNames) {
			$stagedValueScriptText = $stagedValueScripts[$valueScriptName]
			$markerCount = [System.Text.RegularExpressions.Regex]::Matches($stagedValueScriptText, [System.Text.RegularExpressions.Regex]::Escape($quotedMarker)).Count
			if ($markerCount -eq 0) {
				continue
			}
			$stagedValueScriptText = $stagedValueScriptText.Replace($quotedMarker, $pythonUnicodeLiteral)
			$stagedValueScripts[$valueScriptName] = $stagedValueScriptText
			$localizedDynamicValueCount += $markerCount
			$markerFound = $true
		}
		if (-not $markerFound) {
			throw "Dynamic value marker '$marker' was not found in any staged value script."
		}
	}
	foreach ($valueScriptName in $valueScriptNames) {
		$stagedValueScriptPath = Join-Path (Join-Path $stagePath 'scripts') $valueScriptName
		[System.IO.File]::WriteAllText($stagedValueScriptPath, $stagedValueScripts[$valueScriptName], (New-Object System.Text.UTF8Encoding($false)))
	}

	$messageScriptNames = @('script_cardLogic.py', 'script_gameLogic.py', 'script_powerLogic.py')
	$localizedMessageCount = 0
	foreach ($messageScriptName in $messageScriptNames) {
		$stagedMessageScriptPath = Join-Path (Join-Path $stagePath 'scripts') $messageScriptName
		if (-not (Test-Path -LiteralPath $stagedMessageScriptPath -PathType Leaf)) {
			throw "User message script not found in staging: '$stagedMessageScriptPath'."
		}
		$stagedMessageScriptText = [System.IO.File]::ReadAllText($stagedMessageScriptPath)
		foreach ($sourceMessage in $messageKeysBySource.Keys) {
			$quotedSourceMessage = '"' + $sourceMessage + '"'
			$messageCount = [System.Text.RegularExpressions.Regex]::Matches($stagedMessageScriptText, [System.Text.RegularExpressions.Regex]::Escape($quotedSourceMessage)).Count
			if ($messageCount -gt 0) {
				$translationKey = $messageKeysBySource[$sourceMessage]
				$pythonUnicodeLiteral = 'u' + (ConvertTo-Json -InputObject $translationsByKey[$translationKey] -Compress)
				$stagedMessageScriptText = $stagedMessageScriptText.Replace($quotedSourceMessage, $pythonUnicodeLiteral)
				$localizedMessageCount += $messageCount
			}
		}
		[System.IO.File]::WriteAllText($stagedMessageScriptPath, $stagedMessageScriptText, (New-Object System.Text.UTF8Encoding($false)))
	}
	foreach ($sourceMessage in $messageKeysBySource.Keys) {
		$sourceMessageFound = $false
		foreach ($messageScriptName in $messageScriptNames) {
			$sourceMessagePath = Join-Path (Join-Path $gameSource 'scripts') $messageScriptName
			$sourceMessageText = [System.IO.File]::ReadAllText($sourceMessagePath)
			if ($sourceMessageText.Contains('"' + $sourceMessage + '"')) {
				$sourceMessageFound = $true
				break
			}
		}
		if (-not $sourceMessageFound) {
			throw "User message source text '$sourceMessage' was not found in the mapped scripts."
		}
	}

	$stagedDefinitionPath = Join-Path $stagePath 'definition.xml'
	$stagedDefinition = New-Object System.Xml.XmlDocument
	$stagedDefinition.PreserveWhitespace = $true
	$stagedDefinition.Load($stagedDefinitionPath)
	$stagedDefinitionText = [System.IO.File]::ReadAllText($stagedDefinitionPath)
	$localizedMenuCount = @{}
	foreach ($menuKey in $menuKeysBySource.Keys) {
		$localizedMenuCount[$menuKey] = 0
	}
	$unmappedMenuLabels = @{}
	$replacements = @()
	$menuAttributeMatches = [System.Text.RegularExpressions.Regex]::Matches(
		$stagedDefinitionText,
		'\bmenu\s*=\s*"(?<value>[^"]*)"'
	)
	foreach ($menuAttributeMatch in $menuAttributeMatches) {
		$sourceMenu = [System.Net.WebUtility]::HtmlDecode($menuAttributeMatch.Groups['value'].Value)
		if ($menuKeysBySource.ContainsKey($sourceMenu)) {
			$menuKey = $menuKeysBySource[$sourceMenu]
			if ($translationsByKey[$menuKey] -ne $sourceMenu) {
				$replacements += [pscustomobject]@{
					Index = $menuAttributeMatch.Groups['value'].Index
					Length = $menuAttributeMatch.Groups['value'].Length
					Value = [System.Security.SecurityElement]::Escape($translationsByKey[$menuKey])
				}
			}
			$localizedMenuCount[$sourceMenu]++
		}
		else {
			$unmappedMenuLabels[$sourceMenu] = $true
		}
	}
	foreach ($sourceMenu in $localizedMenuCount.Keys) {
		if ($localizedMenuCount[$sourceMenu] -eq 0) {
			throw "Definition menu map source label '$sourceMenu' was not found in '$stagedDefinitionPath'."
		}
	}
	if ($unmappedMenuLabels.Count -gt 0) {
		throw "Definition menu map is missing labels: $($unmappedMenuLabels.Keys -join ', ')."
	}

	foreach ($replacement in ($replacements | Sort-Object Index -Descending)) {
		$stagedDefinitionText = $stagedDefinitionText.Remove($replacement.Index, $replacement.Length).Insert($replacement.Index, $replacement.Value)
	}
	$stagedDefinition.LoadXml($stagedDefinitionText)
	[System.IO.File]::WriteAllText($stagedDefinitionPath, $stagedDefinitionText, (New-Object System.Text.UTF8Encoding($true)))

	$stagedSetsPath = Join-Path $stagePath 'Sets'
	New-Item -ItemType Directory -Path $stagedSetsPath | Out-Null
	$localizedSetCardCount = 0
	foreach ($setSource in $setSources) {
		$stagedSetPath = Join-Path $stagedSetsPath $setSource.Id
		New-Item -ItemType Directory -Path $stagedSetPath | Out-Null
		foreach ($item in Get-ChildItem -LiteralPath $setSource.Path -Force) {
			if ($item.Name -ne 'Cards' -or $setSource.Name -eq 'Debug') {
				Copy-Item -LiteralPath $item.FullName -Destination $stagedSetPath -Recurse
			}
		}

		if ($Language -ne 'en') {
			$setDataFileName = (Split-Path -Leaf $setSource.Path) + '.json'
			$setDataPath = Join-Path $setDataRoot $setDataFileName
			if (Test-Path -LiteralPath $setDataPath -PathType Leaf) {
				$localizedSetDataJson = Get-Content -LiteralPath $setDataPath -Raw | ConvertFrom-Json
				$localizedSetRecords = @{}
				foreach ($property in $localizedSetDataJson.PSObject.Properties) {
					$localizedSetRecords[$property.Name] = $property.Value
				}
				if ($localizedSetRecords.Count -eq 0) {
					throw "Set localization data is empty: '$setDataPath'."
				}

				$stagedSetXmlPath = Join-Path $stagedSetPath 'set.xml'
				$stagedSetXml = New-Object System.Xml.XmlDocument
				$stagedSetXml.PreserveWhitespace = $true
				$stagedSetXml.Load($stagedSetXmlPath)
				$usedSetNumbers = @{}
				$setCards = $stagedSetXml.SelectNodes('/set/cards/card')
				foreach ($card in $setCards) {
					$setNumberProperty = $card.SelectSingleNode("property[@name='SetNumber']")
					if ($null -eq $setNumberProperty) {
						throw "Card '$($card.GetAttribute('name'))' has no SetNumber in '$stagedSetXmlPath'."
					}
					$setNumber = $setNumberProperty.GetAttribute('value')
					if ([string]::IsNullOrWhiteSpace($setNumber) -or $usedSetNumbers.ContainsKey($setNumber)) {
						throw "Set '$($setSource.Name)' has an empty or duplicate SetNumber '$setNumber'."
					}
					if (-not $localizedSetRecords.ContainsKey($setNumber)) {
						throw "Set localization data '$setDataPath' has no entry for card '$setNumber'."
					}
					$usedSetNumbers[$setNumber] = $true

					$localizedCard = $localizedSetRecords[$setNumber]
					foreach ($requiredField in @('name', 'job', 'abilities', 'specialAbilities')) {
						if ($null -eq $localizedCard.PSObject.Properties[$requiredField]) {
							throw "Set localization data '$setDataPath' has no '$requiredField' value for card '$setNumber'."
						}
					}
					$nameProperty = $card.SelectSingleNode("property[@name='InternalName']")
					if ($null -eq $nameProperty) {
						$nameProperty = $stagedSetXml.CreateElement('property')
						$nameProperty.SetAttribute('name', 'InternalName')
						$card.AppendChild($nameProperty) | Out-Null
					}
					$nameProperty.SetAttribute('value', $card.GetAttribute('name'))
					$card.SetAttribute('name', [string]$localizedCard.name)

					$jobProperty = $card.SelectSingleNode("property[@name='Job']")
					if ($null -eq $jobProperty) {
						throw "Card '$setNumber' has no Job property in '$stagedSetXmlPath'."
					}
					$internalJobProperty = $card.SelectSingleNode("property[@name='InternalJob']")
					if ($null -eq $internalJobProperty) {
						$internalJobProperty = $stagedSetXml.CreateElement('property')
						$internalJobProperty.SetAttribute('name', 'InternalJob')
						$card.AppendChild($internalJobProperty) | Out-Null
					}
					$internalJobProperty.SetAttribute('value', $jobProperty.GetAttribute('value'))
					$jobProperty.SetAttribute('value', [string]$localizedCard.job)

					$abilitiesProperty = $card.SelectSingleNode("property[@name='Abilities']")
					$specialAbilitiesProperty = $card.SelectSingleNode("property[@name='SpecialAbilities']")
					if ($null -eq $abilitiesProperty -or $null -eq $specialAbilitiesProperty) {
						throw "Card '$setNumber' is missing an ability property in '$stagedSetXmlPath'."
					}
					$abilitiesText = [string]$localizedCard.abilities
					if ($abilitiesText.StartsWith('EX BURST')) {
						$abilitiesProperty.InnerXml = '<s value="EXBurst">EX BURST</s>' + [System.Security.SecurityElement]::Escape($abilitiesText.Substring(8))
					}
					else {
						$abilitiesProperty.InnerText = $abilitiesText
					}
					$specialAbilitiesProperty.InnerText = [string]$localizedCard.specialAbilities
					$localizedSetCardCount++
				}
				$unusedSetNumbers = @($localizedSetRecords.Keys | Where-Object { -not $usedSetNumbers.ContainsKey($_) })
				if ($unusedSetNumbers.Count -gt 0) {
					throw "Set localization data '$setDataPath' contains unknown card numbers: $($unusedSetNumbers -join ', ')."
				}
				[System.IO.File]::WriteAllText($stagedSetXmlPath, $stagedSetXml.OuterXml, (New-Object System.Text.UTF8Encoding($true)))
			}
		}

		$stagedCardsPath = Join-Path $stagedSetPath 'Cards'
		if ($setSource.Name -eq 'Debug') {
			$stagedProxyPath = Join-Path $stagedCardsPath 'Proxies'
			if (Test-Path -LiteralPath $stagedProxyPath -PathType Container) {
				foreach ($proxyImage in Get-ChildItem -LiteralPath $stagedProxyPath -File -Recurse) {
					$stagedImagePath = Join-Path $stagedCardsPath $proxyImage.Name
					if (Test-Path -LiteralPath $stagedImagePath) {
						throw "Debug proxy image '$($proxyImage.Name)' conflicts with a Cards image."
					}
					Copy-Item -LiteralPath $proxyImage.FullName -Destination $stagedImagePath
				}
				Remove-Item -LiteralPath $stagedProxyPath -Recurse -Force
			}
		}
		if (-not (Test-Path -LiteralPath $stagedCardsPath -PathType Container)) {
			New-Item -ItemType Directory -Path $stagedCardsPath | Out-Null
		}
	}

	Write-Host "Applied '$Language' localization to $($localizedMenuCount.Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum) definition menu labels, $localizedDynamicLabelCount dynamic label values, $localizedPromptCount prompt values, $localizedDynamicValueCount dynamic message values, $localizedMessageCount player-facing message strings, and $localizedSetCardCount set cards."
	Write-Host "Staged $($setSources.Count) sets for game $gameId at:"
	Write-Host $stagePath
	foreach ($setSource in ($setSources | Sort-Object Name)) {
		Write-Host ("  {0} -> Sets\{1}" -f $setSource.Name, $setSource.Id)
	}

	if ($StageOnly) {
		Write-Host 'Staging only; the OCTGN builder was not run.'
		return
	}

	if ([string]::IsNullOrWhiteSpace($BuilderPath)) {
		if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
			throw 'Set -BuilderPath to o8build.exe; LOCALAPPDATA is not set.'
		}
		$BuilderPath = Join-Path $env:LOCALAPPDATA 'Programs\OCTGN\o8build.exe'
	}
	if (-not (Test-Path -LiteralPath $BuilderPath -PathType Leaf)) {
		throw "OCTGN builder not found at '$BuilderPath'. The staged game is preserved at '$stagePath'. Specify -BuilderPath."
	}

	$builderArguments = @('-d', $stagePath)
	if ($ValidateOnly) {
		$builderArguments += '-v'
	}
	elseif ($Install) {
		$builderArguments += '-i'
	}

	Write-Host "Running o8build.exe $($builderArguments -join ' ')"
	& $BuilderPath @builderArguments
	if ($LASTEXITCODE -ne 0) {
		throw "o8build.exe exited with code $LASTEXITCODE. The staged game is preserved at '$stagePath'."
	}

	$packages = @(Get-ChildItem -LiteralPath $stagePath -Filter '*.nupkg' -File -Recurse)
	if ($packages.Count -gt 0) {
		Write-Host 'Built package(s):'
		$packages | ForEach-Object { Write-Host $_.FullName }
	}
	else {
		Write-Host "Build completed. Inspect the output and artifacts under '$stagePath'."
	}
}
catch {
	if (Test-Path -LiteralPath $stagePath -PathType Container) {
		Write-Host "Staging directory preserved at: $stagePath"
	}
	throw
}
