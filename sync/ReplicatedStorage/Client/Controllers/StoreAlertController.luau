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
	if not self.ReplicaController then
		warn("[StoreAlertController] ReplicaController not found, skipping.")
		return
	end

	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

	local configs = ReplicatedStorage:FindFirstChild("Configs")
	local freeShopConfigModule = configs and configs:FindFirstChild("FreeShopConfig")

	if not freeShopConfigModule then
		warn("[StoreAlertController] FreeShopConfig not found, skipping.")
		return
	end

	local FreeShopConfig = require(freeShopConfigModule)

	local hud = PlayerGui:FindFirstChild("HUD")
	local leftButtons = hud and hud:FindFirstChild("LeftButtons")
	local storeButton = leftButtons and leftButtons:FindFirstChild("Store")
	local alertGui = storeButton and storeButton:FindFirstChild("Alert")

	if not alertGui then
		warn("[StoreAlertController] Store alert UI not found, skipping.")
		return
	end

	local function updateAlert()
		local data = self.ReplicaController:GetPlayerData()
		local lastClaim = (data and data.LastFreeShopClaim) or 0
		local hasClaim = lastClaim < FreeShopConfig.CURRENT_CLAIM_INDEX
		alertGui.Visible = hasClaim
	end

	task.spawn(function()
		updateAlert()
	end)

	local replica = self.ReplicaController:GetReplica()
	if replica and replica.OnSet then
		replica:OnSet({ "LastFreeShopClaim" }, function(newVal)
			local hasClaim = newVal < FreeShopConfig.CURRENT_CLAIM_INDEX
			alertGui.Visible = hasClaim
		end)
	end

	storeButton.Activated:Connect(function()
		if self.SoundController and self.SoundController.PlaySound then
			self.SoundController:PlaySound("OpenShop", {
				PlaybackSpeed = 1 + math.random(0, 5) / 10
			})
		end
	end)
end

return StoreAlertController
