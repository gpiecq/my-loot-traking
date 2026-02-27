# Changelog

All notable changes to MyLootTraking will be documented in this file.

## [1.1.0] - 2026-02-27

### Added
- Full English translation of the README
- 7 new localization keys: `ATLASLOOT_INTEGRATED`, `ADDON_DESCRIPTION`, `OPEN_SETTINGS`, `SOURCE_UPDATED`, `DEFAULT_FARM_NAME`, `CTRL_RIGHT_CLICK`
- French translations for all new keys
- Logo and screenshots (logo/, screens/)

### Fixed
- 10 hardcoded English strings now properly use the localization system (L["KEY"])
  - AtlasLoot integration message
  - Interface Options description and button
  - Source update message in Database
  - Default farm list name
  - Tooltip "Ctrl+Right-Click" hint
  - OK/Cancel buttons in all dialogs (confirm, input, copy)
- Removed unicode emojis from German (deDE) and Spanish (esES) locale files (incompatible with WoW fonts)

### Changed
- README.md rewritten in English and updated to reflect current state
  - Added all 9 locale files to file structure
  - Updated language support section (deDE partial, esES partial, 5 stubs)
  - Added max items slider detail in settings section

## [1.0.2] - 2026-02-17

### Fixed
- Items in the main list could not be clicked in certain conditions

## [1.0.1] - 2026-02-12

### Fixed
- Loot not detected when inside dungeons
- Farm list item count not updating correctly after looting

## [1.0.0] - 2026-02-11

### Added
- **BiS Lists**: Create per-character item wishlists with auto-tracking on loot
- **Farm Lists**: Track farmable items with target quantities, real-time bag sync
- **Item Source Database**: 3,977 items from 59 instances (Classic + TBC) with boss, instance and difficulty (N)/(H)
- **Alerts**: Popup notifications for group drops, personal loot, and dungeon entry with sound and queue system
- **Mini-Tracker**: Compact overlay grouped by list, collapsible, with farm counters and BiS sources
- **Main Window**: Detailed list view with filters (by instance, character, source type), sorting, drag-and-drop reorder, notes and character assignment
- **Search**: Real-time item search by name or ID across the full database
- **Statistics**: Boss kill counts, dungeon/raid run counts, per-list and global progress
- **Minimap Button**: Left-click list, right-click settings, hover for progress, draggable
- **Settings**: Popup/sound toggles, dungeon entry alert, tracker transparency/scale/max items, position locking, full reset
- **AtlasLoot Integration**: "+" button on AtlasLoot items to add with boss/instance context
- **Tooltip Hook**: Ctrl+Right-Click on any item tooltip to add it to a list
- **Slash Commands**: `/mlt`, `/mlt add`, `/mlt list`, `/mlt track`, `/mlt search`, `/mlt config`
- **Localization**: English (complete), French (complete), German (partial), Spanish (partial), 5 stub locales (ruRU, koKR, zhCN, zhTW, ptBR)
- **ElvUI** and **Blizzard Interface Options** compatibility
- Item source auto-generation tool (`tools/parse_atlasloot.ps1`)
