PLUGIN.Author="Fox Junior"
PLUGIN.Title="Broadcast"
PLUGIN.ResourceId=280
PLUGIN.Version="1.16.7"
PLUGIN.Description="Broadcast your messages. Pluggable, highly customizable"
print("Loading " .. PLUGIN.Title .. " " .. PLUGIN.Version)

function PLUGIN:Unload()
	if (self.BroadCaster) then
		self.BroadCaster:Destroy()
	else
		print (self.Title .. " Broadcaster was not initialized! Thats might be not right!")
	end
end

-- info: { channel = channel, chatname = chatname }
function PLUGIN:AddExternalMessage( plugin, message, info )
	_data = {  m = message, i = info}
	if ( not( self.ExternalConfiguration[plugin] ) ) then
		self.ExternalConfiguration[plugin] = {}
	end
	self:AddMessage( message, info )
	table.insert(self.ExternalConfiguration[plugin], _data)
end

function PLUGIN:LoadConfiguration()
	if (self.BroadCaster) then
		self.BroadCaster:Destroy()
	end
	self.Messages = {}
	
	local _dataFile = util.GetDatafile( "cfg_advanced_broadcast" )
	local _txt = _dataFile:GetText()
	local _result = nil
	if ( _txt ~= "" ) then
	    _result = json.decode( _txt )
		if (not(_result)) then
			print (self.Title .. " Configuration file is corrupted!")
			return false
		end
	else
		print (self.Title .. " Configuration file not found!")
	end
	if ( not(_result)) then
		_result = {}
	end
	
	local _default_conf = {
		chatname = "message",
		delay = 600,
		channel = "chat",
		command = "broadcast",
		messages = {
			{
				chatname = "tip of the day",
				message = "Check out our help!"
			},
			{
				chatname = "tip of the day",
				message = "Check out our help!"
			},
			{
				"For latest updates and rules visit our website",
				"http://example.com"
			},
			{ channel = "notice", message = "Respect rules and play fair!" },
			{ channel = "inventory", message = "Respect rules and play fair!" },
			"Respect rules and play fair!"
		},
		flags = {},
		commands = {
			chat = "chat",
			notice = "notice",
			reload = "reload",
			push = "push",
			inventory = "inv"
		},
		shortcuts = {chat = ":", notice = "!"}
	}
	
	local _doSave = false
	if (not(_result)) then
		_result = _default_conf
		_doSave = true
	end
	
	for _key, _conf in pairs( _default_conf ) do
		if ( _result[_key] == nil ) then
			_result[_key] = _conf
			_doSave = true
		end
	end
	if ( not(_result.channel) ) then
		_result.channel = "chat"
		_doSave = true
	end
	if ( not(_result.commands) ) then
		_result.commands = _default_conf.commands
		_doSave = true
	end
	if ( not(_result.flags) ) then
		_result.flags = _default_conf.flags
		_doSave = true
	end
	
	for _type, _value in pairs( _result.commands ) do
		if ( not(_result.commands[_type]) ) then
			_result.commands[_type] = _value
			_doSave = true
		end
	end
	
	if (_doSave) then
		_dataFile:SetText( json.encode( _result, { indent = true } ) )
		_dataFile:Save()
		print (self.Title .. " configuration updated")
	end
	
	self.ChatName = _result.chatname
	self.Channel = _result.channel
	self.Commands = _result.commands
	self.Flags = _result.flags
	self.ShortCuts = { chat = nil, notice = nil }
	if (_result.shortcuts and _result.shortcuts.chat) then
		self.ShortCuts.chat = _result.shortcuts.chat
	end
	if (_result.shortcuts and _result.shortcuts.notice) then
		self.ShortCuts.notice = _result.shortcuts.notice
	end
	
	if ( _result.messages ) then
		if ( not( type(_result.messages) == "table") ) then
			error("configuration.messages must be a list!")
		end
		for _, _conf in pairs( _result.messages ) do
			if ( type(_conf) == "table" and _conf.message ) then
				self:AddMessage(_conf.message, _conf)
			else
				self:AddMessage(_conf)
			end
		end
	end
	
	print ("Starting " .. self.Title .. " " .. tostring(_result.delay) )
	self.BroadCaster = timer.Repeat( _result.delay, 0, function() self:DoBroadcast() end )
	for _plugin, _info in pairs( self.ExternalConfiguration ) do
		for _, _msg in pairs(_info) do
			self:AddMessage( _msg.m, _msg.i )
		end
	end
	return _result.command
