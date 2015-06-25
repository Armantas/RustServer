--[[
//////////////////////////////////////////////////////////////////////
// d-RestartKit - Written by DanSteph 
//
// http://forum.rustoxide.com/resources/d-restartkit.635
// http://orbiter.dansteph.com 
//////////////////////////////////////////////////////////////////////--]]

PLUGIN.Title       = "d-RestartKit"
PLUGIN.Description = "Allow VIP users (paypal or other) to get restart kit after wipe without any admin intervention. Admin and user friendly plugin"
PLUGIN.Author      = "DanSteph"
PLUGIN.Version     = "1.1.0" 
PLUGIN.RID		   = "635"

------------------------------------
-- Init()
------------------------------------
function PLUGIN:Init()
    print( self.Title .. " v" .. self.Version .. ": starting..." )
    --Somes variables
    g_cNameOfKitReadable=""
    g_iNbrKitsAvailable=0
    g_tblKitIndex={}
    g_tblKitInverseIndex={}
    g_tblHelpNameKit={}
    --Load cfg
    self:LoadCFG()
    -- Setup
    self:SetupDatabase()
    self:AddCommand(     "restartkit", "help", self.cmdconsolehelp )
    self:AddCommand(     "restartkit", "adduser", self.cmdconsoleadduser)
    self:AddCommand(     "restartkit", "deleteuser", self.cmdconsoledeleteuser)
    self:AddCommand(     "restartkit", "displayuser", self.cmdconsoledisplayuser)
    self:AddCommand(     "restartkit", "giveagain", self.cmdconsolegiveagain)
    self:AddCommand(     "restartkit", "listusers", self.cmdconsolelistuser)
    self:AddCommand(     "restartkit", "listkits", self.cmdconsolelistkist)
    self:AddCommand(     "restartkit", "resetafterwipe", self.cmdconsoleresetafterwipe)
    self:AddCommand(     "restartkit", "DELETEALLDATABASES", self.cmdconsoledeletealldatabases)
    self:AddChatCommand( "restartkit", self.cmdrestartkit )
    self.timer = {}
    oxmin_plugin = plugins.Find("oxmin")
    if ( not oxmin_plugin ) then
        self.oxmin = false
    else
        self.oxmin = true
        self.FLAG_cangive = oxmin.AddFlag("cangive")
    end
    -- check data sanity ----------------------------------------------
    -- check kit declaration valid
    if(self.Config.KitsDeclaration==nil) then 
        error("Error with declaration of kits in 'cfg_restartkit.txt': Bad syntax in kit declaration")
        self.bInitOk=false
        goto endinit
    end
    -- check number of kits declared
    g_iNbrKitsAvailable=self:tablelength(self.Config.KitsDeclaration)
    if(g_iNbrKitsAvailable<1) then
        error("Error with declaration of kits in 'cfg_restartkit.txt': Zero kit declared (or bad syntax?)")
        self.bInitOk=false
        goto endinit
    end
    -- check sanity of kits declared
    for i,value in pairs(self.Config.KitsDeclaration) do 
        if string.find(self.Config.KitsDeclaration[i][1],"NameOfKit:") then 
            local cNameOfKit=self:ExtractKitName(self.Config.KitsDeclaration[i][1])
            if(cNameOfKit~="") then
                if(g_cNameOfKitReadable=="") then
                    g_cNameOfKitReadable=cNameOfKit
                else
                   g_cNameOfKitReadable=g_cNameOfKitReadable..", "..cNameOfKit
                end
                g_tblKitIndex[cNameOfKit]=i
                g_tblKitInverseIndex[i]=cNameOfKit
                g_tblHelpNameKit[i]=cNameOfKit
                g_tblHelpNameKit[i+1]=cNameOfKit
                g_tblHelpNameKit[i+2]=cNameOfKit
                g_tblHelpNameKit[i+3]=cNameOfKit
            else
                error("Error with declaration of kits in 'cfg_restartkit.txt': bad name of kit: in kit: "..i)
                self.bInitOk=false
                goto endinit
            end
        else
            error("Error with declaration of kits in 'cfg_restartkit.txt': Missing 'NameOfKit:' in kit: "..i)
            self.bInitOk=false
            goto endinit
        end
    end
    print("Name of kits:"..g_cNameOfKitReadable)
    print("Nbr of kits:"..g_iNbrKitsAvailable)

    -- End check data sanity ----------------------------------------------
::endinit::
    -- Msg initialization
    if(self.bInitOk==true) then
        print( self.Title .. " v" .. self.Version .. ": successfully initialized!" )
    else
        error( self.Title .. " v" .. self.Version .. ": ERROR in config file - All functions disabled !" )
        error( "Correct or delete the config file 'cfg_restartkit.txt' and reload 'd-RestartKit' plugin to cure the problem" )
    end
    -- test flags
    bFlagIsBetaTest=false	-- Beta test flag for local test on local server (own PC).
                            -- This switch simulate many fake users for the search by name functions
                            -- as the author's test server had only a very few players.
                            -- Set this value to false before using this plugin on a game server.
    if(bFlagIsBetaTest==true) then
        print( "***********************************************************************" )
        print( "RESTARTKIT WARNING TEST SWITCH ON !!!! DO NOT USE ON REAL GAME SERVER !" )
        print( "This switch simulate many fake users for the search functions" )
        print( "as the author's test server had only a very few players." )
        print( "Set the value \"bFlagIsBetaTest\" to \"false\" in code before" )
        print( "using this plugin on a real game server." )
        print( "***********************************************************************" )
    end

end

------------------------------------
-- SetupDatabase()
------------------------------------
function PLUGIN:SetupDatabase()
    self.PlayerData = util.GetDatafile( "db_restartkit" )
    if (self.PlayerData:GetText() == "") then
        self.PData = {}
    else
        self.PData = json.decode( self.PlayerData:GetText() )
        if (not self.PData) then
            error( "json decode error in db_restartkit.txt" )
            self.PData = {}
        end
    end
    self.WipeData = util.GetDatafile( "db_restartkitflags" )
    if (self.WipeData:GetText() == "") then
        self.WData = {}
    else
        self.WData = json.decode( self.WipeData:GetText() )
        if (not self.WData) then
            error( "json decode error in db_restartkitflags.txt" )
            self.WData = {}
        end
    end
end

------------------------------------
-- LoadCFG()
------------------------------------
function PLUGIN:LoadCFG()
    self.bInitOk=false
    local b, res = config.Read( "restartkit" )
    self.Config = res or {}
    if (not b or not self.Config.Version or ( self.Config.Version and self.Config.Version ~= "1.1.0")) then
        if(self.Config.Version == "1.0.0") then print("restartkit: Found old configuration version 1.0.0, replacing with new one 1.1.0") end
        print("restartkit: Loading Default Configs")
        self:LoadDefaultCFG()
    end
    if(self.Config.Version == "1.1.0") then
        self.bInitOk=true
    end
end

------------------------------------
-- LoadDefaultCFG()
------------------------------------
function PLUGIN:LoadDefaultCFG()
    -- This trick below is to ensure a perfect indenting and readability of the config file ;)
    local IndentConfigText=[[{
   "ChatMsgColor":   "[color #33FFFF]",
   "ChatCmdColor":   "[color #33FF33]",
   "MessageBuy":     "To buy restart kit visit toprustservers.com/server/example",
   "MessageBuyChat1":"You didn't buy a restart kit yet",
   "MessageBuyChat2":"To buy restart kit with C4,M4,kevlar,wood,metal etc. visit: toprustservers.com/server/example",
   "MessageBuyChat3":"To see what are in the kits, type '/restartkit help'",
   "MessageThanks":  "Thank for your purchase, ",

   "MessageThanks1": "Make SURE you are at a safe location then type: ",
   "MessageClaim":   "'/restartkit now' to receive your kit",
   "MessageEmpty":   "Your inventory must be completely empty before getting items (including belt)",
   "MessageEmpty1":  "Empty your inventory and retype '/restartkit now'",
   "InventoryFull":  "Inventory FULL ! Empty it and retype: '/restartkit now'",
   "MsgNotComplete": "Empty inventory and retype: '/restartkit now'!",
   "MessageDonated": "You got the restart kit - Enjoy :)",
   "MessageAlready": "You already received the kit, wait for the next wipe to get one again",
   "MessageAlready1":"If you got raided within 24h after the wipe and lost your stuff, ask an admin",

   "KitsDeclaration":{
                     ["NameOfKit: 'big'    <-Kit's name. Between quote, lower case and without space",
                      "Large Wood Storage:5",
                      "Low Quality Metal:4000",
                      "Kevlar Helmet:2",
                      "Kevlar Vest:2",
                      "Kevlar Pants:2",
                      "Kevlar Boots:2",
                      "Supply Signal:4",
                      "Explosive Charge:20",
                      "M4:2",
                      "556 Ammo:500",
                      "9mm Ammo:250",
                      "Shotgun Shells:250",
                      "Metal Door:5",
                      "Large Medkit:10",
                      "Research Kit 1:5"],

                     ["NameOfKit: 'medium'    <-Kit's name. Between quote, lower case and without space",
                     "Large Wood Storage:3",
                      "Wood Planks:4000",
                      "Kevlar Helmet:2",
                      "Kevlar Vest:2",
                      "Kevlar Pants:2",
                      "Kevlar Boots:2",
                      "Supply Signal:4",
                      "Explosive Charge:20",
                      "M4:2",
                      "556 Ammo:500",
                      "Metal Door:5",
                      "Large Medkit:10",
                      "Research Kit 1:5"],

                      ["NameOfKit: 'small'    <-Kit's name. Between quote, lower case and without space",
                      "Large Wood Storage:2",
                      "Wood Planks:2000",
                      "Leather Helmet:2",
                      "Leather Vest:2",
                      "Leather Pants:2",
                      "Leather Boots:2",
                      "Supply Signal:2",
                      "Explosive Charge:10",
                      "M4:1",
                      "556 Ammo:250"],
                      },
   "Version":"1.1.0"}]]

    -- This trick below is to ensure a perfect indenting and readability of the config file ;)
    local TableConfig={}
    TableConfig=self:explode(IndentConfigText,"\n")
    local logFile=util.GetDatafile( "cfg_restartkit" )
    logFile:SetText(table.concat(TableConfig, '\r\n'));
    logFile:Save();

    local b, res = config.Read( "restartkit" )
    self.Config = res or {}
    if (not b or not self.Config.Version or ( self.Config.Version and self.Config.Version ~= "1.1.0")) then
        print("CRITICAL ERROR CREATING AND READING DEFAULT CONFIG FILE")
    end
