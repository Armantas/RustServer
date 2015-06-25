PLUGIN.Title = "Daytime Poll"
PLUGIN.Description = "Allows players to vote for daytime"
PLUGIN.Author = "GreenMan"
PLUGIN.Version = "2.2.1"


function PLUGIN:Init ()
	local b, res = config.Read ( "daytime" )
	self.Config = res or {}
	if (not b) then
		self:LoadDefaultConfig()
		if ( res ) then config.Save( "daytime" ) end
	end
	self:AddChatCommands()
	self:CheckPlugins()
end

function PLUGIN:LoadDefaultConfig ()
	self.Config.VoteCMD = "vote"
	self.Config.poll_timer = 30
	self.Config.start_time = 18.00
	self.Config.end_time = 5.00
	self.Config.denied_time = 300
	self.Config.percent_topass = 50
	self.Config.Poll_Cost = 500
	self.Config.disable_whendenied = true
	self.Config.PollEnabled = true
	self.Config.EnableEcon = false
end

function PLUGIN:AddChatCommands ()
	self:AddChatCommand( self.Config.VoteCMD, self.cmdvote )
	self:AddChatCommand( "daytime", self.cmddaytime )
	self:AddChatCommand( "gametime", self.cmdgametime )
	self:AddChatCommand( "daysettings", self.cmdSettings )
end

function PLUGIN:CheckPlugins ()
	if (self.Config.EnableEcon == true) then
		local bushy = plugins.Find( "bushycoin" )
		econ = plugins.Find( "econ" )
		if ( bushy ) and ( not econ ) then
			econ_loaded = "bushycoin"
			print( "Timed DayTime Poll Loaded with Bushy Coin Support" )
		elseif ( econ ) and ( not bushy ) then
			econ_loaded = "econ"
			print( "Timed DayTime Poll Loaded with Basic/Extended Economy Support" )
		elseif ( econ ) and ( bushy ) then 
			print( "ERROR: Two Economy Plugins Found" )
			print( "Timed Daytime Poll Loaded with no Economy Support" )
		else
			print( "ERROR: No Economy Plugins Found" )
			print( "Timed Daytime Poll Loaded with no Economy Support" )
		end
	else 
		print ( "Timed Daytime Poll Loaded." )
	end
end

function PLUGIN:cmdgametime ( netuser, cmd )
	local game_time = Rust.EnvironmentControlCenter.Singleton:GetTime()
	rust.Notice( netuser, "Current Game time is: " .. string.format("%.2f", game_time) )
end

