PLUGIN.Author="Fox Junior"
PLUGIN.Title="News"
PLUGIN.ResourceId=291
PLUGIN.Version="1.16.5"
PLUGIN.Description="Create news wall"
print("Loading " .. PLUGIN.Title .. " " .. PLUGIN.Version)

function PLUGIN:CanDoAction( netuser, action)
	if (netuser:CanAdmin()) then
		return true
	end
	if ( (action == self.Commands.add or action == self.Commands.list) and self.Flags and self.Flags.add ) then
		return self:HasPermission(netuser, self.Flags.add)
	elseif ( (action == self.Commands.remove or action == self.Commands.clean) and self.Flags and self.Flags.remove ) then
		return self:HasPermission(netuser, self.Flags.remove)
	end
	return false
end

function PLUGIN:HasPermission(netuser, flag)
	if ( not(netuser:CanAdmin()) ) then
		local _b, _rv = api.Call("fj_flags_wrapper", "HasFlag", netuser, flag)
		return _b and _rv
	end
	return true
end

function PLUGIN:AddBroadcast()
	api.Call("broadcast", "RemoveExternalMessage", "news")
	if ( self.Messages.broadcast ) then
		api.Call("broadcast", "AddExternalMessage", "news", self.Messages.broadcast, { chatname = self.ChatName } )
	end
end

function PLUGIN:SaveNews()
	self.NewsFile:SetText( json.encode( self.News ) )
	self.NewsFile:Save()
	self:AddBroadcast()
end

