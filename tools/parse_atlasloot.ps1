$inputFiles = @(
    (Join-Path $PSScriptRoot "..\data-classic.lua"),
    (Join-Path $PSScriptRoot "..\data-tbc.lua")
)
$outputFile = Join-Path $PSScriptRoot "..\ItemSources.lua"

$instanceNames = @{
    # Classic Dungeons
    "Ragefire" = "Ragefire Chasm"
    "WailingCaverns" = "Wailing Caverns"
    "TheDeadmines" = "The Deadmines"
    "ShadowfangKeep" = "Shadowfang Keep"
    "BlackfathomDeeps" = "Blackfathom Deeps"
    "TheStockade" = "The Stockade"
    "Gnomeregan" = "Gnomeregan"
    "RazorfenKraul" = "Razorfen Kraul"
    "ScarletMonasteryGraveyard" = "SM: Graveyard"
    "ScarletMonasteryLibrary" = "SM: Library"
    "ScarletMonasteryArmory" = "SM: Armory"
    "ScarletMonasteryCathedral" = "SM: Cathedral"
    "RazorfenDowns" = "Razorfen Downs"
    "Uldaman" = "Uldaman"
    "Zul'Farrak" = "Zul'Farrak"
    "Maraudon" = "Maraudon"
    "TheTempleOfAtal'Hakkar" = "Sunken Temple"
    "BlackrockDepths" = "Blackrock Depths"
    "LowerBlackrockSpire" = "Lower Blackrock Spire"
    "UpperBlackrockSpire" = "Upper Blackrock Spire"
    "DireMaulEast" = "Dire Maul East"
    "DireMaulWest" = "Dire Maul West"
    "DireMaulNorth" = "Dire Maul North"
    "Scholomance" = "Scholomance"
    "Stratholme" = "Stratholme"
    # Classic Raids
    "WorldBosses" = "World Bosses"
    "MoltenCore" = "Molten Core"
    "Onyxia" = "Onyxia's Lair"
    "Zul'Gurub" = "Zul'Gurub"
    "BlackwingLair" = "Blackwing Lair"
    "TheRuinsofAhnQiraj" = "Ruins of Ahn'Qiraj"
    "TheTempleofAhnQiraj" = "Temple of Ahn'Qiraj"
    "Naxxramas" = "Naxxramas"
    # TBC Dungeons
    "HellfireRamparts" = "Hellfire Ramparts"
    "TheBloodFurnace" = "The Blood Furnace"
    "TheShatteredHalls" = "The Shattered Halls"
    "Mana-Tombs" = "Mana-Tombs"
    "AuchenaiCrypts" = "Auchenai Crypts"
    "SethekkHalls" = "Sethekk Halls"
    "ShadowLabyrinth" = "Shadow Labyrinth"
    "TheSlavePens" = "The Slave Pens"
    "TheUnderbog" = "The Underbog"
    "TheSteamvault" = "The Steamvault"
    "OldHillsbradFoothills" = "Old Hillsbrad Foothills"
    "TheBlackMorass" = "The Black Morass"
    "TheArcatraz" = "The Arcatraz"
    "TheBotanica" = "The Botanica"
    "TheMechanar" = "The Mechanar"
    "MagistersTerrace" = "Magisters' Terrace"
    # TBC Raids
    "Karazhan" = "Karazhan"
    "ZulAman" = "Zul'Aman"
    "WorldBossesBC" = "World Bosses (TBC)"
    "MagtheridonsLair" = "Magtheridon's Lair"
    "GruulsLair" = "Gruul's Lair"
    "SerpentshrineCavern" = "Serpentshrine Cavern"
    "TempestKeep" = "Tempest Keep"
    "HyjalSummit" = "Hyjal Summit"
    "BlackTemple" = "Black Temple"
    "SunwellPlateau" = "Sunwell Plateau"
}

$items = @{}

