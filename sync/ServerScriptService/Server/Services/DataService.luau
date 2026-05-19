local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
		ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Packages"),
		ReplicatedStorage:FindFirstChild("Packages"),
		ServerScriptService:FindFirstChild("Server") and ServerScriptService.Server:FindFirstChild("Packages"),
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

local function getConfigValue(config, key)
	if config[key] ~= nil then
		return config[key]
	end

	if config.Shared and config.Shared[key] ~= nil then
		return config.Shared[key]
	end

	return nil
end

local function getProfileStoreName(config)
	local studioVersion = getConfigValue(config, "DataVersionStudio")
	local liveVersion = getConfigValue(config, "DataVersion")

	if RunService:IsStudio() and studioVersion then
		return studioVersion
	end

	return liveVersion or "HitALuckyblock-v1"
end

local function getValueClassName(value)
	if typeof(value) == "string" then
		return "StringValue"
	end

	if typeof(value) == "boolean" then
		return "BoolValue"
	end

	return "NumberValue"
end

local function getDefaultValueForClass(className: string)
	if className == "StringValue" then
		return ""
	end

	if className == "BoolValue" then
		return false
	end

	return 0
end

function DataService:Initialize()
	self.Config = Framework.Config

	local ProfileStore = requirePackage("ProfileStore")
	local ProfileTemplate = requirePackage("Template")

	self.ProfileStore = ProfileStore.New(
		getProfileStoreName(self.Config),
		deepCopy(ProfileTemplate)
	)

	self.Profiles = {}
	self._leaderstats = {}

	self._dataChangedEvent = self:Event("DataChanged")
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
	player:SetAttribute("DataLoaded", false)

	local profile = self.ProfileStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick("Data failed to load.\nPlease rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		self.Profiles[player] = nil
		self._leaderstats[player] = nil

		if player.Parent == Players then
			player:Kick("Your data was opened somewhere else.\nPlease rejoin.")
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

	self:_fireDataChanged(player)
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
	local studioConfig = getConfigValue(self.Config, "Studio")

	if not studioConfig or not studioConfig.Enabled then
		return
	end

	local startingCash = studioConfig.StartingCash or 0

	if startingCash > (profile.Data.Cash or 0) then
		profile.Data.Cash = startingCash
		self:UpdateLeaderstats(player)
	end
end

function DataService:_createLeaderstats(player: Player, profile)
	local leaderstats = getOrCreateValue(player, "Folder", "leaderstats")
	local values = {}

	local categories = getConfigValue(self.Config, "LeaderstatsCategories")
	categories = categories or {
		"Cash",
		"Rebirths",
	}

	for _, statName in ipairs(categories) do
		local dataValue = profile.Data[statName]
		local className = getValueClassName(dataValue)

		local value = getOrCreateValue(leaderstats, className, statName)
		value.Value = if dataValue ~= nil then dataValue else getDefaultValueForClass(className)

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
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return nil
	end

	if type(self.Profiles) ~= "table" then
		return nil
	end

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

function DataService:IsLoaded(player: Player): boolean
	return self:GetProfile(player) ~= nil
end

function DataService:Mutate(player: Player, callback)
	local profile = self:GetProfile(player)

	if not profile then
		return false, "DataNotLoaded"
	end

	if typeof(callback) ~= "function" then
		return false, "InvalidCallback"
	end

	local ok, result = pcall(callback, profile.Data, profile)

	if not ok then
		warn("[DataService] mutation failed:", result)
		return false, "MutationFailed"
	end

	self:UpdateLeaderstats(player)
	self:_fireDataChanged(player)

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

function DataService:SetCash(player: Player, amount: number)
	amount = math.max(math.floor(tonumber(amount) or 0), 0)

	return self:Mutate(player, function(data)
		data.Cash = amount
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

function DataService:AddRebirths(player: Player, amount: number)
	amount = math.floor(tonumber(amount) or 0)

	if amount == 0 then
		return false, "InvalidAmount"
	end

	return self:Mutate(player, function(data)
		data.Rebirths = math.max(0, (data.Rebirths or 0) + amount)
		return data.Rebirths
	end)
end

function DataService:SetRebirths(player: Player, amount: number)
	amount = math.max(math.floor(tonumber(amount) or 0), 0)

	return self:Mutate(player, function(data)
		data.Rebirths = amount
		return data.Rebirths
	end)
end

function DataService:AddKickPower(player: Player, amount: number)
	amount = tonumber(amount) or 0

	if amount == 0 then
		return false, "InvalidAmount"
	end

	return self:Mutate(player, function(data)
		local economy = getConfigValue(self.Config, "Economy") or {}
		local startingKickPower = economy.StartingKickPower or 1

		data.KickPower = math.max(1, (data.KickPower or startingKickPower) + amount)

		return data.KickPower
	end)
end

function DataService:SetKickPower(player: Player, amount: number)
	amount = math.max(tonumber(amount) or 0, 0)

	return self:Mutate(player, function(data)
		data.KickPower = amount
		return data.KickPower
	end)
end

function DataService:AddRunSpeed(player: Player, amount: number)
	amount = tonumber(amount) or 0

	if amount == 0 then
		return false, "InvalidAmount"
	end

	return self:Mutate(player, function(data)
		data.RunSpeed = math.max(0, (data.RunSpeed or 0) + amount)
		return data.RunSpeed
	end)
end

function DataService:SetRunSpeed(player: Player, amount: number)
	amount = math.max(tonumber(amount) or 0, 0)

	return self:Mutate(player, function(data)
		data.RunSpeed = amount
		return data.RunSpeed
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

function DataService:_fireDataChanged(player: Player)
	if not self._dataChangedEvent then
		return
	end

	local publicData = self:GetPublicData(player)

	if not publicData then
		return
	end

	self._dataChangedEvent:Fire(player, publicData)
end

function DataService.Client.GetData(service, player: Player)
	return service:GetPublicData(player)
end

return DataService