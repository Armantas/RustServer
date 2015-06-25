PLUGIN.Title = "Clean Up"
PLUGIN.Description = "Clean the server: remove decaying houses, bags, and sleepers"
PLUGIN.Author = "Reneb"
PLUGIN.Version = "1.1.3"

local AllStructures = util.GetStaticPropertyGetter( Rust.StructureMaster, "AllStructures") 
local getStructureMasterOwnerId = util.GetFieldGetter(Rust.StructureMaster, "ownerID", true)
local FindByClass = util.GetStaticMethod( UnityEngine.Resources._type, "FindObjectsOfTypeAll" )
local CloseAllSleepers = util.FindOverloadedMethod( Rust.SleepingAvatar, "CloseAll", bf.public_static, { System.Boolean, System.Boolean } )
local GetComponents, SetComponents = typesystem.GetField( Rust.StructureMaster, "_structureComponents", bf.private_instance )
local getdecay, setdecay = typesystem.GetField( Rust.StructureMaster, "_decayDelayRemaining", bf.private_instance )
local NetCullRemove = util.FindOverloadedMethod(Rust.NetCull._type, "Destroy", bf.public_static, {UnityEngine.GameObject})
local UseExitReason = new( cs.gettype( "UseExitReason, Assembly-CSharp" ) )

function PLUGIN:Init()
	self:AddChatCommand( "cleanup", self.cmdCleanup )
	self:AddCommand( "clean", "all", self.ccmdCleanAll)
	self.CleanInfo = {}
	self.Timers = {}
end

local function GetOneConnectedFoundations( master )
	local hashset = GetComponents( master )
    local tbl = {}
    local it = hashset:GetEnumerator()
    while (it:MoveNext()) do
		if(string.find(tostring(it.Current.name), "Foundation")) then
			return it.Current
		end
    end
	return false
end
function RemoveObject(object)
    local objs = util.ArrayFromTable(cs.gettype("System.Object"), {object})
    cs.convertandsetonarray( objs, 0, object , UnityEngine.GameObject._type )
    NetCullRemove:Invoke(nil, objs) 
end
local function GetConnectedComponentsAndRemove( master )
    local hashset = GetComponents( master )
    local it = hashset:GetEnumerator()
	local tbl = {}
	local count = 0
	count = hashset.Count
	while (it:MoveNext()) do
		table.insert(tbl,it.Current.GameObject)
	end
	for i=1, #tbl do
		RemoveObject(tbl[i])
	end
	return count
end

