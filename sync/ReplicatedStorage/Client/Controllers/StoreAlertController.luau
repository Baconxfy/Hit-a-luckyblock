local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local StoreAlertController = Framework:CreateController("StoreAlertController")

function StoreAlertController:Initialize()
	self.ReplicaController = Framework:GetController("ReplicaController")
	self.SoundController = Framework:GetController("SoundController")
end

function StoreAlertController:Start()
	if not self.ReplicaController then
		warn("[StoreAlertController] ReplicaController not found, skipping.")
		return
	end

	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local configs = ReplicatedStorage:FindFirstChild("Configs")
	local freeShopConfigModule = configs and configs:FindFirstChild("FreeShopConfig")

	if not freeShopConfigModule then
		warn("[StoreAlertController] FreeShopConfig not found, skipping.")
		return
	end

	local FreeShopConfig = require(freeShopConfigModule)

	local hud = playerGui:FindFirstChild("HUD")
	local leftButtons = hud and hud:FindFirstChild("LeftButtons")
	local storeButton = leftButtons and leftButtons:FindFirstChild("Store")
	local alertGui = storeButton and storeButton:FindFirstChild("Alert")

	if not storeButton or not alertGui then
		warn("[StoreAlertController] Store alert UI not found, skipping.")
		return
	end

	local function updateAlert()
		local data = self.ReplicaController:GetPlayerData()
		local lastClaim = (data and data.LastFreeShopClaim) or 0

		alertGui.Visible = lastClaim < FreeShopConfig.CURRENT_CLAIM_INDEX
	end

	task.defer(updateAlert)

	local replica = self.ReplicaController:GetReplica()
	if replica and replica.OnSet then
		replica:OnSet({ "LastFreeShopClaim" }, function(newValue)
			local lastClaim = newValue or 0
			alertGui.Visible = lastClaim < FreeShopConfig.CURRENT_CLAIM_INDEX
		end)
	end

	storeButton.Activated:Connect(function()
		if self.SoundController and self.SoundController.PlaySound then
			self.SoundController:PlaySound("OpenShop", {
				PlaybackSpeed = 1 + math.random(0, 5) / 10,
			})
		end
	end)
end

return StoreAlertController