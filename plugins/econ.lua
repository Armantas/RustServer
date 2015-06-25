PLUGIN.Title = "Economy"
PLUGIN.Description = "Configurable Economy Plugin (fork)"
PLUGIN.Version = "1.3.1"
PLUGIN.Author = "ZOR"

function PLUGIN:Init()
    self.CfgFile,    self.Cfg =      self:readFileToMap( "pricesCfg" )
    self.PricesFile,  self.Prices =   self:readFileToMap( "prices2" )
    self.DataFile,     self.Data =     self:readFileToMap( "economy2" )  --money store
    self.SleeperPos = {}  --unpersistable, because restart clears all sleepers from map
    self.payoutTimers = {}
    self:initCfgParam("CurrencySymbol","$")
    self:initCfgParam("customPriceLocation","-")
    self:initCfgParam("sleeperRad",2)
    self:initCfgParam("startMoney",100)
    self:initCfgParam("bearFee",150)
    self:initCfgParam("mutantbearFee",150)
    self:initCfgParam("wolfFee",70)
    self:initCfgParam("mutantwolfFee",100)
    self:initCfgParam("humanFee",10)
    self:initCfgParam("sleeperFee",50)
    self:initCfgParam("deathFee",5)
    self:initCfgParam("boarFee",5)
    self:initCfgParam("chickenFee",150)
    self:initCfgParam("deerFee",10)
    self:initCfgParam("rabbitFee",200)
    self:initCfgParam("transferFee",20)--%
    self:initCfgParam("statsFee",100)
    self:initCfgParam("tp100mFee",20)
    self:initCfgParam("ownremoveFee",100)
    self:initCfgParam("tpAnchX",3)
    self:initCfgParam("pay4online",0) self:initCfgParam("alivePay4online",1)
    self:initCfgParam("payoutsInterval",10) -- min
    self:initCfgParam("pricePageOffset",20)

    self.topEnabled = true
    self:initCfgParam("moneyTopMaxRows",15)
    self:AddChatCommand("money", self.cmdMoney)
    self:AddChatCommand("setmoney", self.cmdSetMoney)
    self:AddChatCommand("buy", self.cmdBuy)
    self:AddChatCommand("sell", self.cmdSell)
    self:AddChatCommand("price", self.cmdPrice)
    self:AddChatCommand("priceset", self.cmdPriceSet)
    self:AddChatCommand("ehelp", self.cmdEhelp)
    self:AddChatCommand("emanage", self.cmdManage)
    self:AddChatCommand("bindgood", self.cmdBindGoods)

    zones_Plugin = plugins.Find("cor.zones")
    oxmin_Plugin = plugins.Find("oxmin")
    if oxmin_Plugin then  self.FLAG_MANAGER = oxmin.AddFlag("econmanager") end
    if not localization then localization = plugins.Find( "localization" ) end

    print( self.Title .. " v" .. self.Version .. " loaded!" )
end

function PLUGIN:initCfgParam(paramname, defaultVal)
    if (self.Cfg[paramname] ~= nil)
    then self[paramname] = self.Cfg[paramname]
    else self.Cfg[paramname] = defaultVal self[paramname] = defaultVal end end

local IShort = {}
IShort["Beans"]  = "Can of Beans"
IShort["Grenade"]  = "F1 Grenade"
IShort["Planks"]  = "Wood Planks"
IShort["Meat"]  = "Raw Chicken Breast"
IShort["Researchkit"]  = "Research Kit 1"
IShort["Food"]  = "Cooked Chicken Breast"
IShort["9mm"]  = "9mm Ammo"
IShort["556"]  = "556 Ammo"
IShort["Antirad"]  = "Anti-Radiation Pills"
IShort["C4"]  = "Explosive Charge"

local loc = {}
loc["ehelp"] = "Use /ehelp to see Economy commands"
loc["money"] = "Use /money [\"name\" send amount] to check your balance, or send someone money"
loc["buysell"] = "Use /buy or /sell to list available buy or sell prices"
loc["price.item"] = "Use /price \"string\" to filter pricelist by 'string'"
loc["price.list"] = "Use /price [\"pagenum\"] to see page of pricelist"
loc["shop.hint"] = "'{shop}' in price-line means that you have visit located somewhere 'shop' to trade it."
loc["buy"] = "Use /buy \"item\" [\"amount\"] to buy an item (amount optional)"
loc["sell"] = "Use /sell \"item\" [\"amount\"] to sell an item (amount optional) from your inventory"
loc["stats"] = "Use /money (top|transf) to see some global stats (for "
function PLUGIN:PostInit()
    if not localization then return end
    for k,v in pairs(loc) do  localization:AddString("econ", "en", k, v)  end