end

------------------------------------
-- cmdconsolehelp
------------------------------------
function PLUGIN:cmdconsolehelp( arg )
    local netuser = arg.argUser
    local sendto = 'console'
    if netuser then sendto = 'echo' end
    if ( netuser and not self:CanUserAdmin( netuser ) ) then
        local msg="Error, only admin can do this command"
        self:msgPrint( netuser, msg, sendto )
        return false
    end
    if(self.bInitOk==false) then
        self:msgPrint( netuser,"ERROR in config file - All functions disabled !", sendto )
        self:msgPrint( netuser,"Try to correct or delete the file 'cfg_restartkit.txt' and reload 'RestartKit' plugin", sendto )
        return true
    end
    self:msgPrint( netuser,"------------------------------------------------------", sendto )
    self:msgPrint( netuser,"RestartKit Help", sendto )
    self:msgPrint( netuser,"------------------------------------------------------", sendto )
    self:msgPrint( netuser,"RestartKit add easy and automatic kit donation after wipe based on", sendto )
    self:msgPrint( netuser,"your list of people that bought them on paypal or got them by any", sendto )
    self:msgPrint( netuser,"other rewards. For configuration see 'data/cfg_restartkit.txt'" , sendto )
    self:msgPrint( netuser,"and help at: 'forum.rustoxide.com/resources/d-restartkit.635'.", sendto )
    self:msgPrint( netuser,"                                                                  .", sendto )
    self:msgPrint( netuser,"Admin commands in console:", sendto )
    self:msgPrint( netuser,"-------------------------------", sendto )
    self:msgPrint( netuser,"restartkit.adduser", sendto )
    self:msgPrint( netuser,"restartkit.deleteuser", sendto )
    self:msgPrint( netuser,"restartkit.displayuser", sendto )
    self:msgPrint( netuser,"restartkit.giveagain", sendto )
    self:msgPrint( netuser,"restartkit.listusers", sendto )
    self:msgPrint( netuser,"restartkit.listkits", sendto )
    self:msgPrint( netuser,"restartkit.resetafterwipe", sendto )
    self:msgPrint( netuser,"restartkit.DELETEALLDATABASES", sendto )
    self:msgPrint( netuser,"                                                                  .", sendto )
    self:msgPrint( netuser,"Command in chat available to users:", sendto )
    self:msgPrint( netuser,"---------------------------------------", sendto )
    self:msgPrint( netuser,"/restartkit", sendto )
    self:msgPrint( netuser,"                                                                  .", sendto )
    self:msgPrint( netuser,"Note: You can safely type all commands without parameters", sendto )
    self:msgPrint( netuser,"to display their help. (Even 'DELETEALLDATABASES)'", sendto )
    self:msgPrint( netuser,"Note2: Commands also accept user's name instead of it's SteamID64", sendto )
    self:msgPrint( netuser,"(Partial and case insensitive search available)", sendto )
    return true
end

