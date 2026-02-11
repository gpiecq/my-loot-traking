"""
Parse AtlasLootClassic data-tbc.lua and generate ItemSources.lua
Extracts: itemID -> { bossName, instanceName }
"""
import re
import os

INPUT_FILE = os.path.join(os.path.dirname(__file__), '..', 'data-tbc.lua')
OUTPUT_FILE = os.path.join(os.path.dirname(__file__), '..', 'ItemSources.lua')

# Readable instance names (from AtlasLoot internal keys)
INSTANCE_NAMES = {
    "HellfireRamparts": "Hellfire Ramparts",
    "TheBloodFurnace": "The Blood Furnace",
    "TheShatteredHalls": "The Shattered Halls",
    "Mana-Tombs": "Mana-Tombs",
    "AuchenaiCrypts": "Auchenai Crypts",
    "SethekkHalls": "Sethekk Halls",
    "ShadowLabyrinth": "Shadow Labyrinth",
    "TheSlavePens": "The Slave Pens",
    "TheUnderbog": "The Underbog",
    "TheSteamvault": "The Steamvault",
    "OldHillsbradFoothills": "Old Hillsbrad Foothills",
    "TheBlackMorass": "The Black Morass",
    "TheArcatraz": "The Arcatraz",
    "TheBotanica": "The Botanica",
    "TheMechanar": "The Mechanar",
    "MagistersTerrace": "Magisters' Terrace",
    "Karazhan": "Karazhan",
    "ZulAman": "Zul'Aman",
    "WorldBossesBC": "World Bosses",
    "MagtheridonsLair": "Magtheridon's Lair",
    "GruulsLair": "Gruul's Lair",
    "SerpentshrineCavern": "Serpentshrine Cavern",
    "TempestKeep": "Tempest Keep",
    "HyjalSummit": "Hyjal Summit",
    "BlackTemple": "Black Temple",
    "SunwellPlateau": "Sunwell Plateau",
}

def parse_file(filepath):
    """Parse the data-tbc.lua file and extract item -> source mappings."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    items = {}  # itemID -> (bossName, instanceName)

    current_instance = None
    current_boss = None

    # Pattern for instance declaration: data["InstanceName"] = {
    instance_pat = re.compile(r'^data\["([^"]+)"\]\s*=\s*\{')

    # Pattern for boss name: name = AL["Boss Name"],
    boss_pat = re.compile(r'name\s*=\s*AL\["([^"]+)"\]')

    # Pattern for formatted boss name: name = format(NAME_SOMETHING, AL["Boss Name"])
    boss_format_pat = re.compile(r'name\s*=\s*format\([^,]+,\s*AL\["([^"]+)"\]\)')

    # Pattern for item entry: { number, itemID }, -- Item Name
    item_pat = re.compile(r'\{\s*\d+\s*,\s*(\d+)\s*\}')

    # Pattern for item with alliance/horde variant: { number, itemID, [ATLASLOOT_IT_ALLIANCE] = itemID2 }
    item_variant_pat = re.compile(r'\{\s*\d+\s*,\s*(\d+)\s*,\s*\[ATLASLOOT_IT_(?:ALLIANCE|HORDE)\]\s*=\s*(\d+)\s*\}')

    # Skip patterns (not real items)
    skip_pat = re.compile(r'"INV_|"Interface|SET_ITTYPE|QUEST_EXTRA|PRICE_EXTRA|AtlasLoot:')

    for line in content.split('\n'):
        stripped = line.strip()

        # Check for instance declaration
        m = instance_pat.match(stripped)
        if m:
            key = m.group(1)
            current_instance = INSTANCE_NAMES.get(key, key)
            current_boss = None
            continue

        if not current_instance:
            continue

        # Check for boss name
        m = boss_format_pat.search(stripped)
        if not m:
            m = boss_pat.search(stripped)
        if m:
            current_boss = m.group(1)
            continue

        if not current_boss:
            continue

        # Skip non-item lines
        if skip_pat.search(stripped):
            continue

        # Check for item with variant
        m = item_variant_pat.search(stripped)
        if m:
            item_id = int(m.group(1))
            variant_id = int(m.group(2))
            if item_id > 1000:
                items.setdefault(item_id, (current_boss, current_instance))
            if variant_id > 1000:
                items.setdefault(variant_id, (current_boss, current_instance))
            continue

        # Check for regular item
        m = item_pat.search(stripped)
        if m:
            item_id = int(m.group(1))
            if item_id > 1000:  # Skip slot-only entries
                items.setdefault(item_id, (current_boss, current_instance))

    return items


def generate_lua(items, output_path):
    """Generate ItemSources.lua from parsed items."""

    # Group by instance for readability
    by_instance = {}
    for item_id, (boss, instance) in sorted(items.items()):
        by_instance.setdefault(instance, []).append((item_id, boss))

    lines = []
    lines.append("-- MyLootTraking Item Sources Database")
    lines.append("-- Auto-generated from AtlasLootClassic data")
    lines.append("-- Format: [itemID] = { \"Boss Name\", \"Instance Name\" },")
    lines.append("")
    lines.append("local _, MLT = ...")
    lines.append("")
    lines.append("MLT.ItemSourceData = {")

    for instance in sorted(by_instance.keys()):
        entries = by_instance[instance]
        lines.append("")
        lines.append(f"    -- {instance}")
        for item_id, boss in sorted(entries):
            # Escape quotes in names
            safe_boss = boss.replace('"', '\\"')
            safe_inst = instance.replace('"', '\\"')
            lines.append(f'    [{item_id}] = {{ "{safe_boss}", "{safe_inst}" }},')

    lines.append("}")
    lines.append("")

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    return len(items)


if __name__ == '__main__':
    print(f"Parsing {INPUT_FILE}...")
    items = parse_file(INPUT_FILE)
    print(f"Found {len(items)} unique items")

    count = generate_lua(items, OUTPUT_FILE)
    print(f"Generated {OUTPUT_FILE} with {count} entries")

    # Show some stats
    instances = set(inst for _, inst in items.values())
    bosses = set(boss for boss, _ in items.values())
    print(f"Instances: {len(instances)}, Bosses: {len(bosses)}")
