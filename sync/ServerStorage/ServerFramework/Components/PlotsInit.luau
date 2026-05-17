--< Services
local Players = game:GetService("Players")

--< Modules
local PlotsManager = require(game:GetService("ServerStorage"):WaitForChild("ServerFramework"):WaitForChild("Modules"):WaitForChild("PlotsManager"))


return function ()
	Players.PlayerAdded:Connect(function(player: Player) 
		PlotsManager:AssignPlot(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player: Player, reason: Enum.PlayerExitReason)
		PlotsManager:ReleasePlot(player)
	end)
end