------------------------------------
-- cmdconsoleadduser
------------------------------------
function PLUGIN:cmdconsoleadduser( arg )
    local netuser = arg.argUser
    local sendto = 'console'
    if netuser then sendto = 'echo' end
    if ( netuser and not self:CanUserAdmin( netuser ) ) then
        local msg="Error, only admin can do this command"
        self:msgPrint( netuser, msg, sendto )
        return true
    end
    if(self.bInitOk==false) then
        self:msgPrint( netuser,"ERROR in config file - All functions disabled !", sendto )
        self:msgPrint( netuser,"Try to correct or delete the file 'cfg_restartkit.txt' and reload 'd-RestartKit' plugin", sendto )
        return true
    end

    local cSteamId64 = tostring( arg:GetString( 0, "text" ) )
    local cKeyword = tostring( arg:GetString( 1, "text" ) )
    if cSteamId64 == "text" or cKeyword == "text" then
        self:msgPrint( netuser,"Error: missing one or wrong parameter", sendto )
        self:msgPrintHelpCommand(netuser,'adduser',sendto)
    return true
    end

    -- this is a research by name
    -- return 1-if it's a name search (true/false)
    --        2-the number found (numeric)
    --        3-the steam ID associated (if 1 result)
    --		  4-the name found  (if 1 result)
    --		  5-a table with all the full names (if more than one result)
    -- this is a research by name
    local strSearch=cSteamId64
    local bIsByName,iNumberFound,NameSteamId64,sFoundName,tblAllFoundName=self:IAdvancedSearchUserByName(cSteamId64)
    if(bIsByName==true) then
        if(iNumberFound<0) then
           self:msgPrint( netuser,"Error, search string is less than 2 chars or more than 20 chars", sendto )
           self:msgPrint( netuser,"Please retry", sendto )
           return true
        elseif(iNumberFound>1) then
           self:msgPrint( netuser,"Too much users ("..iNumberFound..") match this search ("..strSearch.."), please refine", sendto )
           self:msgPrint( netuser,"Matching results:", sendto )
           for i,name in ipairs(tblAllFoundName) do
                self:msgPrint( netuser,"   "..i.."- "..name, sendto )
           end 
           return true
        elseif (iNumberFound==0) then
             self:msgPrint( netuser,"No user matches this search !", sendto )
             self:msgPrint( netuser,"Not online actually and/or user registered with another name or with steamid only (searched in db and online users))", sendto )
             return true
        end
        cSteamId64=NameSteamId64
    end

    if string.len(cSteamId64)~=17 then
        self:msgPrint( netuser,"Error: the SteamID64 must be 17 char length", sendto )
        self:msgPrintHelpCommand(netuser,'adduser',sendto)
        return true
    end

    local iKitType=g_tblKitIndex[cKeyword]
    if ( iKitType == nil) then
        local cKitHelp=string.gsub(g_cNameOfKitReadable,", "," or ")
        self:msgPrint( netuser,"Wrong keyword for kit's type (should be: "..cKitHelp..")", sendto )
        self:msgPrintHelpCommand(netuser,'adduser',sendto)
        return true
    end

    local userid=cSteamId64
    local data = self.PData[ userid ]
    if (not data) then
        data = {}
        self.PData[ userid ] = data
    end
    local respawn = "KitType"
    data[ respawn ] = iKitType
    if(bIsByName==true) then
       data[ "Name" ]=sFoundName
    elseif not data["Name"] then
       data["Name"]=" "
       sFoundName="(no name entered)"
    end
    data["Registered"]=System.DateTime.Now:ToString("dd/MM/yyyy HH:mm")
    -- reserve for future update so databases are still compatibles
    data["DataOne"]=""
    data["DataTwo"]=""
    data["DataThree"]=""
    data["DataFour"]=""
    data["Email"]=""
    data["ID"]=""
    data["Forum"]=""
    -- end
    self.PlayerData:SetText( json.encode( self.PData ) )
    self.PlayerData:Save()
    -- self:SetupDatabase()
    self:msgPrint( netuser,"Ok, user '"..sFoundName.."'   (steamid: "..cSteamId64.. ") added in database.", sendto )
    if(sFoundName=="(no name entered)") then
        self:msgPrint( netuser,"NOTE: this user's name will be automatically added the next time he will claim his kit.", sendto )
    end
    return true
end

------------------------------------
-- cmdconsoledeleteuser
------------------------------------
function PLUGIN:cmdconsoledeleteuser( arg )
    local netuser = arg.argUser
    local sendto = 'console'
    if netuser then sendto = 'echo' end
    if ( netuser and not self:CanUserAdmin( netuser ) ) then
        local msg="Error, only admin can do this command"
        self:msgPrint( netuser, msg, sendto )
        return true
    end
    if(self.bInitOk==false) then
        self:msgPrint( netuser,"ERROR in config file - All functions disabled !", sendto )
        self:msgPrint( netuser,"Try to correct or delete the file 'cfg_restartkit.txt' and reload 'd-RestartKit' plugin", sendto )
        return true
    end

    local cSteamId64 = tostring( arg:GetString( 0, "text" ) )
    if cSteamId64 == "text" then
        self:msgPrint( netuser,"Error: missing one or wrong parameter", sendto )
        self:msgPrintHelpCommand(netuser,'deleteuser',sendto)
        return true
    end

    -- return 1-if it's a name search (true/false)
    --        2-the number found (numeric)
    --        3-the steam ID associated (if 1 result)
    --		  4-the name found  (if 1 result)
    --		  5-a table with all the full names (if more than one result)
    -- this is a research by name
    local strSearch=cSteamId64
    local bIsByName,iNumberFound,NameSteamId64,sFoundName,tblAllFoundName=self:IAdvancedSearchUserByName(cSteamId64)
    if(bIsByName==true) then
        if(iNumberFound<0) then
           self:msgPrint( netuser,"Error, search string is less than 2 chars or more than 20 chars", sendto )
           self:msgPrint( netuser,"Please retry", sendto )
           return true
        elseif(iNumberFound>1) then
           self:msgPrint( netuser,"Too much users ("..iNumberFound..") match this search ("..strSearch.."), please refine", sendto )
           self:msgPrint( netuser,"Matching results:", sendto )
           for i,name in ipairs(tblAllFoundName) do
                self:msgPrint( netuser,"   "..i.."- "..name, sendto )
           end 
           return true
        elseif (iNumberFound==0) then
             self:msgPrint( netuser,"No user matches this search !", sendto )
             self:msgPrint( netuser,"Not online actually and/or user registered with another name or with steamid only (searched in db and online users)", sendto )
             return true
        end
        cSteamId64=NameSteamId64
    end

    if string.len(cSteamId64)~=17 then
        print(cSteamId64)
        self:msgPrint( netuser,"Error: the SteamID64 must be 17 char length", sendto )
        self:msgPrintHelpCommand(netuser,'deleteuser',sendto)
        return true
    end

    local userid=cSteamId64
    local data = self.PData[ userid ]
    if (not data) then
        local msg="User "..sFoundName.." "..cSteamId64.. " not found in database."
        self:msgPrint( netuser, msg, sendto )
    return true
    end
    self.PData[ userid ]=nil;
    self.PlayerData:SetText( json.encode( self.PData ) )
    self.PlayerData:Save()
    -- self:SetupDatabase()
    local msg="Ok, user "..sFoundName.." "..cSteamId64.. " deleted from database."
    self:msgPrint( netuser, msg, sendto )
    return true
end