end

local function locstr(str)
    if localization  then return localization:GetString("econ", str)
    else return loc[str]  end
end

function PLUGIN:OnKilled (takedamage, dmg)
    if (takedamage:GetComponent("HumanController")) then
        if (tonumber(self.humanFee) > 0) then local victim = takedamage:GetComponent("HumanController")
            if (victim) then local victimPlayer = victim.networkViewOwner
                if (victimPlayer) then local victimUser = rust.NetUserFromNetPlayer(victimPlayer)
                    if (victimUser) then local victimID = rust.GetUserID(victimUser)
                        if self.pay4online > 0 and self.alivePay4online == 1 then
                            if self.payoutTimers[victimID] then self.payoutTimers[victimID]:Destroy() end
                            self.payoutTimers[victimID] = timer.Repeat(math.ceil(tonumber(self.payoutsInterval) * 60), 0,
                                function() self:giveMoneyTo(victimUser, tonumber(self.pay4online)) end)
                        end
                        if ((dmg.attacker.client) and (dmg.attacker.client.netUser)) then
                            local actor = dmg.attacker.client.netUser
                            if (actor.displayName == victimUser.displayName) then return end
                            self:giveMoneyTo(actor, math.floor(self.Data[victimID].Money * self.humanFee / 100))
                            local loosePercent = self.humanFee + self.deathFee
                            if (loosePercent > 100) then loosePercent = 100 end
                            self:setMoneyPercent(victimUser, 100 - loosePercent)
                        end
                    end
                end
            end
        end
        return
    end
    --   TODO replace with  if (takedamage:GetComponent( "BearAI" )) /StagAI/WolfAI/ChickenAI/RabbitAI/BoarAI
    if (dmg.attacker.client and dmg.attacker.client.netUser) then
        local fee = 0
        local myString = takedamage.gameObject.Name
        if (string.find(myString, "MutantBear(", 1, true)) then fee = self.mutantbearFee
        elseif string.find(myString, "MutantWolf(", 1, true) then fee = self.mutantwolfFee
        elseif (string.find(myString, "Chicken_A", 1, true)) then fee = self.chickenFee
        elseif string.find(myString, "Boar_A", 1, true) then fee = self.boarFee
        elseif string.find(myString, "Bear(", 1, true) then fee = self.bearFee
        elseif string.find(myString, "Wolf(", 1, true) then fee = self.wolfFee
        elseif string.find(myString, "Stag_A(", 1, true) then fee = self.deerFee
        elseif string.find(myString, "Rabbit", 1, true) then fee = self.rabbitFee
        end
        if not tonumber(fee) then print("ECON: fee for: "..myString.." val: "..fee .." is not a number! Set it correctly.") fee = 0 end
        if (tonumber(fee) > 0) then
            local player = dmg.attacker.client.netUser
            local playerID = rust.GetUserID(player)
            self:giveMoneyTo(player, tonumber(fee))
        elseif (string.find(myString, "MaleSleeper(", 1, true) and self.sleeperFee > 0) then
            local actorUser = dmg.attacker.client.netUser
            local coord = actorUser.playerClient.lastKnownPosition

            local sleepreId = self:sleeperIdAtPos(coord)
            if (sleepreId ~= nil) then
                self.SleeperPos[sleepreId] = nil
                self:giveMoneyTo(actorUser, math.floor(self.Data[sleepreId].Money * self.sleeperFee / 100))
                self:setMoneyPercentById(sleepreId, 100 - self.sleeperFee - self.deathFee)
            end
        end
    end
    return
end

