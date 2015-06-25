PLUGIN.Title = "Limited Sleepers"
PLUGIN.Description = "Allows for limited sleepers on a server"
PLUGIN.Author = "Hatemail"
PLUGIN.Version = "1.1.1"
PLUGIN.ConfigVersion = "1.1.0"
PLUGIN.ResourceID = "299"
print("Loading " .. PLUGIN.Title .." V" .. PLUGIN.Version .. "...")
Sleepers = {}
function PLUGIN:Init()
	 self:LoadConfig()
	 self:LoadFlags()
	 self:AddChatCommand("sleepers", self.cmdSleeperConfig)
	 self:AddChatCommand("Sleepers", self.cmdSleeperConfig)
end

function PLUGIN:PostInit()
	self:LoadFlags()
    print(self.Title .." V" .. self.Version .. " loaded correctly")
end

function PLUGIN:HasFlag(netuser, flag)
    if (netuser:CanAdmin()) then
		return true
	end
    if ((self.oxminPlugin ~= nil) and (self.oxminPlugin:HasFlag(netuser, flag))) then
      return true 
	end
    if ((self.flagsPlugin ~= nil) and (self.flagsPlugin:HasFlag(netuser, flag))) then
       return true 
	end
    return false
end

function PLUGIN:LoadFlags()
    self.oxminPlugin = plugins.Find("oxmin")
    if (self.oxminPlugin) then
        self.FLAG_SLEEPERS = oxmin.AddFlag("Sleepers")
        self.oxminPlugin:AddExternalOxminChatCommand(self, "Sleepers", { self.FLAG_SLEEPERS }, self.cmdSleeperConfig)
        self.oxminPlugin:AddExternalOxminChatCommand(self, "sleepers", { self.FLAG_SLEEPERS }, self.cmdSleeperConfig)
    end

    self.flagsPlugin = plugins.Find("flags")
    if (self.flagsPlugin) then
        self.flagsPlugin:AddFlagsChatCommand(self, "Sleepers", { "Sleepers" }, self.cmdSleeperConfig)
        self.flagsPlugin:AddFlagsChatCommand(self, "sleepers", { "Sleepers" }, self.cmdSleeperConfig)
    end
end
function PLUGIN:LoadConfig()
	print("Loading Config File")
	local b, res = config.Read( "Sleepers" )
	self.Config = res or {}
	if (not b) then
		print("Loading Default Sleepers Config...")
		self:LoadDefaultConfig()
		if (res) then config.Save( "Sleepers" ) end
	end
	if ( self.Config.configVersion ~= self.ConfigVersion) then
		print("Out of date Sleepers Config, Updating!")
		self:LoadDefaultConfig()
		config.Save( "Sleepers" )
	end
end
function PLUGIN:LoadDefaultConfig()
	self.Config.configVersion = "1.1.0"
	self.Config.inCombatTime = self.Config.inCombatTime or 60
	self.Config.inCombatKill = self.Config.inCombatKill or false
	self.Config.sleeperTime = self.Config.sleeperTime or 60
	self.Config.sleeperCombatTime = self.Config.sleeperCombatTime or 300
end

function PLUGIN:cmdSleeperConfig(netuser, cmd, args)
	if (type(cmd) == "table") then
		args = cmd
	end
	if (self:HasFlag(netuser,"Sleepers")) then
		if (not args[1]) then
			rust.Notice(netuser, "Syntax: /Sleepers \"Config Value\" ")
			rust.SendChatToUser( netuser,"Sleepers", "/Sleepers inCombatTime value" )
			rust.SendChatToUser( netuser,"Sleepers", "/Sleepers inCombatKill value" )
			rust.SendChatToUser( netuser,"Sleepers", "/Sleepers sleeperTime value" )
			rust.SendChatToUser( netuser,"Sleepers", "/Sleepers sleeperCombatTime value" )
			return
		end
		local targetConfig = args[1]
		for k, v in pairs(self.Config) do 
			if (k == targetConfig) then 
				if (tostring(self.Config[targetConfig]) == "true") then 
					self.Config[targetConfig] = false 
					rust.Notice( netuser, targetConfig .. " Set to: false") 
				else
					if (tostring(self.Config[targetConfig]) == "false") then 
						self.Config[targetConfig] = true 
						rust.Notice( netuser, targetConfig .. " Set to: true") 
					else
						if (args[2] == "configVersion") then
							rust.Notice( netuser, "You are not allowed to change the config version") 
							return
						end
						self.Config[targetConfig] = args[2]
						rust.Notice( netuser, targetConfig .. " Set to: " .. tostring(args[2])) 
					end
				end
				print("Saving Config")
				config.Save( "Sleepers" )
				self:LoadConfig()
				return
			end
		end
		rust.Notice( netuser, "No Config found!") 
	end