------------------------------------
-- iFindOnlineUserByName - case insensitive and partial search
------------------------------------
function PLUGIN:iFindOnlineUserByName(searchUser)
        local iFoundStmID64=0
        searchUser=string.lower(searchUser)
        local iNbrFound=0
        local tblNetUserFound={}
        local tblNameFound={}
        for _, netuser in pairs( rust.GetAllNetUsers() ) do
            if string.find(string.lower(netuser.displayName),searchUser) then 
                tblNetUserFound[iNbrFound+1]=netuser
                tblNameFound[iNbrFound+1]=netuser.displayName
                iNbrFound=iNbrFound+1
            end
        end
        if(iNbrFound==1) then
            iFoundStmID64=rust.GetLongUserID(tblNetUserFound[1])
        end
        return iNbrFound,iFoundStmID64,tblNetUserFound,tblNameFound
end

------------------------------------
-- IAdvancedSearchUserByName - case insensitive and partial search, online and in database
-- return 1-if it's a name search (true/false)
--        2-the number found (numeric)
--        3-the steam ID associated (if 1 result)
--		  4-the name found  (if 1 result)
--		  5-a table with all the full names (if more than one result)
--
--	      return -1 if less than two or more than 20 chars
------------------------------------
function PLUGIN:IAdvancedSearchUserByName(strSteam64ID)
    local iFoundStmID64=0
    local sFoundName=""
    local tFoundAllNames={}
    -- is it a research by name ?
    if(string.find(tostring(strSteam64ID), "'")==nil) then
        return false,0,iFoundStmID64,sFoundName,tFoundAllNames
    end
    -- extract name, make it lower for case insensitive comparison
    local strSearch=string.lower(strSteam64ID:gsub("'",""))
    -- check sanity
    if( string.len(strSearch)<2 or string.len(strSearch)>20) then
        return true,-1,iFoundStmID64,sFoundName,tFoundAllNames
    end
    -- search user online
    if(bFlagIsBetaTest==true) then
        iNbrUserFound,iFoundStmID64,ptrNetUser,tFoundAllNames=self:TEST_iFindOnlineUserByName( strSearch )
    else
        iNbrUserFound,iFoundStmID64,ptrNetUser,tFoundAllNames=self:iFindOnlineUserByName( strSearch )
    end
    -- only one user found, okay return
    if(iNbrUserFound==1) then
        sFoundName=tFoundAllNames[1]
        return true,iNbrUserFound,iFoundStmID64,sFoundName,tFoundAllNames
    end
    -- multiple users found online, not good, return all usernames found for display
    if(iNbrUserFound>1) then
        return true,iNbrUserFound,iFoundStmID64,sFoundName,tFoundAllNames
    end
    -- no user found online, search in db
    local tblSteamId64={}
    for i,cRustItem in pairs(self.PData) do
        if string.find(string.lower(cRustItem["Name"]),strSearch) then 
            tFoundAllNames[iNbrUserFound+1]=cRustItem["Name"]
            tblSteamId64[iNbrUserFound+1]=i
            iNbrUserFound=iNbrUserFound+1
        end
    end
    -- only one user found, okay return
    if(iNbrUserFound==1) then
        iFoundStmID64=tblSteamId64[1]
        sFoundName=tFoundAllNames[1]
        return true,iNbrUserFound,iFoundStmID64,sFoundName,tFoundAllNames
    end
    if(iNbrUserFound>1) then
        return true,iNbrUserFound,iFoundStmID64,sFoundName,tFoundAllNames
    end
    -- zero found
    return true,0,"","",tFoundAllNames
end

------------------------------------
-- cmdconsoledisplayuser
------------------------------------
function PLUGIN:cmdconsoledisplayuser( arg )
    local netuser = arg.argUser
    local sendto = 'console'
    if netuser then sendto = 'echo' end
    if ( netuser and not self:CanUserAdmin( netuser ) ) then
        local msg="Error, only admin can do this command"
        self:msgPrint( netuser, msg, sendto )
        return true
    end
    if(self.bInitOk==false) then
        self:msgPrint( netuser,"ERROR in config file - All functions disabled !", sendto )
        self:msgPrint( netuser,"Try to correct or delete the file 'cfg_restartkit.txt' and reload 'd-RestartKit' plugin", sendto )
        return true
    end

    local cSteamId64 = tostring( arg:GetString( 0, "text" ) )
    if cSteamId64 == "text" then
        self:msgPrint( netuser,"Error: missing one or wrong parameter", sendto )
        self:msgPrintHelpCommand(netuser,'displayuser',sendto)
        return true
    end

    -- return 1-if it's a name search (true/false)
    --        2-the number found (numeric)
    --        3-the steam ID associated (if 1 result)
    --		  4-the name found  (if 1 result)
    --		  5-a table with all the full names (if more than one result)
    -- this is a research by name
    local strSearch=cSteamId64
    local bIsByName,iNumberFound,NameSteamId64,sFoundName,tblAllFoundName=self:IAdvancedSearchUserByName(cSteamId64)
    if(bIsByName==true) then
        if(iNumberFound<0) then
           self:msgPrint( netuser,"Error, search string is less than 2 chars or more than 20 chars", sendto )
           self:msgPrint( netuser,"Please retry", sendto )
           return true
        elseif(iNumberFound>1) then
           self:msgPrint( netuser,"Too much users ("..iNumberFound..") match this search ("..strSearch.."), please refine", sendto )
           self:msgPrint( netuser,"Matching results:", sendto )
           for i,name in ipairs(tblAllFoundName) do
                self:msgPrint( netuser,"   "..i.."- "..name, sendto )
           end 
           return true
        elseif (iNumberFound==0) then
             self:msgPrint( netuser,"No user matches this search !", sendto )
             self:msgPrint( netuser,"Not online actually and/or user registered with another name or with steamid only (searched in db and online users)", sendto )
             return true
        end
        cSteamId64=NameSteamId64
    end

    if string.len(cSteamId64)~=17 then
        self:msgPrint( netuser,"Error: the SteamID64 must be 17 char length", sendto )
        self:msgPrintHelpCommand(netuser,'displayuser',sendto)
        return true
    end

    local userid=cSteamId64
    local data = self.PData[ userid ]
    if (not data) then
        if(bIsByName==true) then
            self:msgPrint( netuser,"User '"..sFoundName.. "' isn't registered for a kit. Use 'restartkit.adduser'", sendto )
        else
            self:msgPrint( netuser,"User '"..cSteamId64.. "' isn't registered for a kit. Use 'restartkit.adduser'", sendto )
        end
        return true
    end
    if(bIsByName==true) then
        self:msgPrint( netuser,"User's name: "..sFoundName, sendto )
    elseif(data["Name"]~="") then
        self:msgPrint( netuser,"User's name: "..data["Name"], sendto )
    else
        self:msgPrint( netuser,"User's name: not available (user was added by steamId and he's not online actually)", sendto )
    end
    self:msgPrint( netuser,"User's Steam64ID: "..cSteamId64, sendto )
    self:msgPrint( netuser,"Registered: "..data["Registered"], sendto )

    local cKitName = g_tblKitInverseIndex[data["KitType"]]
    if(cKitName==nil) then
        cKitName="ERROR ! This kit doesn't exist anymore! Add this user again with a valid kit"
    end
    self:msgPrint( netuser,"Kit type: "..cKitName, sendto )
    -- search last claim
    data = self.WData[ userid ]
    if (not data) then
        self:msgPrint( netuser,"Last kit received: no kit received since the last wipe", sendto )
        return true
    end
    if(data["Partial"]~=9999) then
        self:msgPrint( netuser,"Last kit received: he got only a part, instruct him to redo a", sendto )
        self:msgPrint( netuser,"'/restartkit now'", sendto )
        return true
    end
    self:msgPrint( netuser,"Last kit received: "..data["Received"], sendto )
    return true
