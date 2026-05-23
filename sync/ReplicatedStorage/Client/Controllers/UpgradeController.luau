local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local UpgradeController = Framework:CreateController("UpgradeController")

local Players = game:GetService("Players")

function UpgradeController:Start()
	self.SpeedUpgradeService = Framework:GetService("SpeedUpgradeService")
	
	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	local SpeedUpgradesGui = PlayerGui:WaitForChild("SpeedUpgrades")
	
	local menu = SpeedUpgradesGui:WaitForChild("Main")
	local scrollingFrame = menu:WaitForChild("ScrollingFrame")
	local closeBtn = menu:WaitForChild("Top"):WaitForChild("Main"):WaitForChild("Close")
	
	closeBtn.MouseButton1Click:Connect(function()
		menu.Visible = false
	end)
	
	for _, upgradeFrame in ipairs(scrollingFrame:GetChildren()) do
		if upgradeFrame:IsA("GuiObject") then
			local buttonsFrame = upgradeFrame:FindFirstChild("ButtonsFrame")
			if buttonsFrame then
				for _, button in ipairs(buttonsFrame:GetChildren()) do
					if button:IsA("GuiButton") and button.Name ~= "BuyRBX" then
						button.MouseButton1Click:Connect(function()
							print(button.Name .. " was clicked!")
							self.SpeedUpgradeService:BuyUpgrade(upgradeFrame.Name, button.Name)
						end)
					end
				end
			end
		end
	end
end

return UpgradeController
