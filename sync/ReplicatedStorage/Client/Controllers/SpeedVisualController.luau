local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local SpeedVisualController = Framework:CreateController("SpeedVisualController")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getEquippedTool(player)
	local character = player.Character

	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end

	return nil
end

function SpeedVisualController:Initialize()
	pcall(function()
		self.ReplicaController = Framework:GetController("ReplicaController")
		self.EquipController = Framework:GetController("EquipController")
	end)
end

function SpeedVisualController:Start()
	if not self.ReplicaController then
		warn("[SpeedVisualController] ReplicaController not found, skipping.")
		return
	end

	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

	local configs = ReplicatedStorage:FindFirstChild("Configs")
	local gearsConfigModule = configs and configs:FindFirstChild("GearsConfig")

	if not gearsConfigModule then
		warn("[SpeedVisualController] GearsConfig not found, skipping.")
		return
	end

	local gearsConfig
	local gearsOk = pcall(function()
		gearsConfig = require(gearsConfigModule)
	end)

	if not gearsOk then
		warn("[SpeedVisualController] GearsConfig failed to load, skipping.")
		return
	end

	local hud = PlayerGui:FindFirstChild("HUD")
	local bottomLeft = hud and hud:FindFirstChild("BottomLeft")
	local currency = bottomLeft and bottomLeft:FindFirstChild("Currency")
	local power = currency and currency:FindFirstChild("Power")
	local speed = power and power:FindFirstChild("Speed")
	local speedLabel = speed and speed:FindFirstChild("SpeedLabel")

	if not speedLabel then
		warn("[SpeedVisualController] SpeedLabel not found, skipping.")
		return
	end

	local function updateSpeed()
		local data = self.ReplicaController:GetPlayerData()
		local speed = (data and data.Upgrades and data.Upgrades.MovementSpeed) or 0

		local tool = getEquippedTool(LocalPlayer)
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

	local replica = self.ReplicaController:GetReplica()
	if replica and replica.OnSet then
		replica:OnSet({ "Upgrades" }, updateSpeed)
	end

	if self.EquipController and self.EquipController.ToolAdded then
		self.EquipController.ToolAdded:Connect(updateSpeed)
	end

	if self.EquipController and self.EquipController.ToolRemoved then
		self.EquipController.ToolRemoved:Connect(updateSpeed)
	end

	LocalPlayer.CharacterAdded:Connect(function()
		task.defer(updateSpeed)
	end)
end

return SpeedVisualController