end

------------------------------------
-- cmdconsolegiveagain
------------------------------------
function PLUGIN:cmdconsolegiveagain( arg )
    local netuser = arg.argUser
    local sendto = 'console'
    if netuser then sendto = 'echo' end
    if ( netuser and not self:CanUserAdmin( netuser ) ) then
        local msg="Error, only admin can do this command"
        self:msgPrint( netuser, msg, sendto )
        return true
    end
    if(self.bInitOk==false) then
        self:msgPrint( netuser,"ERROR in config file - All functions disabled !", sendto )
        self:msgPrint( netuser,"Try to correct or delete the file 'cfg_restartkit.txt' and reload 'd-RestartKit' plugin", sendto )
        return true
    end

    local cSteamId64 = tostring( arg:GetString( 0, "text" ) )
    if cSteamId64 == "text" then
        self:msgPrint( netuser,"Error: missing one or wrong parameter", sendto )
        self:msgPrintHelpCommand(netuser,'giveagain',sendto)
    return true
    end

    -- return 1-if it's a name search (true/false)
    --        2-the number found (numeric)
    --        3-the steam ID associated (if 1 result)
    --		  4-the name found  (if 1 result)
    --		  5-a table with all the full names (if more than one result)
    -- this is a research by name
    local strSearch=cSteamId64
    local bIsByName,iNumberFound,NameSteamId64,sFoundName,tblAllFoundName=self:IAdvancedSearchUserByName(cSteamId64)
    if(bIsByName==true) then
        if(iNumberFound<0) then
           self:msgPrint( netuser,"Error, search string is less than 2 chars or more than 20 chars", sendto )
           self:msgPrint( netuser,"Please retry", sendto )
           return true
        elseif(iNumberFound>1) then
           self:msgPrint( netuser,"Too much users ("..iNumberFound..") match this search ("..strSearch.."), please refine", sendto )
           self:msgPrint( netuser,"Matching results:", sendto )
           for i,name in ipairs(tblAllFoundName) do
                self:msgPrint( netuser,"   "..i.."- "..name, sendto )
           end 
           return true
        elseif (iNumberFound==0) then
             self:msgPrint( netuser,"No user matches this search !", sendto )
             self:msgPrint( netuser,"Not online actually and/or user registered with another name or with steamid only (searched in db and online users)", sendto )
             return true
        end
        cSteamId64=NameSteamId64
    end

    if string.len(cSteamId64)~=17 then
        self:msgPrint( netuser,"Error: the SteamID64 must be 17 char length", sendto )
        self:msgPrintHelpCommand(netuser,'giveagain',sendto)
        return true
    end

    local userid=cSteamId64
    local data = self.PData[ userid ]
    if (not data) then
        local msg="User "..sFoundName.." "..cSteamId64.. " not found in database. He can't claim a kit."
        self:msgPrint( netuser, msg, sendto )
        return true
    end

    -- check this user
    local data = self.WData[ cSteamId64 ]
    if (not data) then
        self:msgPrint( netuser,"This user never claimed his kit after the last wipe. He can claim it now", sendto )
    return true
    end

    self.WData[ cSteamId64 ]=nil;
    self.WipeData:SetText( json.encode( self.WData ) )
    self.WipeData:Save()
    -- self:SetupDatabase()

    self:msgPrint( netuser,"Okay, this user can claim a new kit again", sendto )
    return true
end

------------------------------------
-- cmdconsolelistuser
------------------------------------
function PLUGIN:cmdconsolelistuser( arg )
    local netuser = arg.argUser
    local sendto = 'console'
    if netuser then sendto = 'echo' end
    if ( netuser and not self:CanUserAdmin( netuser ) ) then
        local msg="Error, only admin can do this command"
        self:msgPrint( netuser, msg, sendto )
        return true
    end
    if(self.bInitOk==false) then
        self:msgPrint( netuser,"ERROR in config file - All functions disabled !", sendto )
        self:msgPrint( netuser,"Try to correct or delete the file 'cfg_restartkit.txt' and reload 'd-RestartKit' plugin", sendto )
        return true
    end
     local iNbr=0
     local ItemTable=self.PData
     for i,cRustItem in pairs(ItemTable) do
        local cKitName = g_tblKitInverseIndex[cRustItem["KitType"]]
        if(cKitName==nil) then
            cKitName="(ERROR ! This kit doesn't exist anymore!)"
        end
        self:msgPrint( netuser," "..i.."  "..cKitName.."   "..cRustItem["Name"], sendto )
        iNbr=iNbr+1
    end
    self:msgPrint( netuser," ", sendto )
    self:msgPrint( netuser, iNbr.. " users listed", sendto )
    return true
end

------------------------------------
-- cmdconsolelistkist
------------------------------------
function PLUGIN:cmdconsolelistkist( arg )
    local netuser = arg.argUser
    local sendto = 'console'
    if netuser then sendto = 'echo' end
    if ( netuser and not self:CanUserAdmin( netuser ) ) then
        local msg="Error, only admin can do this command"
        self:msgPrint( netuser, msg, sendto )
        return true
    end
    if(self.bInitOk==false) then
        self:msgPrint( netuser,"ERROR in config file - All functions disabled !", sendto )
        self:msgPrint( netuser,"Try to correct or delete the file 'cfg_restartkit.txt' and reload 'd-RestartKit' plugin", sendto )
        return true
    end

    local tblListDKit=self:ReturnKitList()
    for i,value in pairs(tblListDKit) do 
        self:msgPrint( netuser,value, sendto )
    end
   
    return true
end

