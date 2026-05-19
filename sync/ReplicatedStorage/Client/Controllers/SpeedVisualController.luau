local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local SpeedVisualController = Framework:CreateController("SpeedVisualController")

local function getEquippedTool(player: Player): Tool?
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

local function findSpeedLabel(playerGui: PlayerGui): TextLabel?
	local hud = playerGui:FindFirstChild("HUD")

	if hud then
		local bottomLeft = hud:FindFirstChild("BottomLeft")
		local currency = bottomLeft and bottomLeft:FindFirstChild("Currency")
		local power = currency and currency:FindFirstChild("Power")
		local speed = power and power:FindFirstChild("Speed")
		local speedLabel = speed and speed:FindFirstChild("SpeedLabel")

		if speedLabel and speedLabel:IsA("TextLabel") then
			return speedLabel
		end
	end

	local fallback = playerGui:FindFirstChild("SpeedLabel", true)

	if fallback and fallback:IsA("TextLabel") then
		return fallback
	end

	return nil
end

local function getSpeedFromData(data)
	if type(data) ~= "table" then
		return 0
	end

	if tonumber(data.RunSpeed) then
		return tonumber(data.RunSpeed)
	end

	local upgrades = data.Upgrades

	if type(upgrades) == "table" then
		return tonumber(upgrades.RunSpeed)
			or tonumber(upgrades.Speed)
			or tonumber(upgrades.MovementSpeed)
			or 0
	end

	return 0
end

local function getSpeedMultiplierFromTool(tool: Tool?): number
	if not tool then
		return 1
	end

	if tool:GetAttribute("GearType") ~= "SpeedCoil" then
		return 1
	end

	local multiplier = tool:GetAttribute("SpeedMultiplier")
		or tool:GetAttribute("speedBoost")
		or tool:GetAttribute("SpeedBoost")

	if tonumber(multiplier) then
		return tonumber(multiplier)
	end

	return 1
end

function SpeedVisualController:Initialize()
	self.ReplicaController = Framework:GetController("ReplicaController")
	self._connections = {}
end

function SpeedVisualController:Start()
	if not self.ReplicaController then
		warn("[SpeedVisualController] ReplicaController not found, skipping.")
		return
	end

	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local speedLabel = findSpeedLabel(playerGui)

	if not speedLabel then
		warn("[SpeedVisualController] SpeedLabel not found, skipping.")
		return
	end

	local function setText(text)
		speedLabel.Text = text

		local innerSpeedLabel = speedLabel:FindFirstChild("Speed")

		if innerSpeedLabel and innerSpeedLabel:IsA("TextLabel") then
			innerSpeedLabel.Text = text
		end
	end

	local function updateSpeed()
		local data = self.ReplicaController:GetPlayerData()
		local baseSpeed = getSpeedFromData(data)
		local multiplier = getSpeedMultiplierFromTool(getEquippedTool(localPlayer))
		local finalSpeed = math.round(baseSpeed * multiplier)

		setText(`Speed: {finalSpeed}`)
	end

	local function connectCharacter(character: Model)
		table.insert(self._connections, character.ChildAdded:Connect(function()
			updateSpeed()
		end))

		table.insert(self._connections, character.ChildRemoved:Connect(function()
			updateSpeed()
		end))

		task.defer(updateSpeed)
	end

	if localPlayer.Character then
		connectCharacter(localPlayer.Character)
	end

	table.insert(self._connections, localPlayer.CharacterAdded:Connect(connectCharacter))

	local replica = self.ReplicaController:GetReplica()

	if replica and replica.OnSet then
		replica:OnSet({ "RunSpeed" }, updateSpeed)
		replica:OnSet({ "Upgrades" }, updateSpeed)
	end

	task.defer(updateSpeed)
end

function SpeedVisualController:CleanUp()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end

	table.clear(self._connections)
end

return SpeedVisualController