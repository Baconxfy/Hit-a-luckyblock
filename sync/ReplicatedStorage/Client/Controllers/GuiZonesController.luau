local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local GuiZonesController = Framework:CreateController("GuiZonesController")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiController =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"):WaitForChild("GuiController"))
local ZonePlus = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ZonePlus"))

function GuiZonesController:Start()
	local ZonesFolder = workspace:WaitForChild("Zones", 120)
	if not ZonesFolder then
		return
	end

	local ShowWeightUIPart = ZonesFolder:WaitForChild("ShowWeightUI", 10)
	local ShowSpeedUpgradesPart = ZonesFolder:WaitForChild("ShowSpeedUpgrades", 10)

	if ShowWeightUIPart then
		local ShowWeightUIZone = ZonePlus.new(ShowWeightUIPart)
		local WeightUI = GuiController:GetGui("WeightUI")
		if WeightUI then
			local WeightUIMainFrame = GuiController:GetMainFrame(WeightUI)
			ShowWeightUIZone.localPlayerEntered:Connect(function()
				GuiController:ToggleMainFrame(WeightUIMainFrame)
			end)
			ShowWeightUIZone.localPlayerExited:Connect(function()
				if GuiController.CurrentMainFrame == WeightUIMainFrame then
					GuiController:ToggleMainFrame(WeightUIMainFrame)
				end
			end)
		end
	end

	if ShowSpeedUpgradesPart then
		local ShowRunUpgradesZone = ZonePlus.new(ShowSpeedUpgradesPart)
		local SpeedUpgrades = GuiController:GetGui("SpeedUpgrades")
		if SpeedUpgrades then
			local SpeedUpgradesMainFrame = GuiController:GetMainFrame(SpeedUpgrades)
			ShowRunUpgradesZone.localPlayerEntered:Connect(function()
				GuiController:ToggleMainFrame(SpeedUpgradesMainFrame)
			end)
			ShowRunUpgradesZone.localPlayerExited:Connect(function()
				if GuiController.CurrentMainFrame == SpeedUpgradesMainFrame then
					GuiController:ToggleMainFrame(SpeedUpgradesMainFrame)
				end
			end)
		end
	end
end

return GuiZonesController
