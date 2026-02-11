-- MyLootTraking Localization: English (default)
local _, MLT = ...
MLT.L = {}
local L = MLT.L

-- General
L["ADDON_NAME"] = "MyLootTraking"
L["ADDON_LOADED"] = "MyLootTraking v%s loaded. Type /mlt for help."
L["ADDON_SHORT"] = "MLT"

-- Slash commands
L["CMD_HELP"] = "Commands:"
L["CMD_ADD"] = "/mlt add [itemID|itemLink] - Add item to current list"
L["CMD_LIST"] = "/mlt list - Open the detailed list window"
L["CMD_TRACK"] = "/mlt track - Toggle the mini-tracker"
L["CMD_SEARCH"] = "/mlt search [name] - Search for an item"
L["CMD_CONFIG"] = "/mlt config - Open settings"

-- Lists
L["LIST"] = "List"
L["LISTS"] = "Lists"
L["NEW_LIST"] = "New List"
L["DELETE_LIST"] = "Delete List"
L["RENAME_LIST"] = "Rename List"
L["LIST_BY_CHARACTER"] = "By Character"
L["LIST_BY_OBJECTIVE"] = "By Objective"
L["LIST_TYPE_CHARACTER"] = "Character List"
L["LIST_TYPE_OBJECTIVE"] = "Objective List"
L["ENTER_LIST_NAME"] = "Enter list name:"
L["LIST_CREATED"] = "List '%s' created."
L["LIST_DELETED"] = "List '%s' deleted."
L["LIST_RENAMED"] = "List renamed to '%s'."
L["CONFIRM_DELETE_LIST"] = "Are you sure you want to delete the list '%s'?"

-- Items
L["ITEM"] = "Item"
L["ITEMS"] = "Items"
L["ADD_ITEM"] = "Add to MyLootTraking"
L["REMOVE_ITEM"] = "Remove Item"
L["ITEM_ADDED"] = "'%s' added to list '%s'."
L["ITEM_REMOVED"] = "'%s' removed from list '%s'."
L["ITEM_ALREADY_IN_LIST"] = "'%s' is already in this list."
L["ITEM_OBTAINED"] = "obtained"
L["ITEM_NOT_OBTAINED"] = "not obtained"
L["MARK_OBTAINED"] = "Mark as Obtained"
L["MARK_NOT_OBTAINED"] = "Mark as Not Obtained"
L["ASSIGNED_TO"] = "Assigned to: %s"
L["ASSIGN_CHARACTER"] = "Assign Character"

-- Sources
L["SOURCE"] = "Source"
L["SOURCE_BOSS"] = "Boss"
L["SOURCE_DUNGEON"] = "Dungeon"
L["SOURCE_RAID"] = "Raid"
L["SOURCE_QUEST"] = "Quest"
L["SOURCE_MOB"] = "Mob"
L["SOURCE_VENDOR"] = "Vendor"
L["SOURCE_CRAFTED"] = "Crafted"
L["SOURCE_PVP"] = "PvP"
L["SOURCE_UNKNOWN"] = "Unknown"
L["DROP_RATE"] = "Drop Rate: %s%%"
L["EDIT_SOURCE"] = "Edit Source"
L["ENTER_SOURCE"] = "Source (Boss - Instance):"

-- Categories
L["CATEGORY_NEEDED"] = "Needed"
L["CATEGORY_OBTAINED"] = "Obtained"
L["SHOW_OBTAINED"] = "Show Obtained"
L["HIDE_OBTAINED"] = "Hide Obtained"

-- Alerts
L["ALERT_ITEM_DROPPED"] = "%s has DROPPED!"
L["ALERT_ITEM_LOOTED"] = "You LOOTED %s!"
L["ALERT_DUNGEON_ENTER"] = "%d item(s) from your lists drop here!"
L["ALERT_CLICK_DETAILS"] = "Click for details"
L["ALERT_GROUP_DROP"] = "Group Drop"
L["ALERT_PERSONAL_LOOT"] = "Personal Loot"

-- Mini Tracker
L["MINI_TRACKER"] = "Mini Tracker"
L["TRACKER_HIDDEN"] = "Mini tracker hidden. /mlt track to show."
L["TRACKER_SHOWN"] = "Mini tracker shown."
L["NO_ITEMS_TRACKED"] = "No items tracked."

-- Statistics
L["STATISTICS"] = "Statistics"
L["BOSS_KILLS"] = "Boss kills: %d"
L["DUNGEON_RUNS"] = "Runs: %d"
L["PROGRESS"] = "%d/%d - %d%%"

