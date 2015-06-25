PLUGIN.Title = "Ripper"
PLUGIN.Version = "0.1.3"
PLUGIN.Description = "Kill or slay one or all players on command."
PLUGIN.Author = "Luke Spragg - Wulfspider"
PLUGIN.Url = "http://forum.rustoxide.com/resources/410/"
PLUGIN.ConfigFile = "ripper"
PLUGIN.ResourceId = "410"

local debug = false -- Used to enable debug messages

-- TODO:
---- Add ccmdKill console command
---- Add radius based command option
---- Add option for explosion on kill?

-- Plugin initialization
function PLUGIN:Init()
    self:LoadConfiguration()
    self:SetupPermissions()
    print(self.Title .. " v" .. self.Version .. " loaded!")
end

-- Kill chat command
function PLUGIN:cmdKill(netuser, cmd, arg)
    -- Check if user has permission
    if (not self:PermissionsCheck(netuser)) then
        -- Send no permission message to user via notice
        rust.Notice(netuser, self.Config.Messages.NoPermission)
        return
    else
        local targetuser = arg[1]

        -- Check for valid argument
        if (targetuser == nil)  then
            -- Display proper command usage
            rust.Notice(netuser, self.Config.Messages.HelpText)
            return
        end

        -- All players targeted
        if (targetuser == "all") then
            -- Debug messages
            if (debug) then error("Target: " .. tostring(targetuser)) end
            -- Kill all players
            local targetusers = rust.GetAllNetUsers()
            for key, targetuser in pairs(targetusers) do
                -- Play vomit sound on client if enabled
                if (self.Config.Settings.VomitSound ~= "false") then
                    self:VomitSound(targetuser)
                end
                -- Kill individual user
                Rust.TakeDamage.KillSelf(targetuser.playerClient.controllable.idMain, nil)
                -- Send killed by message to user
                self:SendMessages(netuser, targetuser)
                -- Debug messages
                if (debug) then error("Killed: " .. targetuser.displayName) end
            end
        -- Individual user targeted
        else
            -- Get the target user by name
            local b, targetuser = rust.FindNetUsersByName(targetuser)
            if (not b) then 
                -- Check if player name exists
                if (targetuser == 0) then
                    rust.Notice(netuser, self.Config.Messages.NoPlayersFound)
                -- Check for multiple name matches
                elseif (targetuser > 1) then
                    rust.Notice(netuser, self.Config.Messages.MultiplePlayers)
                end
                return
            end
            -- Debug messages
            if (debug) then error("Target: " .. tostring(targetuser.displayName)) end
            -- Trigger vomiting sound if enabled
            if (self.Config.Settings.VomitSound ~= "false") then
                self:VomitSound(targetuser)
            end
            -- Kill individual user
            Rust.TakeDamage.KillSelf(targetuser.playerClient.controllable.idMain, nil)
            -- Send killed by message to user
            self:SendMessages(netuser, targetuser)
            -- Debug messages
            if (debug) then error("Killed: " .. targetuser.displayName) end
        end
    end
end

-- Vomit sound function
function PLUGIN:VomitSound(targetuser)
    local controllable = targetuser.playerClient.controllable:GetComponent("Metabolism")
    local args = cs.newarray(System.Object._type, 0)
    -- Trigger vomiting sound
    controllable.networkView:RPC("Vomit", controllable.networkView.owner, args);
end

-- Send messages to user
function PLUGIN:SendMessages(netuser, targetuser)
    --- Check if notices are enabled
    if (self.Config.Settings.NoticeEnabled ~= "false") then
        -- Notify user of death
        rust.Notice(targetuser, self.Config.Messages.KilledBy .. " " .. netuser.displayName)
    end

    --- Check if chat messages are enabled
    if (self.Config.Settings.ChatEnabled ~= "false") then
        -- Notify user of death
        rust.SendChatToUser(targetuser, self.Config.Settings.ChatName, self.Config.Messages.KilledBy .. " " .. util.QuoteSafe(netuser.displayName))
    end
end

