PLUGIN.Title = "FPSbooster"
PLUGIN.Description = "creates a /command for players with low performance"
PLUGIN.Version = "1.1"
PLUGIN.Author = "Splooge"

--Chat commands
function PLUGIN:Init()
	self:AddChatCommand( "fps", self.AppyBoost );
	self:AddChatCommand( "fpsoff", self.TurnOffBoost );
	self:AddChatCommand( "grass", self.ToggleGrass );
	i = 1;

end

--Apply FPS boost
function PLUGIN:AppyBoost(netuser, cmd, args)
	rust.SendChatToUser( netuser, "You have boosted your performance and increased your FPS.");
	rust.RunClientCommand(netuser, "notice.inventory BOOSTED!")

	i = 0;


	rust.RunClientCommand(netuser, "gfx.tonemap false") -- removes tone mapping
	rust.RunClientCommand(netuser, "terrain.idleinterval 0") -- stops the system from drawing unseen textures
	rust.RunClientCommand(netuser, "grass.disp_trail_seconds 0") -- disables trails in grass created by npcs/players
	rust.RunClientCommand(netuser, "gfx.ssao false") -- disables screen space ambient occlusion
	rust.RunClientCommand(netuser, "gfx.bloom false") -- removes bloom effect
	rust.RunClientCommand(netuser, "gfx.ssaa false") -- disables super sampling anti aliasing
	rust.RunClientCommand(netuser, "gfx.shafts false") -- disables sun rays effect
	rust.RunClientCommand(netuser, "render.level 0") -- lowers render level
	rust.RunClientCommand(netuser, "env.clouds false") -- disables clouds
	rust.RunClientCommand(netuser, "grass.on false") -- disables grass
	

end

--remove FPS boost
function PLUGIN:TurnOffBoost(netuser, cmd, args)
	rust.SendChatToUser( netuser, "Removed Boost.");
	rust.RunClientCommand(netuser, "notice.inventory UNBOOSTED");

	i = 1;


	rust.RunClientCommand(netuser, "gfx.tonemap true") 
	rust.RunClientCommand(netuser, "terrain.idleinterval 1") 
	rust.RunClientCommand(netuser, "grass.disp_trail_seconds 1")
	rust.RunClientCommand(netuser, "gfx.ssao true") 
	rust.RunClientCommand(netuser, "gfx.bloom true") 
	rust.RunClientCommand(netuser, "gfx.ssaa true") 
	rust.RunClientCommand(netuser, "gfx.shafts true") 
	rust.RunClientCommand(netuser, "render.level 1") 
	rust.RunClientCommand(netuser, "env.clouds true") 
	rust.RunClientCommand(netuser, "grass.on true") 
	

end

--Toggle Grass
function PLUGIN:ToggleGrass(netuser, cmd, args)
	rust.SendChatToUser( netuser, "Grass has been toggled.");
	rust.RunClientCommand(netuser, "notice.inventory Applied");
		
	if i == 1 then
		rust.RunClientCommand(netuser, "grass.on false") 
		i = 0;
	elseif i == 0 then
		rust.RunClientCommand(netuser, "grass.on true") 
		i = 1;
	end	

	

end

--Help Text
function PLUGIN:SendHelpText( netuser )
		rust.SendChatToUser( netuser, "Use /fps to boost your game's performance or /fpsoff to undo the changes." )
		rust.SendChatToUser( netuser, "Use /grass to toggle grass on or off." )
end