-- Config
L["SETTINGS"] = "Settings"
L["GENERAL"] = "General"
L["ALERTS_SETTINGS"] = "Alerts"
L["TRACKER_SETTINGS"] = "Tracker"
L["ENABLE_POPUP"] = "Enable popup alerts"
L["ENABLE_SOUND"] = "Enable sound alerts"
L["GROUP_DROP_SOUND"] = "Group drop sound"
L["PERSONAL_LOOT_SOUND"] = "Personal loot sound"
L["DUNGEON_ENTER_ALERT"] = "Alert on dungeon/raid entry"
L["TRACKER_MAX_ITEMS"] = "Max items in mini-tracker"
L["TRACKER_TRANSPARENCY"] = "Tracker transparency"
L["TRACKER_SCALE"] = "Tracker scale"
L["LOCK_TRACKER"] = "Lock tracker position"
L["LOCK_ALERTS"] = "Lock alert position"

-- Minimap
L["MINIMAP_TOOLTIP_TITLE"] = "MyLootTraking"
L["MINIMAP_TOOLTIP_LEFT"] = "Left-click: Open list"
L["MINIMAP_TOOLTIP_RIGHT"] = "Right-click: Settings"
L["MINIMAP_TOOLTIP_ITEMS"] = "%d item(s) to collect"

-- Search
L["SEARCH"] = "Search"
L["SEARCH_PLACEHOLDER"] = "Enter item name or ID..."
L["NO_RESULTS"] = "No results found."

-- Notes
L["NOTES"] = "Notes"
L["ADD_NOTE"] = "Add Note"
L["EDIT_NOTE"] = "Edit Note"
L["NOTE_PLACEHOLDER"] = "Enter your note here..."

-- Filters
L["FILTER"] = "Filter"
L["FILTER_ALL"] = "All"
L["FILTER_BY_CHARACTER"] = "By Character"
L["FILTER_BY_INSTANCE"] = "By Instance"
L["FILTER_BY_SOURCE"] = "By Source Type"
L["SORT_BY"] = "Sort by"
L["SORT_NAME"] = "Name"
L["SORT_SOURCE"] = "Source"
L["SORT_STATUS"] = "Status"
L["SORT_INSTANCE"] = "Instance"

-- Chat
L["LINK_TO_CHAT"] = "Link to Chat"
L["COPY_TO_CHAT"] = "Copy info to chat"
L["CHAT_FORMAT"] = "Looking for %s - drops from %s in %s"

-- Misc
L["YES"] = "Yes"
L["NO"] = "No"
L["OK"] = "OK"
L["CANCEL"] = "Cancel"
L["CLOSE"] = "Close"
L["SAVE"] = "Save"
L["RESET"] = "Reset"
L["CONFIRM"] = "Confirm"
L["NONE"] = "None"
L["UNKNOWN"] = "Unknown"
L["CHARACTER"] = "Character"
L["PRIORITY"] = "Priority"
L["DRAG_TO_REORDER"] = "Drag to reorder"
L["RESET_CONFIRM"] = "Reset all settings to defaults?"
L["UNKNOWN_COMMAND"] = "Unknown command: %s"
L["ADD_USAGE"] = "Usage: /mlt add [itemID or item link]"
L["ITEM_NOT_FOUND"] = "Could not find item: %s"
L["ADD_ITEM_BY_ID"] = "Add"
L["ENTER_ITEM_ID"] = "Item ID or [item link]:"
L["NO_LIST_SELECTED"] = "Select a list first."
L["WOWHEAD_LINK"] = "Wowhead Lookup"
L["WOWHEAD_URL_TITLE"] = "Copy Wowhead URL (Ctrl+C):"
L["MY_LISTS"] = "My Lists"
L["OTHER_CHARACTERS"] = "Other Characters"

-- Farm Lists
L["LIST_TYPE_FARM"] = "Farm List"
L["LIST_TYPE_CHARACTER_SHORT"] = "Character BiS"
L["LIST_TYPE_FARM_SHORT"] = "Farm List"
L["ENTER_TARGET_QTY"] = "Target quantity:"
L["SET_TARGET_QTY"] = "Set Target Quantity"
L["RESET_COUNT"] = "Reset Count"
L["FARM_PROGRESS"] = "%d/%d"
L["SELECT_LIST_TYPE"] = "Select list type:"
