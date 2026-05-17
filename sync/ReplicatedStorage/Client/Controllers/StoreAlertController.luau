local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local StoreAlertController = Framework:CreateController("StoreAlertController")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function StoreAlertController:Initialize()
	pcall(function()
		self.ReplicaController = Framework:GetController("ReplicaController")
		self.SoundController = Framework:GetController("SoundController")
	end)
end

function StoreAlertController:Start()
	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	
	local FreeShopConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("FreeShopConfig"))
	
	local storeButton = PlayerGui:WaitForChild("HUD"):WaitForChild("LeftButtons"):WaitForChild("Store")
	local alertGui = storeButton:WaitForChild("Alert")
	
	local function updateAlert()
		local data = self.ReplicaController:GetPlayerData()
		local lastClaim = (data and data.LastFreeShopClaim) or 0
		local hasClaim = lastClaim < FreeShopConfig.CURRENT_CLAIM_INDEX
		alertGui.Visible = hasClaim
	end
	
	task.spawn(function()
		updateAlert()
	end)
	
	if not self.ReplicaController then
		warn("[StoreAlertController] ReplicaController not found, skipping.")
		return
	end
	
	local replica = self.ReplicaController:GetReplica()
	if replica and replica.OnSet then
		replica:OnSet({ "LastFreeShopClaim" }, function(newVal)
			local hasClaim = newVal < FreeShopConfig.CURRENT_CLAIM_INDEX
			alertGui.Visible = hasClaim
		end)
	end
	
	storeButton.Activated:Connect(function()
		if self.SoundController.PlaySound then
			self.SoundController:PlaySound("OpenShop", {
				PlaybackSpeed = 1 + math.random(0, 5) / 10
			})
		end
	end)
end

return StoreAlertController