function PLUGIN:cmdSell( netuser, cmd, args )
    if (not (args[1]) or tonumber(args[1])) then
        if(self.customPriceLocation ~= "-" and not (netuser:CanAdmin()) ) then rust.Notice( netuser, self.customPriceLocation )
        else
            rust.SendChatToUser( netuser, "You can sell : ")
            args[3] = "sellOnly" self:cmdPrice( netuser, cmd, args )
        end
    else
        if IShort[args[1]]  then args[1] = IShort[args[1]]  end
        local datablock = rust.GetDatablockByName( args[1] )
        if (not datablock) then rust.Notice(netuser, "Wrong item name!")  return end

        local price = 0
        if (self.Prices[args[1]] ~= nil) then
            price = tonumber(self.Prices[args[1]].Sell) end
        if (price == nil or price == 0) then
            rust.Notice(netuser, "The shop doesn't have a sell price for this!")
            return end

        if zones_Plugin and self.Prices[args[1]].StoreFlag and self:tsize(self.Prices[args[1]].StoreFlag)>0  then
            local matchesAny = false
            local zone  = zones_Plugin:mergedZoneAtPos(netuser.playerClient.lastKnownPosition)
            for i,f in pairs(self.Prices[args[1]].StoreFlag) do
                if f and  zone  and zone[i]  then matchesAny = true break end end
            if not matchesAny then
                local shops = "" for i,f in pairs(self.Prices[args[1]].StoreFlag) do  if f then shops = shops .. "  { " ..i.. " }" end end
                rust.Notice(netuser," You can do it only inside of a shops:"..shops) return end
        end
        local inv =  rust.GetInventory( netuser )
        --rust.GetCharacter(netuser).playerClient.controllable:GetComponent( "Inventory" )
--        local status,inv = pcall(function() return  rust.GetInventory( netuser ) end)
        if  not inv then   rust.Notice(netuser,"Please reconnect to be able to /sell")   return end  --not status or
        local amount = 1
        if (args[2]) then
            amount = tonumber(math.floor(args[2]))
            if (amount <= 0) then rust.Notice(netuser, "Sell amount too low!")
                return end end

        local got = self:getInventoryCount(inv, datablock,args[1] == "Research Kit 1")
        if got == 0 then
            rust.Notice(netuser, "You dont have any [ "..args[1].." ]")  return end
        if got < amount then
            rust.Notice(netuser, "You have only "..got.." [ "..args[1].." ] for sell")
            amount = got end

        self:takeFromInventory(inv,datablock, amount,args[1] == "Research Kit 1")

        local gain = price * amount
        self:giveMoneyTo(netuser, gain)
        rust.SendChatToUser(netuser, "Sold " .. tostring(amount) .. " " .. args[1] .. " for " .. self:moneyStr(gain))
    end
end

function PLUGIN:giveMoneyTo(netuser, delta)
    local netuserID = rust.GetUserID( netuser )
    self.Data[netuserID].Transfered = self.Data[netuserID].Transfered + delta
    self.Data[netuserID].Money = self.Data[netuserID].Money + delta
    rust.SendChatToUser( netuser, "Balance is : ".. self:comma_value( self.Data[netuserID].Money) .." (+ "..self:moneyStr(delta)..")" )
    self:SaveMapToFile(self.Data,self.DataFile)
end
function PLUGIN:takeMoneyFrom(netuser, delta)
    local netuserID = rust.GetUserID( netuser )
    self.Data[netuserID].Money = self.Data[netuserID].Money - delta
    rust.SendChatToUser( netuser, "Balance is : ".. self:comma_value( self.Data[netuserID].Money) .." (- "..self:moneyStr(delta)..")" )
    self:SaveMapToFile( self.Data,self.DataFile)
end
function PLUGIN:getMoney(netuser)
    local netuserID = rust.GetUserID( netuser )
    return self.Data[netuserID].Money
end

function PLUGIN:setMoneyPercent(netuser, percent)
    self:setMoneyPercentById(rust.GetUserID( netuser ) ,percent )
    if (percent >= 0 and percent <= 100) then
        rust.SendChatToUser( netuser, self:printmoney(netuser) ) end
end

function PLUGIN:setMoneyPercentById(netuserID, percent)
    if (percent >= 0 and percent <= 100) then
        if (percent == 0) then
            self.Data[netuserID].Money = 0
        else
            self.Data[netuserID].Money = math.floor(self.Data[netuserID].Money * percent / 100)
        end
        self:SaveMapToFile( self.Data,self.DataFile)
    end
end