end

-- remove external plugin message
function PLUGIN:RemoveExternalMessage(plugin)
	if ( not( self.ExternalConfiguration[plugin] ) ) then
		return
	end
	self.ExternalConfiguration[plugin] = nil
	self:LoadConfiguration()
end

function PLUGIN:OnUserChat( netuser, name, msg )
	-- Check for 0 length message
	if (msg:len() == 0 or msg:sub( 1, 1 ) == "/") then return end
	
	-- Is it a chat command?
	if (self.ShortCuts.notice and msg:sub( 1, 1 ) == self.ShortCuts.notice) then
		if ( not (self:HasPermission(netuser)) ) then
			return
		end

		local _msg = msg:sub( 2 )
		if (_msg and _msg ~= "") then
			self:DoBroadcastToNotice({_msg})
		end
		return true
	elseif (self.ShortCuts.chat and msg:sub( 1, 1 ) == self.ShortCuts.chat) then
		if ( not (self:HasPermission(netuser)) ) then
			return
		end

		local _msg = msg:sub( 2 )
		if (_msg and _msg ~= "") then
			self:DoBroadcastToChat({_msg})
		end
		return true
	end
end

function PLUGIN:DoBroadcastMessage(message, info, channel )
	if ( not(channel) ) then
		channel = self.Channel
	end
	if (channel == self.SupportedChannel.chat ) then
		self:DoBroadcastToChat(message, info )
	elseif (channel == self.SupportedChannel.notice ) then
		self:DoBroadcastToNotice( message, info )
	elseif (channel == self.SupportedChannel.inventory ) then
		self:DoBroadcastToInventory( message, info )
	end
end

function PLUGIN:DoBroadcastToNotice( messages, info )
	local _users = rust.GetAllNetUsers()
	for _, _user in pairs( _users ) do
		for _, _message in pairs( messages ) do
			rust.Notice( _user, _message )
		end
	end
end

function PLUGIN:AddMessage( messages, info )
	if ( not( self.Messages ) ) then
		self.Messages = {}
	end
	local _info = { channel = self.Channel, chatname = self.ChatName, message = messages }
	if ( info and  info.chatname ) then
		_info.chatname = info.chatname
	end
	if ( info and info.channel and self.SupportedChannel[info.channel]) then
		_info.channel = info.channel
	end
	local _message = nil
	if ( type( messages ) ~= "table" ) then
		_info.message = { messages }
	end
	_info.c = self.SupportedChannel[_info.channel]
	table.insert( self.Messages, _info )
	return #self.Messages
end

function PLUGIN:HasPermission(netuser)
	if ( not(netuser:CanAdmin()) ) then
		local _b, _rv = api.Call("fj_flags_wrapper", "HasFlag", netuser, self.Flags)
		return _b and _rv
	end
	return true
end

function PLUGIN:DoBroadcastToChat( messages, info )
	local _chatname = nil
	if ( info and info.chatname ) then
		_chatname = info.chatname
	end
	if ( not (_chatname) ) then
		_chatname = self.ChatName
	end
	for _, _message in pairs( messages ) do
		if ( not (_chatname) ) then
			rust.BroadcastChat( _message )
		else
			rust.BroadcastChat( _chatname, _message )
		end
	end
end

function PLUGIN:DoBroadcastToInventory( messages, info )
	local _users = rust.GetAllNetUsers()
	for _, _user in pairs( _users ) do
		for _, _message in pairs( messages ) do
			rust.InventoryNotice( _user, _message )
		end
	end
end

function PLUGIN:DoBroadcast()
	local _len = #self.Messages
	if ( _len == 0 ) then
		print ("No messages")
		return
	end
	local _random = math.random( 1, _len )
	return self:DoBroadcastByIndex(_random)
end

function PLUGIN:SendHelpText( netuser )
	if ( self:HasPermission(netuser) ) then
		rust.SendChatToUser(netuser, "/" .. self.Command .. " see broadcast help" )
	end
end

