--< Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")


--< Modules
local GuiController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("GuiController"))
local ZonePlus = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ZonePlus"))

return function()
	
	--< Workspace Variables
	local ZonesFolder = workspace:WaitForChild("Zones", 120)
	
	local ShowWeightUIPart = ZonesFolder:WaitForChild("ShowWeightUI", 600)
	local ShowSpeedUpgradesPart = ZonesFolder:WaitForChild("ShowSpeedUpgrades", 600)
	
	local ShowWeightUIZone = ZonePlus.new(ShowWeightUIPart)
	local ShowRunUpgradesZone = ZonePlus.new(ShowSpeedUpgradesPart)
	
	local WeightUIMainFrame = GuiController:GetMainFrame(GuiController:GetGui("WeightUI"))
	local SpeedUpgradesMainFrame = GuiController:GetMainFrame(GuiController:GetGui("SpeedUpgrades"))
	
	ShowWeightUIZone.localPlayerEntered:Connect(function()
		GuiController:ToggleMainFrame(WeightUIMainFrame)
	end)
	
	ShowWeightUIZone.localPlayerExited:Connect(function()
		if GuiController.CurrentMainFrame == WeightUIMainFrame then
			GuiController:ToggleMainFrame(WeightUIMainFrame)
		end
	end)
	
	ShowRunUpgradesZone.localPlayerEntered:Connect(function()
		GuiController:ToggleMainFrame(SpeedUpgradesMainFrame)
	end)

	ShowRunUpgradesZone.localPlayerExited:Connect(function()
		if GuiController.CurrentMainFrame == SpeedUpgradesMainFrame then
			GuiController:ToggleMainFrame(SpeedUpgradesMainFrame)
		end
	end)


	
	
	
end