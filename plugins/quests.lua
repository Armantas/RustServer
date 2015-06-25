PLUGIN.Title = "Quests"
PLUGIN.Description = "Basic Quest Plugin"
PLUGIN.Author = "greyhawk"
PLUGIN.Version = "0.2.2"

function PLUGIN:Init()
    econ_mod = plugins.Find("econ")
    
    if (not econ_mod) then
        self.econ = false
    else
        self.econ = true
    end
    
    self.autojoin = true

	-- self.DataFile = util.GetDatafile( "quests" )
	-- local txt = self.DataFile:GetText()
	-- if (txt ~= "") then
		-- self.Quests = json.decode( txt )
	-- else
		self.Quests = {}
	-- end
    
    self.Zombies = {}
    self:addZombieQuest("Zombies25", "25", "Anti-Radiation Pills", "5")
    self:addZombieQuest("Zombies50", "50", "Sulfur", "75")
    self:addZombieQuest("Zombies50", "50", "Metal Fragments", "75")
    self:addZombieQuest("Zombies100", "100", "P250", "1")
    self:addZombieQuest("Zombies125", "125", "MP5A4", "1")
    self:addZombieQuest("Zombies150", "150", "M4", "1")
    self:addZombieQuest("Zombies200", "200", "Bolt Action Rifle", "1")
    self:addZombieQuest("Zombies250", "250", "Explosive Charge", "2")
    -- self:addZombieQuest("So Many Zombies", "200", "Supply Signal", "1")
    -- if (self.econ) then
        -- local questname = "ZombiesMoney"
        -- local killcount = "10"
        -- local rewardcount = "50"
        -- table.insert(self.Zombies, questname)
        -- self:addQuest( questname,
                    -- "kill " .. killcount .. " zombies to get ".. rewardcount .. econ_mod.CurrencySymbol,
                    -- (function(x) return (x >= tonumber(killcount)) end),
                    -- (function(user) econ_mod:giveMoneyTo(user, tonumber(rewardcount)) end)
                    -- )
        
    -- end

	self:AddChatCommand("quest", self.cmdQuest)
    self:AddChatCommand("qhelp", self.cmdQhelp)
end

function PLUGIN:addZombieQuest(questname, killcount, questreward, rewardcount)
    table.insert(self.Zombies, questname)
    self:addQuest( questname,
                    "kill " .. killcount .. " zombies to get ".. rewardcount .. " " .. questreward,
                    (function(x) return (x >= tonumber(killcount)) end),
                    (function(user) rust.RunServerCommand("inv.giveplayer \"" .. util.QuoteSafe( user.displayName ) .. "\" \"" .. questreward .. "\" " .. rewardcount ) end)
                    )
end

function PLUGIN:addQuest(idString, description, objective, reward)
    local userentry = self.Quests[ idString ]
	if (not userentry) then
		userentry = {}
		userentry.ID = idString
		userentry.Desc = description
        userentry.Objective = objective
        userentry.Reward = reward
        userentry.Players = {}
		self.Quests[ idString ] = userentry
        --self:Save()
	end
end

function PLUGIN:addPlayerToQuest(netuser, idString)
    local userentry = self.Quests[ idString ]
	if (not userentry) then
        rust.Notice( netuser, "No quest found with name " .. idString .. " !" )
        return false
    end
    local userID = rust.GetUserID( netuser )
    local player = {}
    player.ID = userID
    player.Name = netuser.displayName
    player.Value = nil
    self.Quests[idString].Players[userID] = player
    return true
end

-- function PLUGIN:Save()
	-- self.DataFile:SetText( json.encode( self.Quests ) )
	-- self.DataFile:Save()
-- end

function PLUGIN:cmdQuest( netuser, cmd, args )
    if (not(args[1])) then
        return
    end
    
    if (args[1] == "list") then
        rust.SendChatToUser( netuser, "Available Quests:" )
        for key,value in pairs(self.Quests) do
            rust.SendChatToUser( netuser, util.QuoteSafe(value.ID) .. ": " .. util.QuoteSafe(value.Desc) )
        end
        return
    end
    
    if (args[1] == "done") then
        local userID = rust.GetUserID( netuser )
        for key,value in pairs(self.Quests) do
            if ((value.Players[userID]) and (value.Players[userID].Value)) then
                if (value.Objective(value.Players[userID].Value)) then
                    value.Reward(netuser)
                    rust.SendChatToUser( netuser, "Completed quest " .. util.QuoteSafe(value.ID) )
                    value.Players[userID] = nil
                else
                    rust.SendChatToUser( netuser, "Status of " .. util.QuoteSafe(value.ID) .. ": " .. tostring(value.Players[userID].Value) )
                end
            else
                rust.SendChatToUser( netuser, "Status of " .. util.QuoteSafe(value.ID) .. ": not joined")
            end
        end
        return
    end
    
    if ((args[1] == "join") and (args[2])) then
        if (self:addPlayerToQuest(netuser, args[2])) then
            rust.SendChatToUser( netuser, "Joined quest " .. util.QuoteSafe(args[2]) )
            return
        else
            rust.Notice( netuser, "/quest join error!" )
        end
        return
    end
    
    rust.Notice( netuser, "/quest error!" )

end

function PLUGIN:OnKilled (takedamage, dmg)
    if (takedamage:GetComponent( "ZombieController" )) then
        local player = dmg.attacker.client.netUser
        local userID = rust.GetUserID( player )
        
        for key,value in pairs(self.Zombies) do
            local quest = self.Quests[value]
            if (quest.Players[userID]) then
                if (not(quest.Players[userID].Value)) then
                    quest.Players[userID].Value = 0
                end
                quest.Players[userID].Value = quest.Players[userID].Value + 1
                if (quest.Objective(quest.Players[userID].Value)) then
                    rust.SendChatToUser( player, "Completed quest " .. util.QuoteSafe(quest.ID) )
                    quest.Reward(player)
                    quest.Players[userID] = nil
                else
                    rust.SendChatToUser( player, "Status of " .. util.QuoteSafe(quest.ID) .. ": " .. tostring(quest.Players[userID].Value) )
                end
            end
        end
    end
end

function PLUGIN:SendHelpText( netuser )
    rust.SendChatToUser( netuser, "Use /qhelp to show Quests commands" )
end

function PLUGIN:cmdQhelp( netuser )
    rust.SendChatToUser( netuser, "--------------------------------------------------------------------------------" )
    rust.SendChatToUser( netuser, "------------------- Greyhawk's Quests Plugin -------------------------" )
    rust.SendChatToUser( netuser, "Use /quest list to list available quests" )
    rust.SendChatToUser( netuser, "Use /quest join name to join a quest" )
    rust.SendChatToUser( netuser, "Use /quest done to check completed quests" )
    rust.SendChatToUser( netuser, "--------------------------------------------------------------------------------" )
end

-- economy interaction : load economy.txt, find user, give user, save economy.txt

-- REWARDS : money, items

