function PLUGIN:cmdBuy( netuser, cmd, args )
    if (not (args[1]) or tonumber(args[1]) ) then
        if(self.customPriceLocation ~= "-" and not (netuser:CanAdmin()) ) then rust.Notice( netuser, self.customPriceLocation )
        else
            rust.SendChatToUser( netuser, "You can buy : ")
            args[3] = "buyOnly"  self:cmdPrice( netuser, cmd, args )
        end
    else
        if IShort[args[1]]  then args[1] = IShort[args[1]] end
        local datablock = rust.GetDatablockByName(args[1])
        if (not datablock) then rust.Notice(netuser, "Wrong item name!")  return end

        local price = 0
        if (self.Prices[args[1]] ~= nil) then
            price = tonumber(self.Prices[args[1]].Buy) end

        if (price == nil or price == 0) then
            rust.Notice(netuser, "The shop doesn't have a buy price for this!")
            return end

        if zones_Plugin and self.Prices[args[1]].StoreFlag and self:tsize(self.Prices[args[1]].StoreFlag)>0  then
            local matchesAny = false
            local zone  = zones_Plugin:mergedZoneAtPos(netuser.playerClient.lastKnownPosition)
            for i,f in pairs(self.Prices[args[1]].StoreFlag) do
                if f and  zone  and zone[i]  then matchesAny = true break end end
            if not matchesAny then
                local shops = "" for i,f in pairs(self.Prices[args[1]].StoreFlag) do  if f then shops = shops .. "  { " ..i.. " }" end end
                rust.Notice(netuser," You can do it only inside of a shops:"..shops) return end
        end

        local number = 1
        if ((args[2]) and (tonumber(args[2]) > 0)) then
            number = tonumber(math.floor(args[2]))
            if (number <= 0) then  rust.Notice(netuser, "Buy amount too low!")
            return end  end
        price = price * number
        local netuserID = rust.GetUserID( netuser )
        if ((price > 0) and (self.Data[netuserID].Money >= price)) then
            self:takeMoneyFrom(netuser, price)
            local inventory =  rust.GetInventory( netuser )
            local rcwas = 0
            if args[1] == "Research Kit 1" then  rcwas = self:getInventoryCount(inventory, datablock, true)  end
            inventory:AddItemAmount( rust.GetDatablockByName(args[1]), number)
            rust.SendChatToUser( netuser, "Bought " .. tostring(number) .. " " .. util.QuoteSafe( args[1] ) )
            if args[1] == "Research Kit 1" then --deal with inv
                local rcnow = self:getInventoryCount(inventory, datablock, true)
                local needtotake = rcnow - (rcwas + number)
                if needtotake > 0 then  self:takeFromInventory(inventory,datablock, needtotake, true) end
            end
        else
            rust.Notice( netuser, "Not enough money to /buy "..tostring(number).." ".. util.QuoteSafe( args[1] ) )  end
        return
    end
end
function PLUGIN:getInventoryCount(inventory, datablock, stackable)
    local ret = 0
    local iterator = inventory.occupiedIterator
    while (iterator:Next()) do
        local item = iterator.item
        if (item.datablock == datablock) then
            if (item.datablock:IsSplittable()  or stackable ) then ret = ret + item.uses
            else ret = ret + 1 end  end  end
    return ret
end
function PLUGIN:takeFromInventory(inv,datablock, amount, stackable)
    local taken = 0
    while taken < amount do
        local item = inv:FindItem(datablock)
        if not item then return end
        if item.datablock:IsSplittable() or stackable  then
            local canTake = item.uses
            local needToTake = amount - taken
            if canTake >  needToTake then taken = taken +item.uses item:SetUses(item.uses - needToTake)
            else taken = taken +item.uses  inv:RemoveItem(item)  end
        else inv:RemoveItem(item)  taken = taken +1 end
    end