function PLUGIN:TimeLeftBeforeCleanup(timeleft)
	if(self.Timer) then self.Timer:Destroy() end
	if(timeleft <= 0) then
		for i=0, AllStructures().Count-1 do
			if(tostring(getdecay(AllStructures()[i])) == "0") then
				local foundation = GetOneConnectedFoundations( AllStructures()[i] )
				if(foundation) then
					table.insert(self.CleanInfo.structures, AllStructures()[i])
				end
			end
		end
		rust.BroadcastChat("SERVER MAINTENANCE","Removing all decaying buildings (" .. (#self.CleanInfo.structures)/4 .. "s)")
		print("SERVER MAINTENANCE: Removing all decaying buildings (" .. (#self.CleanInfo.structures)/4 .. "s)")
		self:RemoveAllDecayingHouses(1)
		return
	elseif(timeleft <= 10) then
		rust.BroadcastChat("SERVER MAINTENANCE","Timeleft before maintenance: " .. timeleft .. " seconds")
		if(timeleft == 10) then
			print("SERVER MAINTENANCE: Timeleft before maintenance: " .. timeleft .. " seconds")
		end
		self.Timer = timer.Once( 1, function() self:TimeLeftBeforeCleanup(timeleft-1) end)
	else
		self.Timer = timer.Once( 1, function() self:TimeLeftBeforeCleanup(timeleft-1) end)
	end
	return
end
function PLUGIN:ccmdCleanAll( arg )
	local user = arg.argUser
	if (user and not self:isAdmin(user)) then return end
	if(self.Timer) then self.Timer:Destroy() end
	local args = self:makeargs(arg.ArgsStr)
	local thenum = 30
	if(args[1] and tonumber(args[1]) ~= nil and tonumber(args[1]) >= 0) then
		thenum = tonumber(args[1])
	end
	self.CleanInfo = {}
	self.CleanInfo.structures = {}
	self.CleanInfo.removed = {}
	self.CleanInfo.removed.structures = 0
	self.CleanInfo.removed.bags = 0
	self.CleanInfo.removed.sleepers = 0
	self.CleanInfo.theuser = false
	rust.BroadcastChat("SERVER MAINTENANCE","Server is going to do a maintenance in " .. thenum .. " seconds")
	rust.BroadcastChat("SERVER MAINTENANCE","All Sleepers / Decaying Buildings / Bags will be cleaned up, This is NOT a server restart")
	print("SERVER MAINTENANCE: Server maintenance in " .. thenum .. " seconds")
	self.Timer = timer.Once( 1, function() self:TimeLeftBeforeCleanup(thenum) end)
end
function PLUGIN:cmdCleanup(netuser, cmd, args)
	if(not netuser:CanAdmin()) then return end
	if(self.Timer) then self.Timer:Destroy() end
	local timeuntilm = 30
	if(args[1]) then
		if(tonumber(args[1]) == 0) then
			self:CancelCleanup()
			return
		end
		timeuntilm = tonumber(args[1])
	end
	self.CleanInfo = {}
	self.CleanInfo.structures = {}
	self.CleanInfo.removed = {}
	self.CleanInfo.removed.structures = 0
	self.CleanInfo.removed.bags = 0
	self.CleanInfo.removed.sleepers = 0
	self.CleanInfo.theuser = netuser
	rust.BroadcastChat("SERVER MAINTENANCE","Server is going to do a maintenance in " .. timeuntilm .. " seconds")
	rust.BroadcastChat("SERVER MAINTENANCE","All Sleepers / Decaying Buildings / Bags will be cleaned up")
	print("SERVER MAINTENANCE: Server maintenance in " .. timeuntilm .. " seconds")
	self.Timer = timer.Once( 1, function() self:TimeLeftBeforeCleanup(timeuntilm) end)
end

function PLUGIN:RemoveAllDecayingHouses(current)
	if(self.Timer) then self.Timer:Destroy() end
	if(not self.CleanInfo.structures[current]) then
		self:RemoveBags()
		return
	end
	local structureOwnerId = getStructureMasterOwnerId(self.CleanInfo.structures[current])
	count = GetConnectedComponentsAndRemove( self.CleanInfo.structures[current] )
	self.CleanInfo.removed.structures = self.CleanInfo.removed.structures + count
	self.Timer = timer.Once( 0.25, function() self:RemoveAllDecayingHouses(current+1) end )
end
function PLUGIN:RemoveBags()
	if(self.Timer) then self.Timer:Destroy() end
	rust.BroadcastChat("SERVER MAINTENANCE","Removing all bags")
	print("SERVER MAINTENANCE: Removing all bags")
	local Objects = FindByClass( Rust.LootableObject._type )
	local count = 0
	for i = 0, tonumber( Objects.Length - 1 ) do
		local LootableObject = Objects[ i ];
		local objType = tostring( LootableObject.Name )
		if objType == 'LootSack(Clone)' then
			count = count + 1
			RemoveObject( LootableObject )
		end
	end
	self.CleanInfo.removed.bags = count
	self:CleanSleepers()
end
function PLUGIN:CleanSleepers()
	if(self.Timer) then self.Timer:Destroy() end
	rust.BroadcastChat("SERVER MAINTENANCE","Removing all sleepers")
	print("SERVER MAINTENANCE: Removing all sleepers")
	local firstarg = false
	local secondarg = true
	local arr = util.ArrayFromTable( System.Object, { firstarg, secondarg } , 2 )
	cs.convertandsetonarray( arr, 0, firstarg, System.Boolean._type )
	cs.convertandsetonarray( arr, 1, secondarg, System.Boolean._type )
	CloseAllSleepers:Invoke(nil, arr)
	self:EndCleanUp()
end
function PLUGIN:EndCleanUp()
	if(self.Timer) then self.Timer:Destroy() end
	rust.BroadcastChat("SERVER MAINTENANCE","Maintenance is now over! Thank you for your patience")
	print("SERVER MAINTENANCE: Maintenance is now over!")
	if(self.CleanInfo.theuser) then
		local netuser = self.CleanInfo.theuser
		rust.SendChatToUser(netuser,"SERVER MAINTENANCE",self.CleanInfo.removed.structures .. " structure elements were removed")
		rust.SendChatToUser(netuser,"SERVER MAINTENANCE",self.CleanInfo.removed.bags .. " bags were removed")
		rust.SendChatToUser(netuser,"SERVER MAINTENANCE","Sleepers were all removed")
	end
	print("SERVER MAINTENANCE: "..self.CleanInfo.removed.structures .. " structure elements were removed")
	print("SERVER MAINTENANCE: "..self.CleanInfo.removed.bags .. " bags were removed")
	print("SERVER MAINTENANCE: Sleepers were all removed")
	self.CleanInfo = {}
end
function PLUGIN:CancelCleanup()
	if(self.Timer) then
		rust.BroadcastChat("SERVER MAINTENANCE","Maintenance was cancelled by the admin")
		print("SERVER MAINTENANCE: Maintenance was cancelled by the admin")
		self.Timer:Destroy()
	end
	self.CleanInfo = {}
end
function PLUGIN:Unload()
	if(self.Timer) then
		self.Timer:Destroy()
		error("Plugin was reloaded while cleaning you: Clean Up STOPED and CANCELLED")
	end
end

function PLUGIN:makeargs(msg)
	local args = {}
	for arg in msg:gmatch( "%S+" ) do
		args[ #args + 1 ] = arg
	end

	-- Loop each argument and merge arguments surrounded by double quotes
	local newargs = {}
	local inlongarg = false
	local longarg = ""
	for i=1, #args do
		local str = args[i]
		local l = str:len()
		local handled = false
		if (l > 1) then
			if (str:sub( 1, 1 ) == "\"") then
				inlongarg = true
				longarg = longarg .. str .. " "
				handled = true
			end
			if (str:sub( l, l ) == "\"") then
				inlongarg = false
				if (not handled) then longarg = longarg .. str .. " " end
				newargs[ #newargs + 1 ] = longarg:sub( 2, longarg:len() - 2 )
				longarg = ""
				handled = true
			end
		end
		if (not handled) then
			if (inlongarg) then
				longarg = longarg .. str .. " "
			else
				newargs[ #newargs + 1 ] = str
			end
		end
	end
	return newargs
end