end
SleepingAvatarType = cs.gettype( "SleepingAvatar, Assembly-CSharp" )
RemoveSleeper = util.FindOverloadedMethod( SleepingAvatarType, "Close", bf.public_static, { Rust.NetUser._type } )
Sleepers.FindObjectsOfType = util.GetStaticMethod( UnityEngine.Object, "FindObjectsOfType")
NetCullDestroy = util.FindOverloadedMethod( Rust.NetCull._type, "Destroy", bf.public_static, { UnityEngine.GameObject } )
local AwayType = cs.gettype( "RustProto.AwayEvent+Types+AwayEventType, Assembly-CSharp" )
typesystem.LoadEnum(AwayType, "AwayTypeEnum" )

function PLUGIN:OnUserDisconnect( networkplayer)
    local netUser = networkplayer:GetLocalData()
    if (not netUser or netUser:GetType().Name ~= "NetUser") then
		print("Sleeper wasn't removed correctly")
		print("Debug info:")
		print(networkplayer)
		print("End Debug")
        return
    end
	self:RemoveSleepingAvatar(netUser)
end

function PLUGIN:RemoveSleepingAvatar(netUser)
	local userData = self:GetUserData(netUser)
	local sleeperTimeAmount = self.Config.sleeperTime
	if (userData.InCombat) then
		if (self.Config.inCombatKill) then
			Rust.TakeDamage.KillSelf( netUser.playerClient.controllable.idMain, nil )
		end
		sleeperTimeAmount = self.Config.sleeperCombatTime
	end
	if(type(userData.CombatTimer) ~= "table" and userData.CombatTimer:GetType().Name == "Timer") then
		userData.CombatTimer:Destroy()
	end
	userData.Timer = timer.Once(tonumber(sleeperTimeAmount), 
		function()
		local avatar = netUser:LoadAvatar()
	    if ( avatar ) then
	    	if (avatar.HasAwayEvent) then
		        if (tostring(avatar.AwayEvent.Type) == tostring(AwayTypeEnum.SLUMBER)) then
		        	local TransientData = RemoveSleeper:Invoke( nil, util.ArrayFromTable( Rust.NetUser._type, { netUser } ))
					TransientData:AdjustIncomingAvatar( avatar )
					netUser:SaveAvatar( avatar )
		       	end
	        end
	    end
	end )
end

function PLUGIN:OnHurt(takedamage, damage)
	if not (damage:GetType().Name == "DamageEvent") then
		return
	end 
	if not (takedamage ~= nil and takedamage:GetType().Name == "HumanBodyTakeDamage") then
		return
	end
	if (takedamage:GetComponent("HumanController")) then
		if(damage.victim.client and damage.attacker.client) then
			local isSamePlayer = (damage.victim.client == damage.attacker.client)
			if (damage.victim.client.netUser and damage.attacker.client.netUser and not isSamePlayer) then
				self:SetInCombat(damage.victim.client.netUser)
				self:SetInCombat(damage.attacker.client.netUser)
			end
		end
	end
end

function PLUGIN:SetInCombat(netUser)
	local userData = self:GetUserData(netUser)
	local userID = rust.GetUserID(netUser)
	userData.InCombat = true
	userData = self:ClearTimers(userData)
	local combattime = tonumber(self.Config.inCombatTime)
	userData.CombatTimer =  timer.Once(combattime, 
	function() userData.InCombat = false Sleepers[userID] = userData userData.CombatTimer:Destroy() end)
	Sleepers[userID] = userData
end

function PLUGIN:ClearTimers(userData)
	if(type(userData.CombatTimer) ~= "table" and userData.CombatTimer:GetType().Name == "Timer") then
		userData.CombatTimer:Destroy()
	end
	if(type(userData.Timer) ~= "table" and userData.Timer:GetType().Name == "Timer") then
		userData.Timer:Destroy()
	end
	return userData
end

function PLUGIN:OnUserConnect( netuser )
	local userData = self:GetUserData(netuser)
	userData.InCombat = false
	userData = self:ClearTimers(userData)
	Sleepers[rust.GetUserID(netuser)] = userData
end

function PLUGIN:GetUserData( netuser )
	local userID = rust.GetUserID(netuser)
	return self:GetUserDataFromID( userID)
end

function PLUGIN:GetUserDataFromID(userID)
	local userData = Sleepers[userID]
	if (not userData) then
		userData = {}
		userData.InCombat = false
		userData.CombatTimer = {}
		userData.Timer = {}
		Sleepers[userID] = userData
	end
	return userData
end