end
function PLUGIN:cmdMoney( netuser, cmd, args )
    local isAuthorized = netuser:CanAdmin() or (oxmin_Plugin and oxmin_Plugin:HasFlag(netuser, self.FLAG_MANAGER, false))
    local netuserID = rust.GetUserID( netuser )
    if (not args[1]) then       --self money
        rust.SendChatToUser( netuser, self:printmoney(netuser) )
        return end
    if ((args[1]) and (not args[2]) and (args[1] == "top") and self.topEnabled) then   -- toplist money       --statsFee
        if ( not isAuthorized and self.Data[netuserID].Money >= tonumber(self.statsFee)) then  self:takeMoneyFrom(netuser, tonumber(self.statsFee))
        elseif not isAuthorized then  rust.SendChatToUser( netuser, "You need  "..self:moneyStr(self.statsFee).." to see global stats") return end
        local mypairs = {}
        for _,value in pairs(self.Data) do  table.insert(mypairs,{Name=value.Name, Money=value.Money})  end
        table.sort(mypairs,function(a,b) return a.Money > b.Money end)
        --        for _,line in ipairs(mypairs) do  print (line.name .. " === " .. line.value)
        local listed = 1
        rust.SendChatToUser( netuser, "Top of richest players: ")
        for _,pair in pairs(mypairs) do
            rust.SendChatToUser( netuser, "Place: "..listed..": " .. util.QuoteSafe(pair.Name) .. " with " ..  self:moneyStr(pair.Money) )
            listed = listed + 1
            if listed > self.moneyTopMaxRows then break end
        end
        return end
    if ((args[1]) and (not args[2]) and (args[1] == "transf") and self.topEnabled) then   -- toplist transfered
        if ( not isAuthorized and self.Data[netuserID].Money >= tonumber(self.statsFee)) then  self:takeMoneyFrom(netuser, tonumber(self.statsFee))
        elseif not isAuthorized then   rust.SendChatToUser( netuser, "You need  "..self:moneyStr(self.statsFee).." to see global stats") return end
        local mypairs = {}
        for _,value in pairs(self.Data) do if value.Transfered then  table.insert(mypairs,{Name=value.Name, Transfered=value.Transfered}) end end
        table.sort(mypairs,function(a,b) return a.Transfered > b.Transfered end)
        --        for _,line in ipairs(mypairs) do  print (line.name .. " === " .. line.value)
        local listed = 1
        rust.SendChatToUser( netuser, "Top of richest players: ")
        for _,pair in pairs(mypairs) do
            rust.SendChatToUser( netuser, "Place: "..listed..": " .. util.QuoteSafe(pair.Name) .. " with total transfers: " .. self:moneyStr(pair.Transfered) )
            listed = listed + 1
            if listed > self.moneyTopMaxRows then break end
        end
        return  end
    if ((args[3]) and (not args[4]) and (args[2] == "send")) then    -- send money
        local b, targetuser = rust.FindNetUsersByName( args[1] )
        if (not b) then
            if (targetuser == 0) then rust.Notice( netuser, "No players found with that name!" )
            else rust.Notice( netuser, "Multiple players found with that name!" ) end
            return
        end
        local amount = tonumber(args[3])
        local amountWithFee = amount + math.floor(amount * (self.transferFee / 100))
        local targetuserID = rust.GetUserID( targetuser )

        if ((amount > 0) and (amountWithFee <= self.Data[netuserID].Money) ) then --and (targetuser.displayName ~= netuser.displayName)) then
            self:giveMoneyTo(targetuser, amount)
            self:takeMoneyFrom(netuser, amountWithFee)
        else
            rust.Notice( netuser, "Wrong /money arguments! Transfer fee is "..self.transferFee.."%" )
        end
        return
    end
    rust.Notice( netuser, "/money error!" )
end

function PLUGIN:tsize(t) local res = 0 for key, value in pairs(t) do  res = res + 1 end  return res   end
function PLUGIN:cmdPriceSet( netuser, cmd, args )
    local isAuthorized = netuser:CanAdmin() or (oxmin_Plugin and oxmin_Plugin:HasFlag(netuser, self.FLAG_MANAGER, false))
    if  not isAuthorized  then return end
    if (  (args[1]) and (args[2])) then  -- admin price edit
        if IShort[args[1]]  then args[1] = IShort[args[1]] end
        if (not rust.GetDatablockByName(args[1])) then rust.Notice(netuser, "Wrong item name!")  return end

        if(tonumber(args[2])  < 0 ) then args[2] = 0 end
        self:updatePrice(args[1], args[2],"Buy")
        rust.SendChatToUser( netuser, "Price updated:  " .. util.QuoteSafe( args[1] ) .. " buy:" .. args[2]  )

        if(args[3] ) then
            if(tonumber(args[3])  <  0 ) then args[3] = 0 end
            self:updatePrice(args[1], args[3],"Sell")
            rust.SendChatToUser( netuser, "Price updated:  " .. util.QuoteSafe( args[1] ) .. " sell: "..args[3] )
        end
        self:SaveMapToFile(self.Prices, self.PricesFile)
    end