-- Callable help text
function PLUGIN:SendHelpText(netuser)
    -- Check if user has permission
    if (self:PermissionsCheck(netuser)) then
        -- Send help text to user via chat
        rust.SendChatToUser(netuser, self.Config.Settings.HelpChatName, self.Config.Messages.HelpText)
    end
end

-- Load the configuration
function PLUGIN:LoadConfiguration()
    -- Read/create configuration file
    local b, res = config.Read(self.ConfigFile)
    self.Config = res or {}

    -- General settings
    self.Config.Settings = self.Config.Settings or {}
    self.Config.Settings.ChatName = self.Config.Settings.ChatName or "Server"
    self.Config.Settings.HelpChatName = self.Config.Settings.HelpChatName or self.Config.Settings.ChatNameHelp or "Help"
    self.Config.Settings.ChatEnabled = self.Config.Settings.ChatEnabled or "true"
    self.Config.Settings.NoticeEnabled = self.Config.Settings.NoticeEnabled or self.Config.Settings.NoticesEnabled or "true"
    self.Config.Settings.VomitSound = self.Config.Settings.VomitSound or "true"

    -- Message strings
    self.Config.Messages = self.Config.Messages or {}
    self.Config.Messages.HelpText = self.Config.Messages.HelpText or "Use /kill \"playername\" or all to kill player(s)"
    self.Config.Messages.InvalidPlayerName = self.Config.Messages.InvalidPlayerName or "You must enter a valid player name"
    self.Config.Messages.KilledBy = self.Config.Messages.KilledBy or "You have been killed by"
    self.Config.Messages.MultiplePlayersFound = self.Config.Messages.MultiplePlayersFound or "Multiple players found with that name"
    self.Config.Messages.NoPermission = self.Config.Messages.NoPermission or "You do not have permission to use this command!"
    self.Config.Messages.NoPlayersFound = self.Config.Messages.NoPlayersFound or "No players found with that name"

    -- Remove old settings
    self.Config.Settings.ChatNameHelp = nil -- Removed in 0.1.2
    self.Config.Settings.NoticesEnabled = nil -- Removed in 0.1.3

    -- Save configuration
    config.Save(self.ConfigFile)
end

-- Check for permissions to use commands
function PLUGIN:PermissionsCheck(netuser)
    -- Check if user is RCON admin
    if (netuser:CanAdmin()) then
        if (debug) then error(netuser.displayName .. " is RCON admin") end -- Debug message
        return true -- User is RCON admin
    -- Check if user has Oxmin plugin flag assigned
    elseif ((self.oxmin ~= nil) and (self.oxmin:HasFlag(netuser, self.FLAG_CANKILL))) then
        if (debug) then error(netuser.displayName .. " has Oxmin flag: cankill") end -- Debug message
        return true -- User has flag assigned
    -- Check if user has Flags plugin flag assigned
    elseif ((self.flags ~= nil) and (self.flags:HasFlag(netuser, "cankill"))) then
        if (debug) then error(netuser.displayName .. " has Flags flag: cankill") end -- Debug message
        return true -- User has flag assigned
    else
        return false -- User has no permission
    end
end

-- Setup plugin commands and flags
function PLUGIN:SetupPermissions()
    -- Find optional Oxmin plugin
    self.oxmin = plugins.Find("oxmin")
    -- Check if Oxmin is installed
    if (self.oxmin) then
        -- Add Oxmin plugin commands
        self.FLAG_CANKILL = oxmin.AddFlag("cankill")
        self.oxmin:AddExternalOxminChatCommand(self, "kill", {self.FLAG_CANKILL}, self.cmdKill)
        self.oxmin:AddExternalOxminChatCommand(self, "slay", {self.FLAG_CANKILL}, self.cmdKill)
    end

    -- Find optional Flags plugin
    self.flags = plugins.Find("flags")
    -- Check if Flags is installed
    if (self.flags) then
        -- Add Flags plugin commands
        self.flags:AddFlagsChatCommand(self, "kill", {"cankill"}, self.cmdKill)
        self.flags:AddFlagsChatCommand(self, "slay", {"cankill"}, self.cmdKill)
    end

    -- Add default chat commands
    self:AddChatCommand("kill", self.cmdKill)
    self:AddChatCommand("slay", self.cmdKill)
end
