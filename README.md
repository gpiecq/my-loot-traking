# MyLootTraking - WoW Classic Anniversary Edition Addon

Loot tracking addon for WoW Classic Anniversary Edition (Interface 20505).
Create item wishlists, track your progress and get alerts when your items drop.

## Installation

1. Extract the `MyLootTraking` folder into:
   ```
   World of Warcraft\_anniversary_\Interface\AddOns\MyLootTraking\
   ```
2. Restart the game or type `/reload` in-game
3. The addon will appear in the AddOns list on the character select screen

## Commands

| Command | Action |
|---|---|
| `/mlt` | Show help |
| `/mlt add [itemID\|link]` | Add an item to a list |
| `/mlt list` | Open/close the detailed window |
| `/mlt track` | Show/hide the mini-tracker |
| `/mlt search [name]` | Search for an item |
| `/mlt config` | Open settings |

## Minimap Button

- **Left click**: Open the detailed list
- **Right click**: Open settings
- **Hover**: Number of items to collect + overall progress
- **Drag**: Reposition the button on the minimap

## Features

### Two Types of Lists

**BiS Lists (per character)**
- Create item wishlists for each character
- Auto-tracking: items are marked as "obtained" when you loot them
- Data shared across all characters on the account
- Character class icon shown in the list panel

**Farm Lists**
- Create farm lists with a target quantity (e.g. Rugged Leather x20)
- Auto-counter: syncs with your bag contents in real-time
- Progress updates on every loot or bag change
- Right-click a farm item: edit target quantity or reset counter

### Adding Items

3 ways to add an item to a list:
1. **Command**: `/mlt add 28795` or `/mlt add [item link]`
2. **Tooltip**: `Ctrl + Right-click` on any item (tooltip, chat link, AtlasLoot)
3. **Interface**: "Add" button in the main window or `/mlt search [name]`

### Mini-Tracker

Compact always-visible overlay on the side of the screen:
- Items grouped by list with a clickable header per list
- Click a list name to collapse/expand it
- Click the "MyLootTraking" title to collapse/expand all
- Farm lists: counter (5/20) under each item
- BiS lists: source (Boss - Instance) with difficulty (N)/(H)
- Right-click an item for options (mark obtained, edit, delete...)
- Transparency, scale and position are adjustable and lockable

### Item Sources

- Built-in database of 3,977 items with boss, instance and difficulty
- Difficulty indicator: **(N)** Normal in green, **(H)** Heroic in orange (TBC)
- Boss and instance names translated per locale
- Manual editing via right-click > Edit source
- Wowhead link for items with no known source

### Alerts

- **Group drop**: orange popup + sound when a list item drops in your group
- **Personal loot**: green popup + sound when you loot a list item
- **Dungeon entry**: blue popup when you enter an instance with items to collect
- Queue system: alerts display one at a time (no overlap)
- Positions are draggable and lockable

### Main Window

- Left panel: all your lists with progress
- Right panel: items in the selected list with sorting and filters
- **Filters**: by instance (Karazhan, Gruul's Lair, etc.)
- **Sorting**: by name, source, status, instance or manual order
- Drag and drop to reorder items
- Personal notes and character assignment per item

### Statistics

- Kill count per boss
- Run count per dungeon/raid
- Progress per list: `7/12 - 58%`
- Overall progress in the title bar and minimap tooltip

### Search

- Real-time search interface (`/mlt search`)
- Search by name or item ID in the database (3,977 items)
- Click a result to add it to a list

### Settings

- Enable/disable popup alerts and sounds
- Alert on dungeon/raid entry
- Mini-tracker transparency and scale (max items: 1-30)
- Lock tracker and alert positions
- Show/hide obtained items
- Full settings reset

### Integrations

- **AtlasLoot**: "+" button on each item to add it with context (boss/instance)
- **ElvUI**: compatible, respects ElvUI scale
- **Blizzard Interface**: accessible via Interface > AddOns menu

### Languages

- French (complete), English (complete)
- German (partial), Spanish (partial)
- Korean, Russian, Chinese (Simplified & Traditional), Portuguese (BR) - fallback to English

## File Structure

```
MyLootTraking/
├── MyLootTraking.toc           # Addon config (Interface 20505)
├── Core.lua                     # Initialization, events, BAG_UPDATE
├── Database.lua                 # Data, CRUD, farm lists, bag scanning
├── Utils.lua                    # Utility functions, colors, formatting
├── ItemSources.lua              # Item source database (3,977 items)
├── LootDetection.lua            # Loot detection + quantities + boss kills
├── Statistics.lua               # Kill/run/progress statistics
├── Alerts.lua                   # Popup notifications with queue
├── TooltipHook.lua              # Tooltips + Ctrl+Right-click
├── MinimapButton.lua            # Minimap button
├── MiniTracker.lua              # Mini-tracker grouped by list
├── MainFrame.lua                # Detailed window + filters + sorting
├── SearchFrame.lua              # Search interface
├── ConfigFrame.lua              # Settings panel
├── SlashCommands.lua            # /mlt commands
├── AtlasLootIntegration.lua     # AtlasLoot integration
├── Locales/
│   ├── enUS.lua                 # English (base)
│   ├── frFR.lua                 # French
│   ├── deDE.lua                 # German (partial)
│   ├── esES.lua                 # Spanish (partial)
│   ├── ruRU.lua                 # Russian (stub)
│   ├── koKR.lua                 # Korean (stub)
│   ├── zhCN.lua                 # Chinese Simplified (stub)
│   ├── zhTW.lua                 # Chinese Traditional (stub)
│   └── ptBR.lua                 # Portuguese BR (stub)
└── tools/
    └── parse_atlasloot.ps1      # ItemSources.lua generator
```

## SavedVariables

- `MyLootTrakingDB`: Account-wide shared data (lists, items, stats, config)

## Development

1. Data is stored in `WTF/Account/YOUR_ACCOUNT/SavedVariables/MyLootTraking.lua`
2. `/reload` to reload after changes
3. `/script MyLootTrakingDB = nil; ReloadUI()` for a full reset
4. To regenerate ItemSources.lua: run `tools/parse_atlasloot.ps1` with AtlasLoot data files