------------------------------------
-- ReturnKitList()
------------------------------------
function PLUGIN:ReturnKitList()
    -- display kits
    local cList=""
    local iNbr=1
    local tblListKit={}
    local iNbrRecordIntable=1
    for i,value in pairs(self.Config.KitsDeclaration) do 
        --self:msgPrint( netuser,"                                            .", sendto )
        tblListKit[iNbrRecordIntable]="."
        iNbrRecordIntable=iNbrRecordIntable+1
        for a,kit in pairs(value) do 
           if(a==1) then
                --self:msgPrint( netuser,g_tblKitInverseIndex[i], sendto )
                --self:msgPrint( netuser,"--------------", sendto )
                tblListKit[iNbrRecordIntable]=g_tblKitInverseIndex[i]
                iNbrRecordIntable=iNbrRecordIntable+1
                tblListKit[iNbrRecordIntable]="----------------"
                iNbrRecordIntable=iNbrRecordIntable+1
           else
                cName, iNumber = kit:match("([^,]+):([^,]+)")
                if(iNbr<3) then
                    cList=cList..iNumber.."x"..cName..", "
                else 
                    cList=cList..iNumber.."x"..cName
                    --self:msgPrint( netuser,cList, sendto )
                    tblListKit[iNbrRecordIntable]=cList
                    iNbrRecordIntable=iNbrRecordIntable+1
                    cList=""
                    iNbr=0
                end
                iNbr=iNbr+1;
            end
        end
    end
    return tblListKit
end

------------------------------------
-- cmdrestartkit()
------------------------------------
function PLUGIN:cmdrestartkit( netuser , cmd, args )

    if(self.bInitOk==false) then
        rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor("ERROR with initialisation and config file - Warn ADMIN !"))
        return true
    end

    -- check it's the "help" command or not
    if ( args[1] and tostring(args[1]) == "help") then
            
            local tblListDKit=self:ReturnKitList()
            for i,value in pairs(tblListDKit) do 
                rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor(value))
            end
        return
    end

    -- check this user have purchased the kit
    local userid=rust.GetLongUserID(netuser)
    local data = self.PData[ userid ]
    if (not data) or data[ "KitType" ] < 1 then
        rust.Notice( netuser, self.Config.MessageBuy )
        rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor(netuser.displayName ..", ".. self.Config.MessageBuyChat1 ))
        rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor("".. self.Config.MessageBuyChat2 ))
        rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor("".. self.Config.MessageBuyChat3 ))
        return
    end

    -- IF he was registered by steamID, his name is empty, time to fill this missing data
    -- or anyway to refresh his new eventual name
    if(data[ "Name" ]~=netuser.displayName) then
        data[ "Name" ]=netuser.displayName
        self.PlayerData:SetText( json.encode( self.PData ) )
        self.PlayerData:Save()
    end
    -- self:SetupDatabase()

    -- check the user already claimed it's kit
    local wdata = self.WData[ userid ]
    if (wdata) and not (wdata[ "Received" ] == "0") then
        rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor(netuser.displayName ..", "..self.Config.MessageAlready ))
        rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor("" .. self.Config.MessageAlready1 ))
        return
    end
    local iContinueAt=-1
    if (wdata) and (wdata[ "Partial" ] ~= 9999) then
        iContinueAt= wdata[ "Partial" ]
        iContinueAt=iContinueAt-1
    end

    -- check it's the full "now" command or not
    if ( not args[1] or tostring(args[1]) ~= "now") then
        rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor("".. self.Config.MessageThanks .. util.QuoteSafe(netuser.displayName) ))
        rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor("".. self.Config.MessageThanks1 ))
        rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor("".. self.Config.MessageClaim ))
        return
    end

    -- check inventory is empty
    local playerinv = rust.GetInventory(netuser)
    local iClothVacantNbr=4
    for i=0,39 do
        b,item = playerinv:GetItem( i )
        if b then
            if(i<36) then
                rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor(self.Config.MessageEmpty ))
                rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor(self.Config.MessageEmpty1 ))
                return
            else
                iClothVacantNbr=iClothVacantNbr-1
            end
        end
    end

    -- Give the kit
    local pref = rust.InventorySlotPreference(  InventorySlotKind.Default, false, InventorySlotKindFlags.Belt)
    local inv = netuser.playerClient.rootControllable.idMain:GetComponent( "Inventory" )
    local ItemTable=self.Config.SmallrestartPak

    --[[if (data[ "KitType" ]==2) then
        ItemTable=self.Config.BigrestartPak
    elseif  (data[ "KitType" ]==3) then
        ItemTable=self.Config.MetalrestartPak
    end--]]
    if(self.Config.KitsDeclaration[data[ "KitType" ]]==nil) then
        rust.SendChatToUser(netuser,"[RestartKit]","[color #FF0000] ERROR with config, this kit doesn't exist anymore, contact an admin !")
        return
    end

    local iPartial=-1;
    local iNbr=0
    for i,cRustItem in ipairs(self.Config.KitsDeclaration[data[ "KitType" ]]) do
        if(i>1) then
            iNbr=iNbr+1
            if(iNbr>iContinueAt) then
                cName, iNumber = cRustItem:match("([^,]+):([^,]+)")
                local rustItem =  rust.GetDatablockByName( cName )
                if(not rustItem) then
                    rust.SendChatToUser(netuser,"[RestartKit]","[color #FF0000] ERROR with restartkit config, one name of item is wrong: '".. cName .. "' Warn the admin please !")
                    return
                end
                if( tonumber(iNumber)<0) or ( tonumber(iNumber)>10000) then
                  rust.SendChatToUser(netuser,"[RestartKit]","[color #FF0000] ERROR with restartkit config, one number of item is wrong: '".. cName .. "' Warn the admin please !")
                  return
                end
                if( (playerinv.vacantSlotCount-iClothVacantNbr)<5 ) then
                    rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor(self.Config.InventoryFull ))
                    iPartial=iNbr
                    break
                end
                if( tonumber(iNumber)>0) then
                    rust.SendChatToUser(netuser,"[RestartKit]",cName.. " -- " .. iNumber)
                    inv:AddItemAmount( rustItem,tonumber(iNumber), pref )
                end
            end
        end
    end

    if(iPartial==-1) then
        rust.InventoryNotice( netuser, self.Config.MessageDonated )
        rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor(self.Config.MessageDonated ))
    end

    -- Save the flag "got kit"
    local userid=rust.GetLongUserID(netuser)
    local data = self.WData[ userid ]
    if (not data) then
        data = {}
        self.WData[ userid ] = data
    end
    local cDateTime = System.DateTime.Now:ToString("dd/MM/yyyy HH:mm")
    if(iPartial==-1) then
        data[ "Received" ] = cDateTime
        data[ "Partial" ] = 9999
        if(self.timer[netuser]) then self.timer[netuser]:Destroy() end 
    else
        data[ "Received" ] = "0"
        data[ "Partial" ] = iPartial
        if(self.timer[netuser]) then self.timer[netuser]:Destroy() end 
        self.timer[netuser] = timer.Once(30, function() self:ActivatePartiallyReceivedTimer(netuser) end)
    end
    -- reserve for future update
    data["FlagOne"]=""
    data["FlagTwo"]=""
    data["FlagThree"]=""
    data["FlagFour"]=""
    -- end
    self.WipeData:SetText( json.encode( self.WData ) )
    self.WipeData:Save()
    -- self:SetupDatabase()
end

