local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local SpeedUpgradeService = Framework:CreateService("SpeedUpgradeService")
local EconomyMath = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Utils"):WaitForChild("EconomyMath"))
local Players = game:GetService("Players")

function SpeedUpgradeService:Start()
	self.DataService = Framework:GetService("DataService")

	local function onCharacterAdded(player, character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			local runSpeed = self.DataService:GetData(player.UserId, "RunSpeed") or 0
			if not character:FindFirstChild("BrainrotMorph") then
				humanoid.WalkSpeed = EconomyMath.GetWalkSpeed(Framework.Config, runSpeed)
			end
		end
	end

	local function onPlayerAdded(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

function SpeedUpgradeService.Client:BuyUpgrade(Player: Player, upgradeName: string, buttonName: string)
	if upgradeName ~= "+1 Speed" then
		print("[SpeedUpgradeService] Invalid upgrade name:", upgradeName)
		return false
	end

	local userId = Player.UserId
	local speedConfig = Framework.Config.Economy.Speed
	local maxLevel = speedConfig.MaxUpgradeLevel

	local currentLevel = self.DataService:GetData(userId, "RunSpeed") or 0
	local cash = self.DataService:GetData(userId, "Cash") or 0

	if currentLevel >= maxLevel then
		print("[SpeedUpgradeService] Player already at max speed level")
		return false
	end

	if buttonName == "Buy1" then
		local cost = EconomyMath.GetSpeedUpgradeCost(Framework.Config, currentLevel)
		if cash >= cost then
			self.DataService:AddPlayerData(userId, "Cash", -cost)
			self.DataService:AddPlayerData(userId, "RunSpeed", 1)
			
			local character = Player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and not character:FindFirstChild("BrainrotMorph") then
				humanoid.WalkSpeed = EconomyMath.GetWalkSpeed(Framework.Config, currentLevel + 1)
			end
			return true
		else
			print("[SpeedUpgradeService] Not enough cash")
			return false
		end
	elseif buttonName == "BuyHalf" then
		local spendLimit = cash / 2
		local totalCost = 0
		local levelsToBuy = 0
		local level = currentLevel
		
		while level < maxLevel do
			local cost = EconomyMath.GetSpeedUpgradeCost(Framework.Config, level)
			if totalCost + cost <= spendLimit then
				totalCost += cost
				levelsToBuy += 1
				level += 1
			else
				break
			end
		end

		if levelsToBuy > 0 then
			self.DataService:AddPlayerData(userId, "Cash", -totalCost)
			self.DataService:AddPlayerData(userId, "RunSpeed", levelsToBuy)
			
			local character = Player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and not character:FindFirstChild("BrainrotMorph") then
				humanoid.WalkSpeed = EconomyMath.GetWalkSpeed(Framework.Config, level)
			end
			return true
		else
			print("[SpeedUpgradeService] Cannot afford any levels within half cash budget")
			return false
		end
	elseif buttonName == "BuyMax" then
		local totalCost = 0
		local levelsToBuy = 0
		local level = currentLevel
		
		while level < maxLevel do
			local cost = EconomyMath.GetSpeedUpgradeCost(Framework.Config, level)
			if totalCost + cost <= cash then
				totalCost += cost
				levelsToBuy += 1
				level += 1
			else
				break
			end
		end

		if levelsToBuy > 0 then
			self.DataService:AddPlayerData(userId, "Cash", -totalCost)
			self.DataService:AddPlayerData(userId, "RunSpeed", levelsToBuy)
			
			local character = Player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and not character:FindFirstChild("BrainrotMorph") then
				humanoid.WalkSpeed = EconomyMath.GetWalkSpeed(Framework.Config, level)
			end
			return true
		else
			print("[SpeedUpgradeService] Not enough cash for max buy")
			return false
		end
	end

	return false
end

return SpeedUpgradeService