end
function PLUGIN:cmdPrice( netuser, cmd, args )
    local isAuthorized = netuser:CanAdmin() or (oxmin_Plugin and oxmin_Plugin:HasFlag(netuser, self.FLAG_MANAGER, false))
    if (self.customPriceLocation ~= "-" and not isAuthorized) then rust.Notice(netuser, self.customPriceLocation)
    else
        local filter = nil
        if not tonumber(args[1]) then  filter = args[1] args[1] = args[2] end
        local offset, totalRows = tonumber(self.pricePageOffset), self:tsize(self.Prices)
        if filter or args[3] then totalRows = 0
            for key, value in pairs(self.Prices) do totalRows = totalRows + 1
                if filter and not key:lower():gsub("%W", ""):find(filter:lower():gsub("%W", ""),1,true) then totalRows = totalRows - 1 end
                if args[3] == "sellOnly" and ( not value.Sell  or tonumber(value.Sell) <= 0) then totalRows = totalRows - 1 end
                if args[3] == "buyOnly" and ( not value.Buy  or tonumber(value.Buy) <= 0) then totalRows = totalRows - 1 end
            end
            if totalRows == 0 then rust.SendChatToUser(netuser, "not found") return end
        end
        local from, page, pages = 1, 1, math.ceil(totalRows / offset)
        if tonumber(args[1]) then page =  tonumber(args[1]) from = from + offset * (page-1) end
        local to = from + offset
        local rownum = 0
        if totalRows > offset then
            rust.SendChatToUser(netuser, "---------Price list :  page [  ".. tostring(page) .. " / "..tostring(pages) .."  ] ----------------------") end
        for key, value in self:pairsKeySorted(self.Prices) do
            rownum =  rownum + 1
            if rownum == to then
                rust.SendChatToUser(netuser, "---------------------- page [  ".. tostring(page) .. " / "..tostring(pages) .."  ] ----------------------")
                break end
            if filter and not key:lower():gsub("%W", ""):find(filter:lower():gsub("%W", ""),1,true)then rownum =  rownum - 1
            elseif args[3] == "sellOnly" and ( not value.Sell  or tonumber(value.Sell) <= 0) then rownum =  rownum - 1
            elseif args[3] == "buyOnly" and ( not value.Buy  or tonumber(value.Buy) <= 0) then rownum =  rownum - 1
            elseif rownum < from then else
                local newLine = "\"" .. key .. "\" - " -- ..string.rep(".",(21 -string.len(key)))
                if  args[3] ~= "sellOnly" then
                    if value.Buy   and tonumber(value.Buy) > 0 then
                        newLine = newLine .. "  [Buy:  " .. tostring(value.Buy) .. " ]"
                    elseif args[3] ~= "buyOnly" then  newLine = newLine .. "  [Buy:  -- ]" end end
                if args[3] ~= "buyOnly" then
                    if value.Sell  and tonumber(value.Sell) > 0 then
                        newLine = newLine .. "  [Sell:  " .. tostring(value.Sell) .. " ]"
                    elseif args[3] ~= "sellOnly" then newLine = newLine .. "  [Sell:  -- ]" end end

                if zones_Plugin and value.StoreFlag  then
                    for i,f in pairs(value.StoreFlag) do  if f then newLine = newLine .. "  { " ..i.. " }" end end  end
                rust.SendChatToUser(netuser, newLine)
            end
        end
    end
end