function PLUGIN:BroadCastCommand(netuser, cmd, args)
	if ( not (self:HasPermission(netuser)) ) then
		return false
	end
	local _cmd = nil
	if ( args[1] ) then
		_cmd = table.remove(args, 1);
	end
	if (_cmd and _cmd == "about" ) then
		rust.SendChatToUser(netuser, self.Title .. " " .. self.Version .. " by " .. self.Author .. ". " .. self.Description)
		return
	elseif (_cmd and _cmd == self.Commands["push"]) then
		if ( not args[1] ) then
			self:DoBroadcast()
			return
		end
		local _index = tonumber( args[1] )
		if ( not( self:DoBroadcastByIndex(_index) ) ) then
			rust.SendChatToUser(netuser, "invalid index")
		end
		return
	elseif (_cmd and _cmd == self.Commands.reload) then
		self:LoadConfiguration()
		rust.SendChatToUser(netuser, "Broadcast data reloaded")
		return
	elseif ( _cmd and ( _cmd == self.Commands.chat or _cmd == self.Commands.notice or _cmd == self.Commands.inventory) ) then
		local _message = table.concat( args, " " )
		if (_message == "") then
			rust.SendChatToUser(netuser, "Nothing to send to " .. _cmd )
			return
		end
		if (_cmd == self.Commands.chat) then
			self:DoBroadcastToChat( { _message } )
		elseif (_cmd == self.Commands.notice) then
			self:DoBroadcastToNotice({ _message })
		elseif (_cmd == self.Commands.inventory) then
			self:DoBroadcastToInventory({ _message })
		else
			rust.SendChatToUser(netuser, "Unknown target" .. _cmd )
			rust.SendChatToUser(netuser, "/" .. self.Command .. " " .. self.Commands.chat)
			rust.SendChatToUser(netuser, "/" .. self.Command .. " " .. self.Commands.notice)
			rust.SendChatToUser(netuser, "/" .. self.Command .. " " .. self.Commands.inventory)
			rust.SendChatToUser(netuser, "/" .. self.Command .. " " .. self.Commands.reload)
			rust.SendChatToUser(netuser, "/" .. self.Command .. " " .. self.Commands["push"])
		end
		return
	end
	for _index, _msgs in pairs(  self.Messages ) do
		local _type = nil
		if (_msgs.c == self.SupportedChannel.chat ) then
			_type = "chat"
		elseif (_msgs.c == self.SupportedChannel.notice ) then
			_type = "notice"
		elseif (_msgs.c == self.SupportedChannel.inventory ) then
			_type = "inventory"
		end
		for _, _message in pairs( _msgs.message ) do
			rust.SendChatToUser(netuser, _msgs.chatname, tostring(_index) .. " - " .. _type  .. " - " .. _message)
		end
	end
	rust.SendChatToUser(netuser, "/" .. self.Command .. " " .. self.Commands.chat .. " <message> to send chat notice")
	rust.SendChatToUser(netuser, "/" .. self.Command .. " " .. self.Commands.notice .. " <message> to send notice notice")
	rust.SendChatToUser(netuser, "/" .. self.Command .. " " .. self.Commands.inventory .. " <message> to send inventory notice")
	rust.SendChatToUser(netuser, "/" .. self.Command .. " " .. self.Commands.reload .. " reload configuration")
	rust.SendChatToUser(netuser, "/" .. self.Command .. " " .. self.Commands["push"] .. " push random message")
	rust.SendChatToUser(netuser, "/" .. self.Command .. " " .. self.Commands["push"] .. " <number> - push specific message ( see /" .. self.Command ..  " for list of messages")
end

function PLUGIN:DoBroadcastByIndex(index)
	if ( index > #self.Messages or index <= 0) then
		return false
	end
	local _msgs = self.Messages[ index ]
	self:DoBroadcastMessage(_msgs.message, _msgs, _msgs.c)
	return true
end

function PLUGIN:Init()
	self.SupportedChannel = { chat = 1, notice = 2, inventory = 3 }
	self.ExternalConfiguration = {}
	self.Command = self:LoadConfiguration()
	self:AddChatCommand( self.Command, self.BroadCastCommand )
	api.Bind(self, "broadcast")
end

function PLUGIN:PostInit()
	if( api.Exists("fj_flags_wrapper") ) then
		print(self.Title .. " Flags wrapper plugin implemented")
	else
		print(self.Title .. " Flags wrapper plugin not found!")
	end
end