------------------------------------
-- cmdconsoleresetafterwipe
------------------------------------
function PLUGIN:cmdconsoleresetafterwipe( arg )
    local netuser = arg.argUser
    local sendto = 'console'
    if netuser then sendto = 'echo' end
    if ( netuser and not self:CanUserAdmin( netuser ) ) then
        local msg="Error, only admin can do this command"
        self:msgPrint( netuser, msg, sendto )
        return true
    end
    if(self.bInitOk==false) then
        self:msgPrint( netuser,"ERROR in config file - All functions disabled !", sendto )
        self:msgPrint( netuser,"Try to correct or delete the file 'cfg_restartkit.txt' and reload 'd-RestartKit' plugin", sendto )
        return true
    end

    local ReplyYes = tostring( arg:GetString( 0, "text" ) )
    if ReplyYes == "text" or ReplyYes ~= "yes" then
        self:msgPrint( netuser,"If you are really sure that you want to reset the users kit flag", sendto )
        self:msgPrint( netuser,"so they all can get a new kit again type:", sendto )
        self:msgPrint( netuser,"'restartkit.resetafterwipe yes'", sendto )
    return true
    end

    if (util.GetDatafile( "db_restartkitflags" )) then
        util.RemoveDatafile( "db_restartkitflags" )
    end
    self:SetupDatabase()
    self:msgPrint( netuser,"RestartKit Database has been cleared, users can claim their kit again", sendto )
    return true
end

------------------------------------
-- cmdconsoledeletealldatabases
------------------------------------
function PLUGIN:cmdconsoledeletealldatabases( arg )
    local netuser = arg.argUser
    local sendto = 'console'
    if netuser then sendto = 'echo' end
    if ( netuser and not self:CanUserAdmin( netuser ) ) then
        local msg="Error, only admin can do this command"
        self:msgPrint( netuser, msg, sendto )
        return true
    end
    if(self.bInitOk==false) then
        self:msgPrint( netuser,"ERROR in config file - All functions disabled !", sendto )
        self:msgPrint( netuser,"Try to correct or delete the file 'cfg_restartkit.txt' and reload 'd-RestartKit' plugin", sendto )
        return true
    end

    local ReplyYes = tostring( arg:GetString( 0, "text" ) )
    if ReplyYes == "text" or ReplyYes ~= "yes" then
        self:msgPrint( netuser,"If you are REALLY sure that you want to DELETE all the DATABASES, type:", sendto )
        self:msgPrint( netuser,"'restartkit.DELETEALLDATABASES yes'", sendto )
        self:msgPrint( netuser,"Note: you'll have to re-enter all the users", sendto )
    return true
    end

    -- do the work
    if (util.GetDatafile( "db_restartkitflags" )) then
        util.RemoveDatafile( "db_restartkitflags" )
    end
    if (util.GetDatafile( "db_restartkit" )) then
        util.RemoveDatafile( "db_restartkit" )
    end
    self:SetupDatabase()
    self:msgPrint( netuser,"RestartKit Databases has been DELETED, you'll have to re-enter all the users", sendto )
    return true
end

------------------------------------
-- SendHelpText
------------------------------------
function PLUGIN:SendHelpText( netuser )
    rust.SendChatToUser( netuser, "/restartkit - To get your restart kit after a wipe (wood, kevlar, m4, etc) " )
end

------------------------------------
-- msgPrint
------------------------------------
function PLUGIN:msgPrint( netuser, msg, sendto )
    if sendto == 'chat' then
        rust.SendChatToUser( netuser, self.Settings.ChatHandle, msg )
    elseif sendto == 'echo' then
        rust.RunClientCommand( netuser, "echo " .. msg  )
    else
        print( msg )
    end
end

------------------------------------
-- ExtractKitName
------------------------------------
function PLUGIN:ExtractKitName(cInput)
    local iStart=nil
    local iEnd=nil
    local cName=""
    iStart=string.find(cInput, "'")
    if(iStart~=nil) then
       iEnd=string.find(cInput, "'",(iStart+1))
       if(iEnd~=nil) then
          cName=string.sub(cInput,(iStart+1),(iEnd-1))
          cName=string.gsub(cName, " ", "")
          if(string.len(cName)>0) then
             return cName
          end
       end
    end
    error("RestartKit - Unable to get kit's name. Please correct configuration")
    return ""
end

------------------------------------
-- CanUserAdmin
------------------------------------
function PLUGIN:CanUserAdmin ( netuser )
    if ( netuser:CanAdmin() ) or ( (self.oxmin==true) and (oxmin_Plugin:HasFlag(netuser, self.FLAG_cangive, false)) ) then
        return true
    else
        return false
    end
end

------------------------------------
-- explode
------------------------------------
function PLUGIN:explode(str,div)
    if (div=='') then return false end
    local pos,arr = 0,{}
    for st,sp in function() return string.find(str,div,pos,true) end do
        table.insert(arr,string.sub(str,pos,st-1))
        pos = sp + 1
    end
    table.insert(arr,string.sub(str,pos))
    return arr
end

------------------------------------
-- ChatColor
------------------------------------
function PLUGIN:ChatColor(str)
    str=self.Config.ChatMsgColor..str:gsub("/restartkit now",self.Config.ChatCmdColor.."/restartkit now"..self.Config.ChatMsgColor)
    str=self.Config.ChatMsgColor..str:gsub("/restartkit help",self.Config.ChatCmdColor.."/restartkit help"..self.Config.ChatMsgColor)
    return str
end

------------------------------------
-- tablelength
------------------------------------
function PLUGIN:tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

--~ print a table
function printTable(list, i)

    local listString = ''
