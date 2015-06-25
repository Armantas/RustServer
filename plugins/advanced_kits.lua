PLUGIN.Author="Fox Junior"
PLUGIN.Title="Advanced Kits"
PLUGIN.ResourceId=200
PLUGIN.Version="2.0"
PLUGIN.Description="Manage players starter and common kits"
print("Loading " .. PLUGIN.Title .. " " .. PLUGIN.Version)

function PLUGIN:ParseMessage(message, parameters)
	if ( not(parameters) ) then
		return message
	end
	local _rv = message
	for _key, _value in pairs(parameters) do
		_rv = string.gsub(_rv , "%%" .. _key .."%%", tostring(_value))
	end
	return _rv
end

function PLUGIN:AutoKit(netuser)
	local _inv = rust.GetInventory(netuser)
	local _rock_removed = false
	local _redeem = false
	local _user_id = rust.GetUserID( netuser )
	local _now = util.GetTime()
	if ( self.AutoKitCooldown and self.AutoKitCooldown > 0) then
		_now = util.GetTime()
	end
	if ( not(self.RedeemedAutoKit[_user_id]) ) then
		self.RedeemedAutoKit[_user_id] = { last_time = 0, kits = {}}
	end
	if (self.WelcomeKit and (not(self.AutoKitCooldown) or self.AutoKitCooldown <= 0 or _now - self.RedeemedAutoKit[_user_id].last_time >  self.AutoKitCooldown)) then
		local _redemables = {} -- if random is enabled
		for _index, _kit in pairs(self.WelcomeKit) do
			if ( self:CanRedeem( netuser, _kit ) ) then
				if ( self.RandomWelcomeKit ) then
					local _sindex = "a" .. tostring(_index)
					if ( _kit.cooldown or not(self.RedeemedAutoKit[_user_id].kits[_sindex]) or _now - self.RedeemedAutoKit[_user_id].kits[_sindex] >  self.AutoKitCooldown) then
						table.insert(_redemables, { _sindex, _kit })
					end
				else
					_rock_removed, _redeem = self:AutoKitRedeem( netuser, _inv, _kit, _rock_removed )
					if ( _redeem ) then
						return
					end
				end
			end
		end
		if ( #_redemables > 0 ) then -- add random
			local _len = #_redemables
			local _random = math.random( 1, _len )
			local _kit_index = _redemables[_random][1]
			local _kit_val = _redemables[_random][2]
			self.RedeemedAutoKit[_user_id].kits[_kit_index] = _now
			self.RedeemedAutoKit[_user_id].last_time = _now
			_rock_removed, _redeem = self:AutoKitRedeem( netuser, _inv,_kit_val, _rock_removed )
			if ( _redeem ) then
				return
			end
		end
	end
	if ( not(_rock_removed) and self.RemoveRock ) then
		for _index, _name in pairs( self.RemoveRock ) do
			local _db_name = rust.GetDatablockByName(_name)
			if ( _inv:FindItem(_db_name) ) then
				self:DoRemoveItemByName(netuser, _inv, "Rock")
				return
			end
		end
	end
end

function PLUGIN:CleanKitStats(netuser, _username)
	if (_username ~= "") then
		local _b, _netuser = api.Call("fj_users_wrapper", "FindSingleUser",  netuser, _username)
		if (_b and _netuser) then
			local _user_id = rust.GetUserID( _netuser )
			if (_user_id) then
				local _user_name = util.QuoteSafe(_netuser.displayName)
				self.UserKits[_user_id] = {}
				self:Save()
				rust.SendChatToUser( netuser, "User " .. _user_name .. " kit statistics cleaned")
				return
			end
		end
	else
		self.UserKits = {}
		self:Save()
		rust.SendChatToUser( netuser, "All users kit statistics cleaned")
	end
end

function PLUGIN:AutoKitRedeem( netuser, inv, kit, rock_removed )
	local redeem = false 
	if (kit.remove_rock and not (rock_removed)) then
		self:DoRemoveItemByName(netuser, inv, "Rock")
		rock_removed = true
	end
	if ( kit["remove"] ) then
		for _, _name in pairs (kit["remove"]) do
			self:DoRemoveItemByName(netuser, inv, _name)
		end
	end
	if ( kit.items ) then
		self:Redeem(netuser, kit.items, false, inv )
		redeem = true
	end
	return rock_removed, redeem
end

function PLUGIN:Reload( netuser )
	self:LoadConfiguraion()
	local _broacastPlugin = nil
	if( api.Exists( "broadcast" )) then
		_broacastPlugin = plugins.Find("broadcast")
		if( _broacastPlugin ) then
			_broacastPlugin:RemoveExternalMessage("advanced_kits")
		end
	end
	if ( self.Messages.broadcast ) then
		if( _broacastPlugin ) then
			_broacastPlugin:AddExternalMessage( "advanced_kits", self.Messages.broadcast  , { chatname = self.ChatName } )
		end
	end
	rust.SendChatToUser( netuser, self.ChatName, "Advanced kits configuration reloaded" )
end

function PLUGIN:Redeem(netuser, items, notice, inventory)
	for __, _kit in pairs(items) do
		local _invPref = nil
		if (_kit.target) then
			if (_kit.target == "belt") then
				_invPref = rust.InventorySlotPreference( InventorySlotKind.Belt, false, InventorySlotKindFlags.Belt )
			elseif (_kit.target == "ammo") then
				_invPref = rust.InventorySlotPreference( InventorySlotKind.Default, true, InventorySlotKindFlags.Belt )
			elseif (_kit.target == "helmet") then
				_invPref = rust.InventorySlotPreference( InventorySlotKind.Armor, false, InventorySlotKindFlags.Armor )
			elseif (_kit.target == "vest") then
				_invPref = rust.InventorySlotPreference( InventorySlotKind.Armor, false, InventorySlotKindFlags.Armor )
			elseif (_kit.target == "pants") then
				_invPref = rust.InventorySlotPreference( InventorySlotKind.Armor, false, InventorySlotKindFlags.Armor )
			elseif (_kit.target == "boots") then
				_invPref = rust.InventorySlotPreference( InventorySlotKind.Armor, false, InventorySlotKindFlags.Armor )
			end
		end
		if not (_invPref) then
			_invPref = rust.InventorySlotPreference(InventorySlotKind.Default, true, InventorySlotKindFlags.Belt)
		end
		local _item = rust.GetDatablockByName( _kit.item )
		inventory:AddItemAmount( _item, _kit.amount, _invPref )
		if (notice) then
			rust.InventoryNotice(netuser,  _kit.amount .. " x " .. _kit.item )
		end
	end
end

function PLUGIN:CanRedeem(netuser, kit, userId, kitName)
	local _b, _rv = api.Call("fj_flags_wrapper", "HasFlag", netuser, "deathmatch", userId  )
	if ( _b and _rv ) then
		return false, false
	end
	local _inv = rust.GetInventory(netuser)
	if (kit.disabled_when) then
		for _, _name in pairs (kit.disabled_when) do
			local _db_name = rust.GetDatablockByName(_name)
			if ( not (_db_name) ) then
				print (self.Title .. " Configuration error! " .. _name .. " not found!")
			elseif ( _inv:FindItem(_db_name) ) then
				return false, false
			end
		end
	end
	if ( kit.flags and (( kit.flags.get and #kit.flags.get > 0 ) or ( kit.flags.give and #kit.flags.give > 0 ))) then
		local _get = false
		local _give = false
		if ( kit.flags.get ) then
			local _b, _rv = api.Call("fj_flags_wrapper", "HasFlag", netuser, kit.flags.get)
			_get = _b and _rv
		end
		if ( kit.flags.give ) then
			local _b, _rv = api.Call("fj_flags_wrapper", "HasFlag", netuser, kit.flags.give)
			_give = _b and _rv
		end
		if ( _get and kit.max and kit.max > 0 and userId and kitName and self.UserKits[userId] and  self.UserKits[userId] and  self.UserKits[userId][kitName] and self.UserKits[userId][kitName].amount and self.UserKits[userId][kitName].amount >= kit.max ) then
			_get = false
		end
		if ( _get and kit.cooldown and kit.cooldown > 0 and userId and kitName and self.UserKits[userId] and  self.UserKits[userId] and  self.UserKits[userId][kitName] and self.UserKits[userId][kitName].when ) then
		 	local _now = util.GetTime()
			if (_now > 61) then -- bug at oxide
				local _remain = self.UserKits[userId][kitName].when + (kit.cooldown * 60) - _now
				if (_remain > 0 ) then
					_get = false
				end
			end
		end
		return _get, _give
	end
	if ( kit.admin and not(netuser:CanAdmin()) ) then
		return false, false
	end
	if ( kit.max and kit.max > 0 and userId and kitName and self.UserKits[userId] and  self.UserKits[userId] and  self.UserKits[userId][kitName] and self.UserKits[userId][kitName].amount and self.UserKits[userId][kitName].amount >= kit.max ) then
		return false, false
	end
	if ( kit.cooldown and kit.cooldown > 0 and userId and kitName and self.UserKits[userId] and  self.UserKits[userId] and  self.UserKits[userId][kitName] and self.UserKits[userId][kitName].when ) then
		 local _now = util.GetTime()
		if (_now > 61) then -- bug at oxide
			local _remain = self.UserKits[userId][kitName].when + (kit.cooldown * 60) - _now
			if (_remain > 0 ) then
				return false, false
			end
		end
	end

	return true, false
end

function PLUGIN:LoadConfiguraion()
	self.Columns = nil
	local _dataFile = util.GetDatafile( "cfg_advanced_kits" )
	local _txt = _dataFile:GetText()
	local _result = nil
	local _default_command = "kit"
	local _default_messages = {
		githelp = "Get your kits! Type /" .. _default_command .. " to get started",
		nokitdefined = "No kit available!",
		redeem = "Kit %kit% redeemed!",
		given = "Kit %kit% given to %user%!",
		received = "Buff! %user% gave you a %kit%!",
		cooldown = "You have to wait %min% minutes and %sec%s seconds for %kit% to be available!",
		exceeded = "Already redeemed %kit% maximum %amount% times!",
		nogiveyourself = "You cannot give %kit% yourself!",
		broadcast = "Get your kits! Type /" .. _default_command .. " to get started",
		nokit = "You must have been exhausted all your kits! Please wait for cooldown."
	}
	local _default_kits = {
		starter = { max = 5, cooldown = 1, description = "Basic things you need! (maximum 5 times)",
			items = { "Stone Hatchet", {item = "Cooked Chicken Breast", amount = 3 } } },
		basic = { max = 2, cooldown = 1, description = "Gives you some comfort (maximum 2 times)!",
			items = { "Wood Shelter", "Cloth Pants", "Wooden Door", "Camp Fire", {item = "Cooked Chicken Breast", amount = 3 } } },
		help = { admin = true, description = "Start building!",
			items = { "Bed", {item = "Wood Wall", amount = 3}, "Wood Doorway", "Metal Door", "Wood Foundation", "Wood Storage Box", "Camp Fire", "Furnace" } }
	}
	
	if ( _txt ~= "" ) then
	    _result = json.decode( _txt )
		if (not(_result)) then
			print (self.Title .. " Configuration file is corrupted!")
			return false
		end
	else
		print (self.Title .. " Configuration file not found!")
	end
	
	local _doSave = false
	
	if (not(_result)) then
		_result = {
			command = _default_command,
			messages = _default_messages,
			kits = _default_kits
		}
		_doSave = true
	end
	if (not(_result.messages)) then
		_result.messages = {}
	end
	
	-- lets optimize messages
	self.Messages = {}
	for _name, _msg in pairs(_default_messages) do
		if (not(_result.messages[_name]) and _name ~= "broadcast" ) then
			_result.messages[_name] = _msg
			_doSave = true
		end
		self.Messages[_name] = _result.messages[_name]
	end
	
	if (not(_result.command)) then
		_result.command = _default_command
		_doSave = true
	end
	if (not(_result.chatname)) then
		_result.chatname = _result.command .. ' '
		_doSave = true
	end
	
	if (not(_result.columns)) then
		_result.columns = 0
		_doSave = true
	else
		self.Columns = _result.columns
	end
	
	if (_doSave) then
		_dataFile:SetText( json.encode( _result, { indent = true } ) )
		_dataFile:Save()
		print (self.Title .. " configuration updated")
	end
	
	self.Debug = false
	if ( _result.debug ) then
		self.Debug = _result.debug
	end
	self.Command = _result.command
	self.ChatName = _result.chatname
	
	self.KitsData = {}
	
	self.KitCount = { total = 0, player = 0}
	
	self.AutoKitCooldown = -1
	if ( _result.auto_kit_cooldown ) then
		self.AutoKitCooldown = _result.auto_kit_cooldown
	end
	
	if ( _result.kits ) then
		for _name, _kits in pairs(_result.kits) do
			local _newKits = { items = {} }
			self.KitCount.total = self.KitCount.total + 1
			if (_kits.admin) then
				_newKits.admin = _kits.admin
			else
				self.KitCount.player = self.KitCount.player + 1
			end
			if (_kits.flags) then
				 _newKits.flags = _kits.flags
				 if ( type(_newKits.flags) == "string" ) then
				 	_newKits.flags = { get = {_newKits.flags}, give = nil }
				 end
			end
			if (_kits.max) then
				_newKits.max = _kits.max
			end
			if (_kits.cooldown) then
				_newKits.cooldown = _kits.cooldown
			end
			if (_kits.description) then
				_newKits.description = _kits.description
			end
			if (not(_kits.items) or #_kits.items == 0) then
				error(self.Title .. " Kit items are missing for kit " .. _name)
				return
			end
			for __, _kit in pairs(_kits.items) do
				local _newKit = { item = "", amount = 1 }
				if (type( _kit ) == "table") then
					if (not(_kit.item)) then
						error(self.Title .. " Kit item item is missing for kit " .. _name)
						return
					end
					_newKit.item = _kit.item
					if (_kit.amount) then
						_newKit.amount = _kit.amount
					end
					if (_kit.target) then
						_newKit.target = _kit.target
					end
				else
					_newKit.item = _kit
				end
				table.insert(_newKits.items, _newKit)
			end
			print (self.Title .. " " .. _name .. " loaded")
			self.KitsData[_name] = _newKits
		end
	else
		print(self.Title .. " No kits defined!")
	end
	
	self.WelcomeKit = {}
	if ( _result.auto_kit ) then
		if (type( _result.auto_kit ) == "table") then
			for _index, _kits in pairs(_result.auto_kit) do
				local _newKits = { disabled_when = nil, items = {}, remove_rock = false, flags = {}, remove = nil }
				if (type( _kits ) == "table") then
					if ( _kits.disabled_when ) then
						_newKits.disabled_when = _kits.disabled_when
					end
					if ( _kits.remove_rock ) then
						_newKits.remove_rock = _kits.remove_rock
					end
					if ( _kits.cooldown ) then
						_newKits["cooldown"] = _kits.cooldown
					end
					if ( _kits["remove"] ) then
						if (type( _kits["remove"] ) == "table") then
							_newKits["remove"] = _kits["remove"]
						else
							_newKits["remove"] = { _kits["remove"] }
						end
					end
					if ( _kits.flags ) then
						if (type(_kits.flags) == "string") then
							_newKits.flags = { get = { _kits.flags }, give = nil }
						else
							_newKits.flags = { get = _kits.flags , give = nil }
						end
					end
					if (not(_kits.items)) then
						error(self.Title .. " Kit item item is missing for kit " .. _name)
						return
					end
	
					for __, _kit in pairs(_kits.items) do
						local _newKit = { item = nil, amount = 1 }
						if (type( _kit ) == "table") then
							if (not(_kit.item)) then
								error(self.Title .. " Kit item item is missing for kit " .. _name)
								return
							end
							_newKit.item = _kit.item
							if (_kit.amount) then
								_newKit.amount = _kit.amount
							end
							if (_kit.target) then
								_newKit.target = _kit.target
							end
						else
							_newKit.item = _kit
						end
						table.insert(_newKits.items, _newKit)
					end
	
				else
					table.insert(_newKits.items, { item = _kits, amount = 1 })
				end
				table.insert(self.WelcomeKit, _newKits )
			end
		else
			table.insert(self.WelcomeKit, { { disabled_when = nil, items = { _result.auto_kit } } })
		end
	end
	
	self.RemoveRock = nil
	if ( _result.remove_rock ) then
		if (type( _result.remove_rock ) == "table") then
			self.RemoveRock = _result.remove_rock
		else
			self.RemoveRock= { _result.remove_rock }
		end
	end
	
	self.RandomWelcomeKit = false
	if ( _result.auto_kit_random ) then
		self.RandomWelcomeKit = true
	end
	
	if ( not(self.WelcomeKit) or #self.WelcomeKit == 0) then
		print (self.Title .. " No auto kit!")
	else
		print (self.Title .. " loaded: " .. tostring(#self.WelcomeKit))
	end 
	
	if (self.KitCount.total > 0) then
		print(self.KitCount.total .. " kits and player " .. self.KitCount.player .. " kits loaded")
	else
		print ("Kits not found!")
	end
end

function PLUGIN:SendHelpText( netuser )
	local _b, _rv = api.Call("fj_flags_wrapper", "HasFlag", netuser, "deathmatch", userId  )
	if ( _b and _rv ) then
		return
	end

	if ((netuser:CanAdmin() and self.KitCount.total > 0) or (not(netuser:CanAdmin()) and self.KitCount.player > 0)) then
		rust.SendChatToUser( netuser, self.Messages.githelp )
	end
end

function PLUGIN:DoNotice(netuser, message, parameters)
	local _message = self:ParseMessage(message, parameters)
	rust.Notice( netuser, _message )
end

function PLUGIN:Init()
	self:LoadConfiguraion()
	self.RedeemedAutoKit = {}
	self.UserKitsFile = util.GetDatafile( "advanced_kits_data" )
	local _kitsResult = self.UserKitsFile:GetText()
	if ( _kitsResult ~= "" ) then
		self.UserKits = json.decode( _kitsResult )
	else
		self.UserKits = {}
	end
	
	self:AddChatCommand(self.Command, self.MainCommand)
end

function PLUGIN:MainCommand( netuser, cmd, args )
	if ((self.KitCount.player == 0 and not(netuser:CanAdmin())) or (self.KitCount.total == 0 and netuser:CanAdmin())) then
		rust.Notice( netuser, self.Messages.nokitdefined )
		return
	end

	if ( args[1] and args[1] == "about" ) then
		rust.SendChatToUser(netuser, self.Title .. " " .. self.Version .. " by " .. self.Author .. ". " .. self.Description)
		return
	end
	if ( args[1] and args[1] == "reload" and netuser:CanAdmin() ) then
		self:Reload(netuser)
		return
	end
	if ( args[1] and args[1] == "clean" and netuser:CanAdmin() ) then
		table.remove(args, 1);
		local _username = table.concat( args, " " )
		self:CleanKitStats(netuser, _username)
		return
	end

	local _b, _rv = api.Call("fj_flags_wrapper", "HasFlag", netuser, "deathmatch", userId  )
	if ( _b and _rv ) then
		return
	end

	local _kit = nil
	local _kit_name = nil
	if (args[1] and self.KitsData[args[1]]) then
		_kit_name = args[1] 
		_kit = self.KitsData[_kit_name]
	end
	local _command = nil
	if (args[2] and (args[2] == "list" or args[2] == "give")) then 
		_command = args[2]
	end

	local _user_id = rust.GetUserID( netuser )
	local _isAdmin = netuser:CanAdmin()

	local _canGet = false
	local _canGive = false
	if ( _kit ) then
		_canGet,  _canGive = self:CanRedeem( netuser, _kit, _user_id, _kit_name )
	end

	if ( _canGet or  _canGive ) then
		if (_command and _command == "list") then
			rust.SendChatToUser( netuser, self.ChatName, _command )
			for _name, _kit in pairs(_kit.items) do
				rust.SendChatToUser( netuser, self.ChatName, _kit.amount .. "  - " .. _kit.item )
			end
			return
		end

		local _message = self.Messages.redeem
		local _isgiven = false
		local _netuser = nil

		local _userGive = false
		if ( _command and _command == "give") then
			if (netuser:CanAdmin() or _canGive ) then
				_userGive = true
			end
		end

		if (_userGive and args[3]) then
			local _b, _m_netuser = api.Call("fj_users_wrapper", "FindSingleUser",  netuser, args[3])
			if (_b and _m_netuser) then
				local _m_user_id = rust.GetUserID( _m_netuser )
				if (_m_user_id == _user_id) then
					self:DoNotice(netuser, self.Messages.nogiveyourself , {kit = _kit_name})
					return
				end
				_netuser = _m_netuser
				_message = self.Messages.received
				_isgiven = true
			end
		elseif (_canGet and not(_command)) then
			local _error_message = nil

			if (_kit.max and _kit.max > 0) then
				if (not(self.UserKits[_user_id])) then
			 		self.UserKits[_user_id] = {}
			 	end
			 	if (not(self.UserKits[_user_id][_kit_name])) then
			 		 self.UserKits[_user_id][_kit_name] = {amount = 0}
			 	end
			 	if (not(self.UserKits[_user_id][_kit_name].amount)) then
			 		 self.UserKits[_user_id][_kit_name].amount = 0
			 	end
			 	if (self.UserKits[_user_id][_kit_name].amount >= _kit.max) then
			 		_error_message = string.gsub(self.Messages.exceeded , "%%kit%%", _kit_name)
			 		_error_message = string.gsub(_error_message , "%%amount%%", self.UserKits[_user_id][_kit_name].amount)
			 	end
			end
			if (not(_error_message) and _kit.cooldown and _kit.cooldown > 0) then
				if (not(self.UserKits[_user_id])) then
			 		self.UserKits[_user_id] = {}
			 	end
			 	if (not(self.UserKits[_user_id][_kit_name])) then
			 		 self.UserKits[_user_id][_kit_name] = {when = 0}
			 	end
			 	if (not(self.UserKits[_user_id][_kit_name].when)) then
			 		 self.UserKits[_user_id][_kit_name].when = 0
			 	end
			 	local _now = util.GetTime()
				if (_now > 61) then -- bug at oxide
					local _remain = self.UserKits[_user_id][_kit_name].when + (_kit.cooldown * 60) - _now
					if (_remain > 0 ) then
						local _min = math.floor( _remain / 60 )
						local _second = _remain - ( _min * 60 )
						_error_message = string.gsub(self.Messages.cooldown , "%%kit%%", _kit_name)
						_error_message = string.gsub(_error_message , "%%min%%", _min)
						_error_message = string.gsub(_error_message , "%%sec%%", _second)
					end
				end
			end
			if (not(_error_message) and (_kit.cooldown or _kit.max)) then
				if (_kit.max) then
			 		self.UserKits[_user_id][_kit_name].amount = self.UserKits[_user_id][_kit_name].amount + 1
				end
				if (_kit.cooldown) then
			 		self.UserKits[_user_id][_kit_name].when = util.GetTime()
				end
				self:Save()
			end
			if (not(_error_message)) then
				_netuser = netuser
			else
				rust.Notice(netuser, _error_message )
				return
			end
		end

		if (_netuser) then
			local _user_name = util.QuoteSafe(_netuser.displayName)
			_message =  string.gsub(_message , "%%kit%%", _kit_name)
			if (_isgiven) then
				_message =  string.gsub(_message , "%%user%%", util.QuoteSafe(netuser.displayName))
			else
				_message =  string.gsub(_message , "%%user%%", _user_name)
			end
			local _inventory = rust.GetInventory(_netuser)

			self:Redeem(_netuser, _kit.items, true, _inventory )
			if (self.Debug) then
				print(_user_name .. " redeemed " .. _kit_name)
			end

			rust.Notice(_netuser, _message )
			if (_isgiven) then
				_message =  string.gsub(self.Messages.given , "%%kit%%", _kit_name)
				_message =  string.gsub(_message , "%%user%%", _user_name)
				rust.Notice(netuser, _message )
			end
			return
		end
	end

	local _total = 0
	for _name, _kit in pairs(self.KitsData) do
		local _canGet, _canGive = self:CanRedeem( netuser, _kit, _user_id, _name )
		if ( _isAdmin or _canGet or _canGive ) then
			_total = _total + 1
			local _text = "/" .. self.Command .. " " .. _name
			local _permissions = nil
			if (netuser:CanAdmin() or _canGet) then
				_text = _text .. " <list"
			end
			if (netuser:CanAdmin() or _canGive) then
				if ( netuser:CanAdmin() or _canGet ) then
					_text = _text .. " | " 
				end
				_text = _text .. " give \"<user>\""
			end
			if ( netuser:CanAdmin() or  _canGet or _canGive   ) then
				_text = _text .. ">" 
			end
			if (_kit.admin and netuser:CanAdmin()) then
				_text = _text .. " (admin kit)"
			end
			if (_kit.description) then
				_text = _text .. " - " .. _kit.description
			end
			rust.SendChatToUser(netuser, self.ChatName, _text )

			if ( self.Columns and self.Columns > 0 ) then
				local _row = nil
				for _name, _kit in pairs(_kit.items) do
					local _text = _kit.item
					if ( _kit.amount > 1 ) then
						_text = tostring(_kit.amount) .. " x " .. _text
					end
					local _tmpRow = nil
					if ( not (_row) ) then
						_tmpRow = "--  " .. _text
					else
						_tmpRow = _row .. ", " .. _text
					end
					if ( #_tmpRow > self.Columns ) then
						rust.SendChatToUser( netuser, self.ChatName, _row )
						_row = "--  " .. _text
					else
						_row = _tmpRow
					end
				end
				if (_row) then
					rust.SendChatToUser( netuser, self.ChatName, _row )
				end
			end 
		end
	end
	if ( _total == 0 ) then
		rust.SendChatToUser( netuser, self.ChatName, self.Messages.nokit )
	end
end

function PLUGIN:DoRemoveItemByName(netuser, inv, item)
	local _item = rust.GetDatablockByName(item)
	if ( _item ) then
		local _r = inv:FindItem(_item)
		local _i = 0
		while (_r) do
			inv:RemoveItem(_r)
			_r = inv:FindItem(_item)
			_i = _i + 1
			if ( _i > 36) then
				print (self.Title .. " Too many " .. item .. "!")
				break -- avoid cycle!
			end
		end
	else
		print (self.Title .. " unknown item to remove " .. item)
	end
end

function PLUGIN:OnSpawnPlayer(playerclient, usecamp, avatar)
	local _user_id = rust.GetUserID( playerclient.netUser )
	if ( playerclient and playerclient.netUser ) then
		local _b, _rv = api.Call("fj_flags_wrapper", "HasFlag", playerclient.netUser, "deathmatch", _user_id  )
		if ( _b and _rv ) then
			return
		end
	end
	if (self.WelcomeKit or self.RemoveRock ) then
    	timer.Once(1, function() self:AutoKit(playerclient.netUser) end)
    end
end

function PLUGIN:Save()
	self.UserKitsFile:SetText( json.encode( self.UserKits ) )
	self.UserKitsFile:Save()
end

function PLUGIN:PostInit()
	if( api.Exists("fj_flags_wrapper") ) then
		print(self.Title .. " Flags wrapper plugin implemented")
	else
		print(self.Title .. " Flags wrapper plugin not found!")
	end
	
	api.Call("broadcast", "RemoveExternalMessage", "advanced_kits")
	if ( self.Messages.broadcast ) then
		api.Call("broadcast", "AddExternalMessage", "advanced_kits", self.Messages.broadcast, { chatname = self.ChatName } )
	end
end
