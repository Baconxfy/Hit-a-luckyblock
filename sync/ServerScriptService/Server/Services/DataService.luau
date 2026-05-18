local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local DataService = Framework:CreateService("DataService")

DataService.Client = {}

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end

	local copy = {}

	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end

	return copy
end

local function requirePackage(packageName: string)
	local packageLocations = {
		ReplicatedStorage:FindFirstChild("Shared")
			and ReplicatedStorage.Shared:FindFirstChild("Packages"),

		ReplicatedStorage:FindFirstChild("Packages"),

		ServerScriptService:FindFirstChild("Server")
			and ServerScriptService.Server:FindFirstChild("Packages"),
	}

	for _, folder in ipairs(packageLocations) do
		if folder then
			local module = folder:FindFirstChild(packageName, true)

			if module and module:IsA("ModuleScript") then
				return require(module)
			end
		end
	end

	error(`Missing package {packageName}`)
end

local function getOrCreateValue(parent: Instance, className: string, name: string)
	local value = parent:FindFirstChild(name)

	if value and value.ClassName == className then
		return value
	end

	if value then
		value:Destroy()
	end

	value = Instance.new(className)
	value.Name = name
	value.Parent = parent

	return value
end

function DataService:Initialize()
	self.Config = Framework.Config

	local ProfileStore = requirePackage("ProfileStore")

	self.ProfileStore = ProfileStore.New(
		self.Config.Runtime.ProfileStoreName,
		deepCopy(self.Config.Runtime.ProfileTemplate)
	)

	self.Profiles = {}
	self._leaderstats = {}
end

function DataService:Start()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_playerAdded(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		self:_playerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_playerRemoving(player)
	end)
end

function DataService:_playerAdded(player: Player)
	local profile = self.ProfileStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick("Data failed to load. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		self.Profiles[player] = nil
		self._leaderstats[player] = nil

		if player.Parent == Players then
			player:Kick("Your data was opened somewhere else. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	self.Profiles[player] = profile

	self:_createLeaderstats(player, profile)
	self:_applyStudioOverrides(player, profile)

	player:SetAttribute("DataLoaded", true)
end

function DataService:_playerRemoving(player: Player)
	local profile = self.Profiles[player]

	self.Profiles[player] = nil
	self._leaderstats[player] = nil

	if profile then
		profile:EndSession()
	end
end

function DataService:_applyStudioOverrides(player: Player, profile)
	local studioConfig = self.Config.Shared and self.Config.Shared.Studio or self.Config.Studio

	if not studioConfig or not studioConfig.Enabled then
		return
	end

	local startingCash = studioConfig.StartingCash or 0

	if startingCash > profile.Data.Cash then
		profile.Data.Cash = startingCash
		self:UpdateLeaderstats(player)
	end
end

function DataService:_createLeaderstats(player: Player, profile)
	local leaderstats = getOrCreateValue(player, "Folder", "leaderstats")
	local values = {}

	local categories = self.Config.LeaderstatsCategories

	if self.Config.Shared and self.Config.Shared.LeaderstatsCategories then
		categories = self.Config.Shared.LeaderstatsCategories
	end

	categories = categories or {
		"Cash",
		"Rebirths",
		"KickPower",
	}

	for _, statName in ipairs(categories) do
		local className = "NumberValue"

		if typeof(profile.Data[statName]) == "string" then
			className = "StringValue"
		end

		local value = getOrCreateValue(leaderstats, className, statName)
		value.Value = profile.Data[statName] or 0
		values[statName] = value
	end

	self._leaderstats[player] = values
end

function DataService:UpdateLeaderstats(player: Player)
	local profile = self:GetProfile(player)
	local values = self._leaderstats[player]

	if not profile or not values then
		return
	end

	for statName, value in pairs(values) do
		local dataValue = profile.Data[statName]

		if dataValue ~= nil then
			value.Value = dataValue
		end
	end
end

function DataService:GetProfile(player: Player)
	return self.Profiles[player]
end

function DataService:GetData(player: Player)
	local profile = self:GetProfile(player)

	if not profile then
		return nil
	end

	return profile.Data
end

function DataService:GetPublicData(player: Player)
	local data = self:GetData(player)

	if not data then
		return nil
	end

	return deepCopy(data)
end

function DataService:Mutate(player: Player, callback)
	local profile = self:GetProfile(player)

	if not profile then
		return false, "DataNotLoaded"
	end

	local ok, result = pcall(callback, profile.Data)

	if not ok then
		warn("[DataService] mutation failed:", result)
		return false, "MutationFailed"
	end

	self:UpdateLeaderstats(player)

	return true, result
end

function DataService:AddCash(player: Player, amount: number)
	amount = math.floor(tonumber(amount) or 0)

	if amount == 0 then
		return false, "InvalidAmount"
	end

	return self:Mutate(player, function(data)
		data.Cash = math.max(0, (data.Cash or 0) + amount)
		return data.Cash
	end)
end

function DataService:SpendCash(player: Player, amount: number)
	amount = math.max(math.floor(tonumber(amount) or 0), 0)

	return self:Mutate(player, function(data)
		if (data.Cash or 0) < amount then
			return {
				Ok = false,
				Reason = "NotEnoughCash",
				Cash = data.Cash or 0,
			}
		end

		data.Cash -= amount

		return {
			Ok = true,
			Cash = data.Cash,
		}
	end)
end

function DataService:AddKickPower(player: Player, amount: number)
	amount = tonumber(amount) or 0

	if amount == 0 then
		return false, "InvalidAmount"
	end

	return self:Mutate(player, function(data)
		local economy = self.Config.Economy or self.Config.Shared.Economy
		local startingKickPower = economy.StartingKickPower or 1

		data.KickPower = math.max(1, (data.KickPower or startingKickPower) + amount)

		return data.KickPower
	end)
end

function DataService:SetUpgradeLevel(player: Player, upgradeName: string, level: number)
	level = math.max(math.floor(tonumber(level) or 0), 0)

	return self:Mutate(player, function(data)
		data.Upgrades = data.Upgrades or {}
		data.Upgrades[upgradeName] = level

		return level
	end)
end

function DataService.Client:GetData(player: Player)
	return DataService:GetPublicData(player)
end

return DataService