function PLUGIN:cmdBindGoods( netuser, cmd, args )
    local isAuthorized = netuser:CanAdmin() or (oxmin_Plugin and oxmin_Plugin:HasFlag(netuser, self.FLAG_MANAGER, false))
    if not isAuthorized then return  end
    if  not args[1]  then return end
    if  not args[2]  then args[2] = "shop" end

    if not rust.GetDatablockByName(args[1]) or not self.Prices[(args[1])] then rust.Notice(netuser, "Wrong item name!")  return end

    if not self.Prices[(args[1])].StoreFlag   then   self.Prices[(args[1])].StoreFlag = {}  end

    if not self.Prices[(args[1])].StoreFlag[args[2]]   then   self.Prices[(args[1])].StoreFlag[args[2]] = true
    rust.SendChatToUser( netuser, util.QuoteSafe( args[1] ) .. " now binded to zone: "..args[2] )
    else  self.Prices[(args[1])].StoreFlag[args[2]] = nil
    rust.SendChatToUser( netuser, util.QuoteSafe( args[1] ) .. " now un-binded from zone: "..args[2] )end     --table.insert(self.Prices[(args[1])].StoreFlag, args[2])

    self:SaveMapToFile(self.Prices, self.PricesFile)
end

function PLUGIN:cmdSetMoney( netuser, cmd, args )
    local isAuthorized = netuser:CanAdmin() or (oxmin_Plugin and oxmin_Plugin:HasFlag(netuser, self.FLAG_MANAGER, false))
    if  not isAuthorized then return  end
    if (args[1]) then
        local b, targetuser = rust.FindNetUsersByName( args[1] )
        if (not b) then
            if (targetuser == 0) then rust.Notice( netuser, "No players found with that name!" )
            else  rust.Notice( netuser, "Multiple players found with that name!" ) end
            return  end
        local targetuserID = rust.GetUserID( targetuser )
        if ((args[2])) then
            self.Data[targetuserID].Money = tonumber(args[2])
            self:SaveMapToFile(self.Data,self.DataFile) end
        rust.SendChatToUser( netuser, self:printmoney(targetuser) )
        return
    end
end

function PLUGIN:cmdEhelp( netuser, cmd, args )
    local isAuthorized = netuser:CanAdmin() or (oxmin_Plugin and oxmin_Plugin:HasFlag(netuser, self.FLAG_MANAGER, false))
    if(tonumber(self.pay4online) > 0) then
        rust.SendChatToUser( netuser, "** You are receiving  "..self:moneyStr(self.pay4online).." for each "..tostring(self.payoutsInterval).." minutes  being online ☺ ** " )
    end
    rust.SendChatToUser( netuser, locstr("money") )
    rust.SendChatToUser( netuser, locstr("buysell") )
    rust.SendChatToUser( netuser, locstr("price.item") )
    rust.SendChatToUser( netuser, locstr("price.list") )
    if zones_Plugin then
        rust.SendChatToUser( netuser, locstr("shop.hint") )  end
    if isAuthorized then
        rust.SendChatToUser( netuser, "Use /priceset \"name\" \"buyPrice\" [\"sellPrice\"] to add an item and its price to the list" )
        rust.SendChatToUser( netuser, "[0] priceValue - price ignored" )  end
    rust.SendChatToUser( netuser, locstr("buy")  )
    rust.SendChatToUser( netuser, locstr("sell")  )
    if isAuthorized then
        rust.SendChatToUser( netuser, "Use /setmoney \"name\" [amount] to see a player's balance or change it" )
        rust.SendChatToUser( netuser, "Use /emanage \"param\" \"(mutantbear|mutantwolf|wolf|human|bear|boar|deer|chicken" )
        rust.SendChatToUser( netuser, "|rabbit|transfer|sleeper|death)Fee| startMoney|sleeperRad\" \"digitValue\"" )
        rust.SendChatToUser( netuser, "Use /emanage \"sparam\" \"CurrencySymbol|customPriceLocation\" \"stringValue\"" ) end
    if self.topEnabled then
        rust.SendChatToUser( netuser, locstr("stats")..self:moneyStr(self.statsFee)..")" )  end
end

function PLUGIN:SendHelpText( netuser )
    rust.SendChatToUser( netuser, locstr("ehelp") )
end

function PLUGIN:updatePrice(name, price,type)
    if self.Prices[name] == nil then self.Prices[name] = {} end
    self.Prices[name][type] = tostring(price)
end

function PLUGIN:GetUserData( netuser )
    local userID = rust.GetUserID( netuser )
    return self:GetUserDataFromID( userID, netuser.displayName )
end

function PLUGIN:GetUserDataFromID( userID, name )
    local userentry = self.Data[ userID ]
    if userentry and not userentry.Transfered then
        userentry.Transfered = userentry.Money
        self:SaveMapToFile(self.Data,self.DataFile)
    elseif (not userentry) then
        userentry = {}
        userentry.ID = userID
        userentry.Money = self.startMoney
        self.Data[ userID ] = userentry
        self:SaveMapToFile(self.Data,self.DataFile)
    end
    userentry.Name = name
    return userentry
