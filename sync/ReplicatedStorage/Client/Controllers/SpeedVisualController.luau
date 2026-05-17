local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local SpeedVisualController = Framework:CreateController("SpeedVisualController")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function SpeedVisualController:Initialize()
	pcall(function()
		self.ReplicaController = Framework:GetController("ReplicaController")
		self.EquipController = Framework:GetController("EquipController")
	end)
end

function SpeedVisualController:Start()
	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	
	local CharacterUtil = Framework.Utils.CharacterUtil
	local gearsConfig
	local gearsOk = pcall(function()
		gearsConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("GearsConfig"))
	end)
	if not gearsOk then
		warn("[SpeedVisualController] GearsConfig not found, skipping.")
		return
	end
	
	local speedLabel = PlayerGui:WaitForChild("HUD"):WaitForChild("BottomLeft"):WaitForChild("Currency"):WaitForChild("Power"):WaitForChild("Speed"):WaitForChild("SpeedLabel")
	
	local function updateSpeed()
		local data = self.ReplicaController:GetPlayerData()
		local speed = (data and data.Upgrades and data.Upgrades.MovementSpeed) or 0
		
		local tool = CharacterUtil.GetEquippedTool(LocalPlayer)
		if tool and tool:GetAttribute("GearType") == "SpeedCoil" then
			local gearId = tool:GetAttribute("GearId")
			if gearsConfig.GEARS and gearsConfig.GEARS[gearId] then
				speed = speed * gearsConfig.GEARS[gearId].stats.speedBoost
			end
		end
		
		speedLabel.Text = string.format("Speed: %d", math.round(speed))
		local innerSpeed = speedLabel:FindFirstChild("Speed")
		if innerSpeed then
			innerSpeed.Text = speedLabel.Text
		end
	end
	
	task.spawn(function()
		updateSpeed()
	end)
	
	if not self.ReplicaController or not self.EquipController then
		warn("[SpeedVisualController] Replica/Equip Controller not found, skipping.")
		return
	end
	
	local replica = self.ReplicaController:GetReplica()
	if replica and replica.OnSet then
		replica:OnSet({ "Upgrades" }, updateSpeed)
	end
	
	if self.EquipController.ToolAdded then
		self.EquipController.ToolAdded:Connect(updateSpeed)
	end
	if self.EquipController.ToolRemoved then
		self.EquipController.ToolRemoved:Connect(updateSpeed)
	end
	
	LocalPlayer.CharacterAdded:Connect(function()
		task.defer(updateSpeed)
	end)
end

return SpeedVisualController