function PLUGIN:cmdSettings( netuser, cmd, args )
	if (  netuser:CanAdmin() ) then
		if ( not args[1] ) then
			rust.SendChatToUser( netuser, "DayTime Poll", "*--------Daytime Settings--------*" )
			rust.SendChatToUser( netuser, "DayTime Poll", "/daysettings { OPTION } { VALUE }" )
			rust.SendChatToUser( netuser, "DayTime Poll", "enable { true|false }" )
			rust.SendChatToUser( netuser, "DayTime Poll", "percent { 1-100 }" )
			rust.SendChatToUser( netuser, "DayTime Poll", "starttime { 1 - 23 }" )
			rust.SendChatToUser( netuser, "DayTime Poll", "endtime { 1 - 23 }" )
			rust.SendChatToUser( netuser, "DayTime Poll", "deniedtime { SECONDS }" )
			rust.SendChatToUser( netuser, "DayTime Poll", "deniedcd { true | false }" )
			rust.SendChatToUser( netuser, "DayTime Poll", "poll_length { SECONDS }" )
			rust.SendChatToUser( netuser, "DayTime Poll", "econ { true | false }" )
			rust.SendChatToUser( netuser, "DayTime Poll", "cost { Number > 0 }" )
			return
		elseif ( args[1] == "enable" ) then
			if ( not args[2] ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Daytime Poll is currently set to: " .. tostring(self.Config.PollEnabled) )
				return
			elseif ( args[2] == "true" ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Daytime poll is now enabled" )
				self.Config.PollEnabled = true
				config.Save( "daytime" )
				return
			elseif ( args[2] == "false" ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Daytime poll is now disabled" )
				self.Config.PollEnabled = false
				config.Save( "daytime" )
				return		
			else rust.SendChatToUser( netuser, "DayTime Poll", "Must Enter True|False.") return end
		elseif ( args[1] == "percent" ) then
			if ( not args[2] ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Percent to Pass is currently set to: " .. tostring(self.Config.percent_topass) .. "%" )
				return
			elseif ( 0 < tonumber(args[2]) and tonumber(args[2]) <= 100 ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Percent of Yes Votes to Pass is now: " .. args[2] )
				self.Config.percent_topass = tonumber(args[2]) 
				config.Save( "daytime" )
				return
			else rust.SendChatToUser( netuser, "DayTime Poll", "Please enter a number between 1 and 100" ) return end
		elseif ( args[1] == "starttime" ) then
			if ( not args[2] ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Poll Start Time is currently set to: " .. tostring(self.Config.start_time) )
				return
			elseif ( 0 < tonumber(args[2]) and tonumber(args[2]) <= 23 ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Start Time is now set to: " .. args[2] )
				self.Config.start_time = tonumber(args[2])
				config.Save( "daytime" )
				return
			else rust.SendChatToUser( netuser, "DayTime Poll", "Please enter a number between 1 and 23" ) return end
		elseif ( args[1] == "endtime" ) then
			if ( not args[2] ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Poll End Time is currently set to: " .. tostring(self.Config.end_time) )
				return
			elseif ( 0 < tonumber(args[2]) and tonumber(args[2]) <= 23 ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "End Time is now set to: " .. args[2] )
				self.Config.end_time = tonumber(args[2])
				config.Save( "daytime" )
				return		
			else rust.SendChatToUser( netuser, "DayTime Poll", "Please enter a number between 1 and 23" ) return end
		elseif ( args[1] == "deniedtime" ) then
			if ( not args[2] ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Denied Timer is currently set to: " .. tostring(self.Config.denied_time) .. " seconds." )
				return
			elseif ( tonumber(args[2]) > 0 ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Denied Timer is now set to: " .. args[2] .. " seconds" )
				self.Config.denied_time = tonumber(args[2])
				config.Save( "daytime" )
				return		
			else rust.SendChatToUser( netuser, "DayTime Poll", "Please enter a number between Greater then 0. To Disable, change deniedcd to false." ) return end	
		elseif ( args[1] == "deniedcd") then
			if ( not args[2] ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Disable When Denied is currently set to: " .. tostring(self.Config.disable_whendenied) )
				return
			elseif ( args[2] == "true" ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Daytime poll will now be disabled when denied" )
				self.Config.disable_whendenied = true
				config.Save( "daytime" )
				return
			elseif ( args[2] == "false" ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Daytime poll will not be disabled when denied" )
				self.Config.disable_whendenied = false
				config.Save( "daytime" )
				return		
			else rust.SendChatToUser( netuser, "Must Enter True|False.") return end
		elseif ( args[1] == "poll_length") then
			if ( not args[2] ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Poll Length is currently set to: " .. tostring(self.Config.poll_timer) .. " seconds" )
				return
			elseif ( tonumber(args[2]) > 0 ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Poll Length is now set to: " .. args[2] .. " seconds" )
				self.Config.poll_timer = tonumber(args[2])
				config.Save( "daytime" )
				return		
			else rust.SendChatToUser( netuser, "DayTime Poll", "Please enter a number between Greater then 0. To Disable, change deniedcd to false." ) return end
		elseif ( args[1] == "cost") then
			if ( not args[2] ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Poll Cost is currently set to: $" .. tostring(self.Config.Poll_Cost) )
				return
			elseif ( tonumber(args[2]) > 0 ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Poll Cost is now set to: $" .. args[2] )
				self.Config.Poll_Cost = tonumber(args[2])
				config.Save( "daytime" )
				return		
			else rust.SendChatToUser( netuser, "DayTime Poll", "Please enter a number between Greater then 0. To Disable, change econ to false." ) return end
		elseif ( args[1] == "econ") then
			if ( not args[2] ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Use Economy is currently set to: " .. tostring(self.Config.disable_whendenied) )
				return
			elseif ( args[2] == "true" ) then
				self.Config.EnableEcon = true			
				if ( not econ_loaded ) then self:CheckPlugins() end
				rust.SendChatToUser( netuser, "DayTime Poll", "Daytime poll will now use Economy Plugins" )
				config.Save( "daytime" )
				return
			elseif ( args[2] == "false" ) then
				rust.SendChatToUser( netuser, "DayTime Poll", "Daytime Poll will no longer use Economy Plugins." )
				self.Config.EnableEcon = false
				config.Save( "daytime" )
				return		
			else rust.SendChatToUser( netuser, "Must Enter True|False.") return end
		else rust.SendChatToUser( netuser, "DayTime Poll", "Unknown Option" ) return end
	end
end


function PLUGIN:cmddaytime( netuser, cmd, args )
	local current_time = Rust.EnvironmentControlCenter.Singleton:GetTime()
	if ( args[1] == "help" ) then
		rust.SendChatToUser( netuser, "DayTime Poll", "*------Daytime Poll by GreenMan------*" )
		rust.SendChatToUser( netuser, "DayTime Poll", "Use /daytime to start a poll for Day" )
		rust.SendChatToUser( netuser, "DayTime Poll", "When a poll is active:" )
		rust.SendChatToUser( netuser, "DayTime Poll", "\"/" .. self.Config.VoteCMD .. " Y\" to vote FOR Day" )
		rust.SendChatToUser( netuser, "DayTime Poll", "\"/" .. self.Config.VoteCMD .. " N\" to vote AGAINST Day" )
		rust.SendChatToUser( netuser, "DayTime Poll", "Polls can be started between " .. string.format("%.2f",self.Config.start_time) .. " and " .. string.format("%.2f",self.Config.end_time) )
		rust.SendChatToUser( netuser, "DayTime Poll", "Type /gametime to see the current Time ingame" )
		if (  netuser:CanAdmin() ) then rust.SendChatToUser( netuser, "DayTime Poll", "Type /daysettings to Change Settings while in-game" ) end
		rust.SendChatToUser( netuser, "DayTime Poll", "*-------------------------------------------*" )
		return
	end
	if ( poll_denied and self.Config.disable_whendenied == true ) or ( self.Config.PollEnabled ~= true ) then
		rust.Notice( netuser, "Poll is Disabled" )
		return
	end
	if ( current_time  > tonumber(self.Config.start_time) ) or ( current_time < tonumber(self.Config.end_time) ) then
		if ( poll_on ) then
			rust.Notice( netuser, "A vote has already begun!" )
			return
		else
			if (self.Config.EnableEcon == true ) and ( econ_loaded ) then
				if (econ_loaded == "bushycoin") then
					local call, req, res = api.Call( "bushycoin", "balance", netuser )
					if ( res < tonumber(self.Config.Poll_Cost) ) then
						rust.SendChatToUser( netuser, "DayTime Poll", "You don't have enough money to do this." )
						return
					else
						local call, req, res = api.Call ( "bushycoin", "deduct", netuser, tonumber(self.Config.Poll_Cost) )
						rust.SendChatToUser( netuser, "DayTime Poll", "You have successfully Started a Daytime Poll for $" .. self.Config.Poll_Cost )
					end
				end
				if (econ_loaded == "econ") then
					local player = rust.GetUserID( netuser )
					if ( econ.Data[ player ].Money < tonumber(self.Config.Poll_Cost) ) then
						rust.SendChatToUser( netuser, "DayTime Poll", "You don't have enough money to do this." )
						return
					else
						econ.Data[ player ].Money = econ.Data[ player ].Money - tonumber(self.Config.Poll_Cost)
						rust.SendChatToUser( netuser, "DayTime Poll", "You have successfully Started a Daytime Poll for $" .. self.Config.Poll_Cost )
					end
				end
			end				
			poll_on = true
			yes_votes = 0
			no_votes = 0
			user_voted = rust.GetAllNetUsers()
			rust.RunServerCommand( "notice.popupall \"" .. self.Config.poll_timer .. " Second Poll for Daytime:  /" .. self.Config.VoteCMD .. " Y or N \"" )	
			endpolltimer = timer.Once( tonumber(self.Config.poll_timer), function() self:endpoll() end )
		end
	else
		rust.Notice( netuser, "Poll only available at Night!" )
	end
end

function PLUGIN:cmdvote ( netuser, cmd, args )
	local all_connected = tonumber(#rust.GetAllNetUsers())
	if ( not poll_on ) then
		rust.Notice( netuser, "There is no Active Poll!" )
		return
	end
	if ( user_voted[ netuser ] ~= true ) then
		if ( args[1] == "Y" ) or ( args[1] == "y") then
			rust.BroadcastChat( "DayTime Poll", netuser.DisplayName .. " votes Yes!" )
			yes_votes = yes_votes + 1
			user_voted[ netuser ] = true
		elseif ( args[1] == "N" ) or ( args[1] == "n" ) then
			rust.BroadcastChat( "DayTime Poll", netuser.DisplayName .. " votes No!" )
			no_votes = no_votes + 1
			user_voted[ netuser ] = true
		else
			rust.Notice( netuser, "Must be /vote Y or N" )
		end
	else
		rust.Notice( netuser, "You may only vote once!" )
		return
	end
	if ((yes_votes + no_votes) == all_connected) then
		endpolltimer:Destroy()
		self:endpoll()
	end
end	

function PLUGIN:SendHelpText ( netuser )
	rust.SendChatToUser( netuser, "DayTime Poll", "Use \"/daytime help\" for DayTime Poll Commands. " )
end

function PLUGIN:endpoll ()
	if ( yes_votes > 0 ) then
		local totalvotes = yes_votes + no_votes
		if ( (( yes_votes / totalvotes ) * 100 ) >= tonumber(self.Config.percent_topass) ) then
			rust.RunServerCommand( "notice.popupall \"Vote Has Passed!\"" )
			rust.RunServerCommand( "env.time 6" )
			rust.BroadcastChat( "DayTime Poll", "Time is now 6:00 am" )
		else
			rust.RunServerCommand( "notice.popupall \"Daytime has been denied!\"" )
			if (self.Config.disable_whendenied == true) then
				rust.BroadcastChat ( "DayTime Poll", "Poll will be disabled for " .. self.Config.denied_time .. " seconds." )
				poll_denied = true
				timer.Once( self.Config.denied_time, function() poll_denied = nil end )
			end
		end
	else 
		rust.RunServerCommand( "notice.popupall \"Daytime has been denied!\"" )
		if (self.Config.disable_whendenied == true) then
			rust.BroadcastChat ( "DayTime Poll", "Poll will be disabled for " .. self.Config.denied_time .. " seconds." )
			poll_denied = true
			timer.Once( self.Config.denied_time, function() poll_denied = nil end )
		end
	end
	for k,v in pairs(user_voted) do user_voted[k]=nil end
	poll_on = nil
	yes_votes = nil
	no_votes = nil
end
	
	
	