foreach ($inputFile in $inputFiles) {
    if (-not (Test-Path $inputFile)) {
        Write-Host "Skipping $inputFile (not found)"
        continue
    }
    Write-Host "Parsing $inputFile..."
    $content = Get-Content $inputFile -Raw -Encoding UTF8
    $lines = $content -split "`n"

    # Only track difficulty for TBC data (Classic has NORMAL_DIFF but no heroic)
    $isTBC = $inputFile -like "*tbc*"

    $currentInstance = $null
    $currentBoss = $null
    $currentDifficulty = $null
    $braceDepth = 0
    $diffBraceDepth = -1

    foreach ($line in $lines) {
        $stripped = $line.Trim()

        # Instance declaration: data["InstanceName"] = {
        if ($stripped -match '^data\["([^"]+)"\]\s*=\s*\{') {
            $key = $Matches[1]
            if ($instanceNames.ContainsKey($key)) {
                $currentInstance = $instanceNames[$key]
            } else {
                $currentInstance = $key
            }
            $currentBoss = $null
            $currentDifficulty = $null
            $braceDepth = 0
            $diffBraceDepth = -1
            continue
        }

        if (-not $currentInstance) { continue }

        # Track brace depth for difficulty scoping
        $openBraces = ([regex]::Matches($stripped, '\{')).Count
        $closeBraces = ([regex]::Matches($stripped, '\}')).Count
        $braceDepth += $openBraces - $closeBraces

        # If we drop below the difficulty brace level, reset difficulty
        if ($diffBraceDepth -ge 0 -and $braceDepth -le $diffBraceDepth) {
            $currentDifficulty = $null
            $diffBraceDepth = -1
        }

        # Detect difficulty block: [NORMAL_DIFF] = { or [HEROIC_DIFF] = {
        # Only meaningful for TBC (Classic has NORMAL_DIFF but no heroic)
        if ($isTBC) {
            if ($stripped -match '\[NORMAL_DIFF\]\s*=\s*\{') {
                $currentDifficulty = "N"
                $diffBraceDepth = $braceDepth - 1
                continue
            }
            if ($stripped -match '\[HEROIC_DIFF\]\s*=\s*\{') {
                $currentDifficulty = "H"
                $diffBraceDepth = $braceDepth - 1
                continue
            }
        }

        # Boss name: name = AL["Boss Name"] or name = format(..., AL["Boss Name"])
        if ($stripped -match 'name\s*=\s*format\([^,]+,\s*AL\["([^"]+)"\]\)') {
            $currentBoss = $Matches[1]
            $currentDifficulty = $null
            $diffBraceDepth = -1
            continue
        }
        if ($stripped -match 'name\s*=\s*AL\["([^"]+)"\]') {
            $currentBoss = $Matches[1]
            $currentDifficulty = $null
            $diffBraceDepth = -1
            continue
        }

        if (-not $currentBoss) { continue }

        # Skip non-item lines
        if ($stripped -match '"INV_|"Interface|SET_ITTYPE|QUEST_EXTRA|PRICE_EXTRA|AtlasLoot:|IgnoreAsSource|ExtraList') {
            continue
        }

        # Item with variant: { N, itemID, [ATLASLOOT_IT_ALLIANCE] = itemID2 }
        if ($stripped -match '\{\s*\d+\s*,\s*(\d+)\s*,\s*\[ATLASLOOT_IT_(?:ALLIANCE|HORDE)\]\s*=\s*(\d+)') {
            $id1 = [int]$Matches[1]
            $id2 = [int]$Matches[2]
            if ($id1 -gt 1000 -and -not $items.ContainsKey($id1)) {
                $items[$id1] = @($currentBoss, $currentInstance, $currentDifficulty)
            }
            if ($id2 -gt 1000 -and -not $items.ContainsKey($id2)) {
                $items[$id2] = @($currentBoss, $currentInstance, $currentDifficulty)
            }
            continue
        }

        # Regular item: { N, itemID }
        if ($stripped -match '\{\s*\d+\s*,\s*(\d+)\s*\}') {
            $id = [int]$Matches[1]
            if ($id -gt 1000 -and -not $items.ContainsKey($id)) {
                $items[$id] = @($currentBoss, $currentInstance, $currentDifficulty)
            }
        }
    }
}

# Group by instance
$byInstance = @{}
foreach ($kv in $items.GetEnumerator()) {
    $inst = $kv.Value[1]
    if (-not $byInstance.ContainsKey($inst)) {
        $byInstance[$inst] = [System.Collections.ArrayList]::new()
    }
    $byInstance[$inst].Add(@($kv.Key, $kv.Value[0], $kv.Value[2])) | Out-Null
}

# Count items with difficulty
$withDiff = 0
foreach ($kv in $items.GetEnumerator()) {
    if ($kv.Value[2]) { $withDiff++ }
}

# Generate Lua
$output = [System.Collections.ArrayList]::new()
$output.Add("-- MyLootTraking Item Sources Database") | Out-Null
$output.Add("-- Auto-generated from AtlasLootClassic data (Classic + TBC)") | Out-Null
$output.Add("-- Total: $($items.Count) items from $($byInstance.Count) instances ($withDiff with difficulty)") | Out-Null
$output.Add("-- Difficulty: N = Normal, H = Heroic, nil = no difficulty (Classic)") | Out-Null
$output.Add("-- Re-generate: powershell -File tools\parse_atlasloot.ps1") | Out-Null
$output.Add("") | Out-Null
$output.Add("local _, MLT = ...") | Out-Null
$output.Add("") | Out-Null
$output.Add("MLT.ItemSourceData = {") | Out-Null

foreach ($inst in ($byInstance.Keys | Sort-Object)) {
    $entries = $byInstance[$inst]
    $sorted = $entries | Sort-Object { $_[0] }
    $output.Add("") | Out-Null
    $output.Add("    -- $inst") | Out-Null
    foreach ($entry in $sorted) {
        $itemId = $entry[0]
        $boss = $entry[1] -replace '"', '\"'
        $instName = $inst -replace '"', '\"'
        $diff = $entry[2]
        if ($diff) {
            $output.Add("    [$itemId] = { `"$boss`", `"$instName`", `"$diff`" },") | Out-Null
        } else {
            $output.Add("    [$itemId] = { `"$boss`", `"$instName`" },") | Out-Null
        }
    }
}

$output.Add("}") | Out-Null
$output.Add("") | Out-Null

# Write without BOM
[System.IO.File]::WriteAllText($outputFile, ($output -join "`n"), [System.Text.UTF8Encoding]::new($false))

Write-Host "Generated $outputFile with $($items.Count) items from $($byInstance.Count) instances ($withDiff with difficulty)"
