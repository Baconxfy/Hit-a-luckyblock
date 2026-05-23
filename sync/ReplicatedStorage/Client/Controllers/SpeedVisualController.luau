local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local SpeedVisualController = Framework:CreateController("SpeedVisualController")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"):WaitForChild("EconomyMath"))

function SpeedVisualController:Initialize()
	pcall(function()
		self.ReplicaController = Framework:GetController("ReplicaController")
		self.EquipController = Framework:GetController("EquipController")
	end)
end

function SpeedVisualController:Start()
	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

	local GearsConfig = nil
	local configsFolder = ReplicatedStorage:FindFirstChild("Configs")
	local gearsConfigInstance = configsFolder and configsFolder:FindFirstChild("GearsConfig")
	if gearsConfigInstance then
		GearsConfig = require(gearsConfigInstance)
	else
		warn(
			"[SpeedVisualController] GearsConfig not found in ReplicatedStorage.Configs. Using fallback speed boost multipliers."
		)
	end

	-- Safe finding HUD speed label to avoid infinite yield
	local hud = PlayerGui:WaitForChild("HUD", 5)
	local speedLabel = nil
	if hud then
		local bottomLeft = hud:FindFirstChild("BottomLeft")
		local currency = bottomLeft and bottomLeft:FindFirstChild("Currency")
		local power = currency and currency:FindFirstChild("Power")
		local speedFrame = power and power:FindFirstChild("Speed")
		speedLabel = speedFrame and speedFrame:FindFirstChild("SpeedLabel")
	end

	local function updateSpeed()
		local data = self.ReplicaController:GetPlayerData()
		local runSpeed = (data and data.RunSpeed) or 0
		local speed = EconomyMath.GetWalkSpeed(Framework.Config, runSpeed)

		local character = LocalPlayer.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		if tool and tool:GetAttribute("GearType") == "SpeedCoil" then
			local gearId = tool:GetAttribute("GearId")
			if GearsConfig and GearsConfig.GEARS and GearsConfig.GEARS[gearId] then
				speed = speed * GearsConfig.GEARS[gearId].stats.speedBoost
			else
				speed = speed * 1.5
			end
		end

		if speedLabel then
			speedLabel.Text = string.format("Speed: %d", math.round(speed))
			local innerSpeed = speedLabel:FindFirstChild("Speed")
			if innerSpeed then
				innerSpeed.Text = speedLabel.Text
			end
		end

		-- Synchronize SpeedText in Rebirth UI
		local rebirthGui = PlayerGui:FindFirstChild("Rebirth")
		local mainFrame = rebirthGui and rebirthGui:FindFirstChild("Main")
		local bar = mainFrame and mainFrame:FindFirstChild("Bar")
		local speedText = bar and bar:FindFirstChild("SpeedText")
		if speedText then
			local rebirths = (data and data.Rebirths) or 0
			local reqSpeed = EconomyMath.GetRebirthRequirement(Framework.Config, rebirths)
			speedText.Text = string.format("%d / %d", math.round(speed), reqSpeed)
			local innerText = speedText:FindFirstChild("TextLabel")
			if innerText then
				innerText.Text = speedText.Text
			end
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
		replica:OnSet({ "RunSpeed" }, updateSpeed)
		replica:OnSet({ "Rebirths" }, updateSpeed)
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
