-- MyLootTraking Slash Commands
-- /mlt command handlers

local _, MLT = ...

----------------------------------------------
-- Initialize Slash Commands
----------------------------------------------
function MLT:InitSlashCommands()
    SLASH_MYLOOTTRAKING1 = "/mlt"
    SLASH_MYLOOTTRAKING2 = "/myloottraking"

    SlashCmdList["MYLOOTTRAKING"] = function(msg)
        MLT:HandleSlashCommand(msg)
    end
end

----------------------------------------------
-- Handle Slash Command
----------------------------------------------
function MLT:HandleSlashCommand(msg)
    local L = self.L
    msg = self:Trim(msg or "")
    local cmd, args = msg:match("^(%S+)%s*(.*)")
    cmd = (cmd or ""):lower()
    args = self:Trim(args or "")

    if cmd == "" or cmd == "help" then
        self:PrintHelp()

    elseif cmd == "add" then
        self:HandleAddCommand(args)

    elseif cmd == "list" then
        self:ToggleMainFrame()

    elseif cmd == "track" then
        self:ToggleMiniTracker()

    elseif cmd == "search" then
        self:ShowSearchFrame(args ~= "" and args or nil)

    elseif cmd == "config" or cmd == "settings" or cmd == "options" then
        self:ToggleConfigFrame()

    elseif cmd == "debugsource" then
        self:DebugSourceInfo()

    elseif cmd == "debug" then
        self:DebugUIFreeze()

    else
        self:Print(format(L["UNKNOWN_COMMAND"], cmd))
        self:PrintHelp()
    end
end

----------------------------------------------
-- Print Help
----------------------------------------------
function MLT:PrintHelp()
    local L = self.L
    self:Print(L["CMD_HELP"])
    self:Print("  " .. L["CMD_ADD"])
    self:Print("  " .. L["CMD_LIST"])
    self:Print("  " .. L["CMD_TRACK"])
    self:Print("  " .. L["CMD_SEARCH"])
    self:Print("  " .. L["CMD_CONFIG"])
end

----------------------------------------------
-- Handle /mlt add [itemID|itemLink]
----------------------------------------------
function MLT:HandleAddCommand(args)
    local L = self.L

    if args == "" then
        self:Print(L["ADD_USAGE"])
        return
    end

    local itemID = self:ExtractItemID(args)
    if not itemID then
        self:Print(format(L["ITEM_NOT_FOUND"], args))
        return
    end

    -- Show the list selection menu
    self:ShowAddToListMenu(itemID)
end