function PLUGIN:ShowNews( netuser, shownum)
	if (#self.News == 0) then
		rust.SendChatToUser(netuser, self.ChatName, self.Messages.nonews )
		return
	end
	if (self.Messages.title) then
		rust.SendChatToUser(netuser, self.ChatName, self.Messages.title )
	end
	local _amount = 0
	for _index, _message in pairs(self.News) do
		if (shownum ) then
			rust.SendChatToUser(netuser, tostring(_index), _message.ts .. ": " .. _message.name .. " - " .. _message.msg )
		else
			rust.SendChatToUser(netuser, _message.ts, _message.msg )
		end
		_amount = _amount + 1
	end
	if (self.Messages.footer) then
		local _msg = string.gsub(self.Messages.footer , "%%total%%", tostring(_amount))
		rust.SendChatToUser(netuser, self.ChatName,_msg )
	end
end

function PLUGIN:SendHelpText( netuser )
	rust.SendChatToUser( netuser, self.Messages.help )
	for _, _cmd in pairs(self.Commands) do
		if (self:CanDoAction (netuser, _cmd)) then
			local _msg = "/" .. self.Command .. " " .. _cmd
			if ( _cmd == self.Commands.add ) then
				_msg = _msg .. " <message> - add new news message"
			elseif ( _cmd == self.Commands.list ) then
				_msg = _msg .. " - list by numbers to remove"
			elseif ( _cmd == self.Commands.remove ) then
				_msg = _msg .. " <message number> - remove specific message"
			elseif ( _cmd == self.Commands.clean ) then
				_msg = _msg .. " - clean up news"
			end
			rust.SendChatToUser( netuser, self.ChatName, _msg )
		end
	end
end

function PLUGIN:Init()
	local _default_conf = {
		max = 20,
		messages = {
			title = "Latest News:",
			nonews = "No news!",
			footer = "Total %total% news.",
			broadcast = "Have you read our news? Check /news",
			tsformat = "MM/dd/yyyy"
		},
		commands = {
			list = "?",
			add = "+",
			remove = "-",
			clean = "clean"
		},
		loginnews = 1,
		chatname = "news",
		flags = { add = "adminhelper", remove = "adminhelper"},
		command = "news"
	}
	
	local _dataFile = util.GetDatafile( "cfg_news" )
	local _txt = _dataFile:GetText()
	local _result = nil
	if ( _txt ~= "" ) then
	    _result = json.decode( _txt )
		if (not(_result)) then
			print (self.Title .. " Configuration file is corrupted!")
			_result = nil
		end
	else
		print (self.Title .. " Configuration file not found!")
	end
	
	local _doSave = false
	if (not(_result)) then
		_result = _default_conf
		_doSave = true
	end
	if (not(_result.max)) then
		_result.max = _default_conf.max
		_doSave = true
	end
	if (not(_result.messages)) then
		_result.messages = _default_conf.messages
		_doSave = true
	end
	if (not(_result.messages.when)) then
		_result.messages.when = _default_conf.messages.when
		_doSave = true
	end
	if (not(_result.messages.nonews)) then
		_result.messages.nonews = _default_conf.messages.nonews
		_doSave = true
	end
	if (not(_result.command)) then
		_result.command = _default_conf.command
		_doSave = true
	end
	if (not(_result.messages.help)) then
		_result.messages.help = "Type /" .. _result.command .. " to see our news"
		_doSave = true
	end
	if (not(_result.messages.tsformat)) then
		_result.messages.tsformat = _default_conf..messages.tsformat
		_doSave = true
	end
	if (not(_result.commands)) then
		_result.commands = _default_conf.commands
		_doSave = true
	end
	if (not(_result.chatname)) then
		_result.chatname = _result.command
		_doSave = true
	end
	if (not(_result.loginnews)) then
		_result.loginnews = _default_conf.loginnews
		_doSave = true
	end
	for _key, _cmd in pairs(  _default_conf.commands ) do
		if (not(_result.commands[_key])) then
			_result.commands[_key] =  _cmd
			_doSave = true
		end
	end
	if (not(_result.flags)) then
		_result.flags = _default_conf.flags
		_doSave = true
	end
	
	for _key, _flags in pairs(  _default_conf.flags ) do
		if ( not ( _result.flags[_key] ) ) then
			_result.flags[_key] = _flags
			_doSave = true
		elseif ( type(_result.flags[_key]) ~= "table" ) then
			_result.flags[_key] = {_result.flags[_key]}
			_doSave = true
		end
	end
	
	if (_doSave) then
		_dataFile:SetText( json.encode( _result, { indent = true } ) )
		_dataFile:Save()
		print (self.Title .. " configuration updated")
	end
	self.Commands = _result.commands
	self.Messages = _result.messages
	self.ChatName = _result.chatname
	self.MaxNews = _result.max
	self.Flags = _result.flags
	self.Command = _result.command
	self.LoginNews = _result.loginnews
	
	-- load news
	self.NewsFile = util.GetDatafile( "news_data" )
	local txt = self.NewsFile:GetText()
	if (txt ~= "") then
	    local _resultNews = json.decode( txt )
		if (not(_resultNews)) then
			print (self.Title .. " news file file is corrupted!")
			self.News = {}
		else
			self.News = _resultNews
		end
	else
		self.News = {}
	end
	-- clean up
	if (#self.News > self.MaxNews) then
		local _news = self.News
		local _until = #self.News - self.MaxNews
		for _i=1, _until do
			table.remove(_news, 1);
		end
		self.News = _news
	end
	
	self:AddChatCommand( _result.command, self.NewsCommand )
end

function PLUGIN:NewsCommand( netuser, cmd, args)
	if (args[1] and args[1] == "about" ) then
		rust.SendChatToUser(netuser, self.Title .. " " .. self.Version .. " by " .. self.Author .. ". " .. self.Description)
		return
	end
	if ( args and args[1] ) then
		local _cmd = table.remove(args, 1);
		if (self:CanDoAction (netuser, _cmd)) then
			if ( _cmd == self.Commands.add ) then
				local _message = table.concat( args, " " )
				if (_message == "") then
					rust.SendChatToUser(netuser, "You forgot to enter your news" )
					return
				end
				local _now = System.DateTime.Now:ToString(self.Messages.tsformat)
				table.insert(self.News, {
							ts = _now,
							name = util.QuoteSafe(tostring(netuser.displayName)),
							msg = util.QuoteSafe(tostring(_message))
						})
				if (#self.News > self.MaxNews) then
					table.remove(self.News, 1);
				end
				rust.SendChatToUser(netuser, self.ChatName, "Added!")
				self:SaveNews()
				return
			elseif ( _cmd == self.Commands.list ) then
				self:ShowNews(netuser, true)
				return
			elseif ( _cmd == self.Commands.clean ) then
				self.News = {}
				self:SaveNews()
				rust.SendChatToUser(netuser, self.ChatName, "News Cleaned!")
				return
			elseif ( _cmd == self.Commands.remove ) then
				local _nr = nil
				if ( args[1]) then
					_nr = table.remove(args, 1)
				end
				if ( not(_nr) or not(type(_nr) ~= "number") ) then
					rust.SendChatToUser(netuser, self.ChatName, "specify news number to remove. See list command")
					return
				end
				_nr = tonumber(_nr)
				if ( _nr > #self.News ) then
					rust.SendChatToUser(netuser, self.ChatName, "number too large,see list")
					return
				end
				table.remove(self.News, _nr)
				rust.SendChatToUser(netuser, self.ChatName, "News removed")
				self:SaveNews()
				return
			end
		end
	end
	self:ShowNews(netuser)
end

function PLUGIN:PostInit()
	if( api.Exists("fj_flags_wrapper") ) then
		print(self.Title .. " Flags wrapper plugin implemented")
	else
		print(self.Title .. " Flags wrapper plugin not found!")
	end
	self:AddBroadcast()
end

function PLUGIN:OnUserConnect( netuser )
	if ( not( netuser ) or not( netuser.networkPlayer ) ) then
		print("User is null! Seems like he has been disconnected before")
		return
	end
	if ( not(self.LoginNews) or  self.LoginNews == 0 ) then
		return
	end
	if (not(self.News) or #self.News == 0) then
		return
	end
	local newsStart = #self.News - self.LoginNews + 1
	if (newsStart < 1) then
		newsStart = 1
	end
	for _index = newsStart, #self.News do
		rust.SendChatToUser(netuser, self.News[_index].ts, self.News[_index].msg )
	end
end