--~ begin of the list so write the {
    if not i then
        listString = listString .. '{'
    end
    i = i or 1
    local element = list[i]

--~ it may be the end of the list
    if not element then
        return listString .. '}'
    end
--~ if the element is a list too call it recursively
    if(type(element) == 'table') then
        listString = listString .. printTable(element)
    else
        listString = listString .. element
    end

    return listString .. ', ' .. printTable(list, i + 1)

end

------------------------------------
-- TEST_iFindOnlineUserByName - case insensitive and partial search
-- BETA TEST FUNCTION  - simulate many fake user online for search functions
-- on real game server this function is not used (see flag 'bFlagIsBetaTest')
------------------------------------
function PLUGIN:TEST_iFindOnlineUserByName(searchUser)
        local iFoundStmID64
        searchUser=string.lower(searchUser)
        local iNbrFound=0
        local tblNetUserFound={}
        local tblNameFound={}
        local tblNameReal={}
        local tblRealOnlineUser=rust.GetAllNetUsers()
        -- get real users online
        for _, netuser in pairs( tblRealOnlineUser ) do
            if string.find(string.lower(netuser.displayName),searchUser) then 
                tblNetUserFound[iNbrFound+1]=netuser
                tblNameFound[iNbrFound+1]=netuser.displayName
                tblNameReal[iNbrFound+1]=true
                iNbrFound=iNbrFound+1
            end
        end
        if(tblRealOnlineUser[1]==nil) then
            error("ERROR - For tests with 'bFlagIsBetaTest=true' there must be at least 1 user online (usually you)")
            return iNbrFound,iFoundStmID64,tblNetUserFound,tblNameFound
        end
        -- add fake users
        local BETATEST_GetAllNetUsers_TestFake={"The Beast","The Crippler","Babyface","Bad Boy","Sugar","KO","The Technician","Kombo King","The Assassin","Black Widow","Crazy Legs","Pitbull","Bulldog","The Hell's Warrior",'The "yo" Warhammer',"The Hammer","Gangsta","The Iceman","Mr. Freeze","The Monster","Man of Stone","Godzilla","King Kong","Red Hot","Thunder","Meltdown","The Nightmare","Dr. Steelhammer","Quicksilver","Iron","Marvelous","The Hitman","The Body Snatcher","Lights Out","Thunder","No Dice","El Terrible","The Blade","Envy That White Boy","Out of Controll","Princess","Dirty and Ditsy","Barbieish","Bad Little Girl","Who Givs A Sh*T"}
        for i, tblNetUser in ipairs( BETATEST_GetAllNetUsers_TestFake) do
            if string.find(string.lower(tblNetUser),searchUser) then 
                tblNetUserFound[iNbrFound+1]=tblRealOnlineUser[1]
                tblNameFound[iNbrFound+1]=tblNetUser
                tblNameReal[iNbrFound+1]=false
                iNbrFound=iNbrFound+1
            end
        end
        if(iNbrFound==1) then
            if(tblNameReal[1]==true) then
                -- for real user get real Steam64ID
                iFoundStmID64=rust.GetLongUserID(tblNetUserFound[1])
            else
                -- for fake users hash name to create a fake steam64ID (17 chars)
                iFoundStmID64=""
                local i = 1
                while string.len(iFoundStmID64)<18 do
                    i = i + 1
                    if i>(string.len(tblNameFound[1])-1) then
                        i=1
                    end
                    local sValue=string.byte(tblNameFound[1], i)
                    iFoundStmID64=iFoundStmID64..sValue
                end
                iFoundStmID64=string.sub(iFoundStmID64,1,17)
            end
        end
        return iNbrFound,iFoundStmID64,tblNetUserFound,tblNameFound
end

------------------------------------
-- ActivatePartiallyReceivedTimer
------------------------------------
function PLUGIN:ActivatePartiallyReceivedTimer(netuser)
    if(self.timer[netuser]) then self.timer[netuser]:Destroy() end 
    local userid=rust.GetLongUserID(netuser)
    local data = self.WData[ userid ]
    if (data and data["Partial"]~=9999) then
        self.timer[netuser] = timer.Once(30, function() self:ActivatePartiallyReceivedTimer(netuser) end)
        rust.SendChatToUser(netuser,"[RestartKit]",self:ChatColor(netuser.displayName .." !! ".. self.Config.MsgNotComplete))
    else
        self.timer[netuser]:Destroy()
        self.timer[netuser] = nil
    end
end

------------------------------------
-- timers
------------------------------------
function PLUGIN:Unload()
    for netuser,d in pairs(self.timer) do
        self.timer[netuser]:Destroy()
    end
end
function PLUGIN:OnUserDisconnect( networkplayer )
    local netuser = networkplayer:GetLocalData()
    if(self.timer[netuser]) then
        self.timer[netuser]:Destroy()
        self.timer[netuser] = nil
    end
end

------------------------------------
-- msgPrintHelpCommand(type)
------------------------------------
function PLUGIN:msgPrintHelpCommand( netuser, type, sendto)

cChoiceOfKits=string.gsub(g_cNameOfKitReadable,", ","/")

    if(type=='adduser') then
        self:msgPrint( netuser,"Format is 'restartkit.adduser [steam64ID/Name] [name of kit]'", sendto )
        self:msgPrint( netuser,"examples:", sendto )
        self:msgPrint( netuser,"          restartkit.adduser 76512361123459234 "..g_tblHelpNameKit[1], sendto )
        self:msgPrint( netuser,"          restartkit.adduser 'DeathKill' "..g_tblHelpNameKit[2], sendto )
        self:msgPrint( netuser,"          restartkit.adduser 'dea' "..g_tblHelpNameKit[3], sendto )
        self:msgPrint( netuser,"          restartkit.adduser 'BillyTheKid' "..g_tblHelpNameKit[4], sendto )
        self:msgPrint( netuser,"", sendto )
        self:msgPrint( netuser," Note: The name must be in single quote (')", sendto )
        self:msgPrint( netuser," Note2: Enter a full or partial name to search.", sendto )
        self:msgPrint( netuser," Note3: Case insensitive, ie: 'dea' match 'Death', 'dean' etc.", sendto )
    elseif(type=='deleteuser') then
        self:msgPrint( netuser,"Format is 'restartkit.deleteuser [Name/steam64ID]'", sendto )
        self:msgPrint( netuser,"examples:", sendto )
        self:msgPrint( netuser,"          restartkit.deleteuser 76512361123459234", sendto )
        self:msgPrint( netuser,"          restartkit.deleteuser 'DeathKill'", sendto )
        self:msgPrint( netuser,"          restartkit.deleteuser 'BillyTheKid'", sendto )
        self:msgPrint( netuser,"", sendto )
        self:msgPrint( netuser," Note: if search by name, the name must be in single quote (')", sendto )
        self:msgPrint( netuser," Note2: Enter a full or partial name to search.", sendto )
        self:msgPrint( netuser," Note3: Case insensitive, ie: 'dea' match 'Death', 'dean' etc.", sendto )
    elseif(type=='displayuser') then
        self:msgPrint( netuser,"Format is 'restartkit.displayuser [Name/steam64ID]'", sendto )
        self:msgPrint( netuser,"examples:", sendto )
        self:msgPrint( netuser,"          restartkit.displayuser 76512361123459234", sendto )
        self:msgPrint( netuser,"          restartkit.displayuser 'DeathKill'", sendto )
        self:msgPrint( netuser,"          restartkit.displayuser 'BillyTheKid'", sendto )
        self:msgPrint( netuser,"", sendto )
        self:msgPrint( netuser," Note: if search by name, the name must be in single quote (')", sendto )
        self:msgPrint( netuser," Note2: Enter a full or partial name to search.", sendto )
        self:msgPrint( netuser," Note3: Case insensitive, ie: 'dea' match 'Death', 'dean' etc.", sendto )
    elseif(type=='giveagain') then
        self:msgPrint( netuser,"Format is 'restartkit.giveagain [Name/steam64ID]'", sendto )
        self:msgPrint( netuser,"examples:", sendto )
        self:msgPrint( netuser,"          restartkit.giveagain 76512361123459234", sendto )
        self:msgPrint( netuser,"          restartkit.giveagain 'DeathKill'", sendto )
        self:msgPrint( netuser,"          restartkit.giveagain 'BillyTheKid'", sendto )
        self:msgPrint( netuser,"", sendto )
        self:msgPrint( netuser," Note: if search by name, the name must be in single quote (')", sendto )
        self:msgPrint( netuser," Note2: Enter a full or partial name to search.", sendto )
        self:msgPrint( netuser," Note3: Case insensitive, ie: 'dea' match 'Death', 'dean' etc.", sendto )
    end
end