end

function PLUGIN:OnUserConnect( netuser )
    local uid = rust.GetUserID( netuser )
    local data = self:GetUserData( netuser ) --init new wollet
    rust.SendChatToUser( netuser, self:printmoney(netuser) )
    if(tonumber(self.sleeperFee) > 0) then self.SleeperPos[rust.GetUserID( netuser )] = nil end
    if(tonumber(self.pay4online) > 0) then
        self.payoutTimers[uid] = timer.Repeat( math.ceil(tonumber(self.payoutsInterval)*60), 0,
            function() self:giveMoneyTo(netuser, tonumber(self.pay4online)) end)
    end
end
--function PLUGIN:OnSpawnPlayer( playerclient, usecamp, avatar )
--        timer.Once( 2, function()     if not  self.Data[ playerclient.netUser.userID] then self:OnUserConnect( playerclient.netUser ) end end)
--end
function PLUGIN:OnUserDisconnect( netuser )
    if netuser.displayName == "displayName" then   netuser = rust.NetUserFromNetPlayer(netuser) end
    local uid = rust.GetUserID( netuser )
    if(tonumber(self.sleeperFee) > 0) then     --track only if fee enabled
        local coord = netuser.playerClient.lastKnownPosition
        self.SleeperPos[uid] = coord end
    -- clenups
    if self.payoutTimers[uid] then self.payoutTimers[uid]:Destroy() end
end

function PLUGIN:printmoney(netuser)
    local data = self:GetUserData( netuser )
    return (util.QuoteSafe(data.Name) .. " balance: " .. self:moneyStr(data.Money) )
end

function PLUGIN:SaveMapToFile(table, file)
    file:SetText( json.encode( table ) )  file:Save() end

function PLUGIN:cmdManage( netuser, cmd, args )
    local isAuthorized = netuser:CanAdmin() or (oxmin_Plugin and oxmin_Plugin:HasFlag(netuser, self.FLAG_MANAGER, false))
    if  not isAuthorized then return  end
    if (args[1]) then
        if (args[1] == "param" or args[1] == "sparam") then
            local paramName = args[2]
            local paramVal
            if( args[1] == "sparam") then paramVal = args[3]
            else paramVal = tonumber(args[3]) end

            self.Cfg[paramName],self[paramName] = paramVal,paramVal
            rust.SendChatToUser( netuser,  paramName .. " now =  " .. paramVal )
        end
        self:SaveMapToFile(self.Cfg,self.CfgFile)
        return
    end
end

function PLUGIN:readFileToMap(filename, map)
    local file = util.GetDatafile(filename)
    local txt = file:GetText()
    if (txt ~= "") then   local decoded = json.decode( txt )
        print( filename..": loaded " .. tostring(self:tsize(decoded)).." entries" )
        return file, decoded
    else
        print( filename.." not loaded: " .. txt )
        return file, {}
    end
end

function PLUGIN:sleeperIdAtPos(point)
    for key,value in pairs(self.SleeperPos) do
        if (self:isPointInRadius(value,point,tonumber(self.sleeperRad))) then
            return key   end  end
end

function PLUGIN:isPointInRadius(pos, point, rad)
    return (pos.x < point.x + rad and pos.x > point.x - rad)
            and (pos.y < point.y + rad and pos.y > point.y - rad)
            and (pos.z < point.z + rad and pos.z > point.z - rad)
end
function PLUGIN:comma_value(n) -- credit http://richard.warburton.it
    local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)','%1 '):reverse())..right
end
function PLUGIN:moneyStr(m)  return tostring(self:comma_value(tonumber(m))).." " .. self.CurrencySymbol   end
function PLUGIN:pairsKeySorted(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n)  end
    table.sort(a, f)
    local i = 0 -- iterator variable
    local iter = function () -- iterator function
        i = i + 1
        if a[i] == nil then  return nil
        else return a[i], t[a[i]] end
    end
    return iter
end
function PLUGIN:GetSymbol() return self.CurrencySymbol end
api.Bind( PLUGIN, "economy" )
