local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Framework)

local HitLuckyBlockService = Framework:CreateService("HitLuckyBlockService")

HitLuckyBlockService.Client = {}

local function getCharacterRoot(player)
	local character = player.Character

	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function isVector3(value)
	return typeof(value) == "Vector3"
end

local function sanitizeDirection(direction, fallback)
	if not isVector3(direction) or direction.Magnitude < 0.001 then
		return fallback
	end

	return direction.Unit
end

function HitLuckyBlockService:Initialize()
	self.Config = Framework.Config
	self.EconomyMath = Framework.Utils.EconomyMath
	self.KickCalculator = Framework.Utils.KickCalculator

	self._cooldowns = {}
	self._busyPlayers = {}
	self._candidates = {}
	self._candidateConnections = {}
	self._rng = Random.new()
end

function HitLuckyBlockService:Start()
	self.DataService = Framework:GetService("DataService")
	self.HitLuckyBlockVisualController = Framework:GetController("HitLuckyBlockVisualController")
	self:_bindCandidateCache()

	Players.PlayerRemoving:Connect(function(player)
		self._cooldowns[player] = nil
		self._busyPlayers[player] = nil
	end)
end

function HitLuckyBlockService:_getBrainrotAssetsFolder()
	local assets = ReplicatedStorage:FindFirstChild("Assets")

	if not assets then
		return nil
	end

	return assets:FindFirstChild("Brainrots")
end

function HitLuckyBlockService:_disconnectCandidateCache()
	for _, connection in ipairs(self._candidateConnections) do
		connection:Disconnect()
	end

	table.clear(self._candidateConnections)
end

function HitLuckyBlockService:_rebuildCandidateCache()
	local brainrotsFolder = self:_getBrainrotAssetsFolder()
	local candidates = {}

	if not brainrotsFolder then
		self._candidates = candidates
		return
	end

	for _, brainrotFolder in brainrotsFolder:GetChildren() do
		if not brainrotFolder:IsA("Folder") then
			continue
		end

		for _, mutationOrModel in brainrotFolder:GetChildren() do
			if mutationOrModel:IsA("Model") or mutationOrModel:IsA("BasePart") then
				table.insert(candidates, {
					Brainrot = brainrotFolder.Name,
					Mutation = mutationOrModel.Name,
					Template = mutationOrModel,
				})
			elseif mutationOrModel:IsA("Folder") then
				local template = mutationOrModel:FindFirstChildWhichIsA("Model") or mutationOrModel:FindFirstChildWhichIsA("BasePart")

				if template then
					table.insert(candidates, {
						Brainrot = brainrotFolder.Name,
						Mutation = mutationOrModel.Name,
						Template = template,
					})
				end
			end
		end
	end

	self._candidates = candidates
end

function HitLuckyBlockService:_bindCandidateCache()
	local brainrotsFolder = self:_getBrainrotAssetsFolder()

	self:_disconnectCandidateCache()
	self:_rebuildCandidateCache()

	if not brainrotsFolder then
		return
	end

	local function watchBrainrotFolder(brainrotFolder)
		if not brainrotFolder:IsA("Folder") then
			return
		end

		table.insert(self._candidateConnections, brainrotFolder.ChildAdded:Connect(function()
			self:_rebuildCandidateCache()
		end))

		table.insert(self._candidateConnections, brainrotFolder.ChildRemoved:Connect(function()
			self:_rebuildCandidateCache()
		end))
	end

	for _, brainrotFolder in ipairs(brainrotsFolder:GetChildren()) do
		watchBrainrotFolder(brainrotFolder)
	end

	table.insert(self._candidateConnections, brainrotsFolder.ChildAdded:Connect(function(child)
		watchBrainrotFolder(child)
		self:_rebuildCandidateCache()
	end))

	table.insert(self._candidateConnections, brainrotsFolder.ChildRemoved:Connect(function()
		self:_rebuildCandidateCache()
	end))
end

function HitLuckyBlockService:_chooseCandidate()
	local candidates = self._candidates

	if #candidates == 0 then
		return nil
	end

	return candidates[self._rng:NextInteger(1, #candidates)]
end

function HitLuckyBlockService:_getLuckyBlockConfig()
	return self.Config.LuckyBlock or (self.Config.Shared and self.Config.Shared.LuckyBlock)
end

function HitLuckyBlockService:_getEconomyConfig()
	return self.Config.Economy or (self.Config.Shared and self.Config.Shared.Economy)
end

function HitLuckyBlockService:_isOnCooldown(player)
	local now = os.clock()
	local cooldown = self:_getLuckyBlockConfig().HitCooldown
	local nextAllowed = self._cooldowns[player] or 0

	if now < nextAllowed then
		return true, nextAllowed - now
	end

	self._cooldowns[player] = now + cooldown

	return false, 0
end

function HitLuckyBlockService:_setBusy(player, busy)
	if busy then
		self._busyPlayers[player] = true
	else
		self._busyPlayers[player] = nil
	end
end

function HitLuckyBlockService:_getSafeOriginAndDirection(player, clientOrigin, clientDirection)
	local root = getCharacterRoot(player)

	if not root then
		return nil, nil, "NoCharacter"
	end

	local origin = root.Position + Vector3.yAxis * 2

	if isVector3(clientOrigin) then
		local maxOffset = self:_getLuckyBlockConfig().MaxAimDistanceFromCharacter

		if (clientOrigin - root.Position).Magnitude <= maxOffset then
			origin = clientOrigin
		end
	end

	local direction = sanitizeDirection(clientDirection, root.CFrame.LookVector)

	return origin, direction, nil
end

function HitLuckyBlockService:_playFlyingVisual(player, candidate, flight)
	if not candidate then
		return
	end

	if not self.HitLuckyBlockVisualController then
		return
	end

	self.HitLuckyBlockVisualController.Server.Fire.PlayFlight(self.HitLuckyBlockVisualController, player, {
		Brainrot = candidate.Brainrot,
		Mutation = candidate.Mutation,
		StartPosition = flight.StartPosition,
		TargetPosition = flight.TargetPosition,
		ControlPosition = flight.ControlPosition,
		Duration = self:_getLuckyBlockConfig().Flight.Duration,
		SpinSpeed = self:_getLuckyBlockConfig().Flight.SpinSpeed,
		VisualLifetime = self:_getLuckyBlockConfig().VisualLifetime,
	})
end

function HitLuckyBlockService:HandleHit(player, clientOrigin, clientDirection)
	if self._busyPlayers[player] then
		return {
			Ok = false,
			Reason = "Busy",
		}
	end

	local onCooldown, remaining = self:_isOnCooldown(player)

	if onCooldown then
		return {
			Ok = false,
			Reason = "Cooldown",
			Remaining = remaining,
		}
	end

	self:_setBusy(player, true)

	local profile = self.DataService:GetProfile(player)

	if not profile then
		self:_setBusy(player, false)
		return {
			Ok = false,
			Reason = "DataNotLoaded",
		}
	end

	local origin, direction, originError = self:_getSafeOriginAndDirection(player, clientOrigin, clientDirection)

	if originError then
		self:_setBusy(player, false)
		return {
			Ok = false,
			Reason = originError,
		}
	end

	local data = profile.Data
	local economy = self:_getEconomyConfig()
	local luckyBlockConfig = self:_getLuckyBlockConfig()

	local kickPower = self.KickCalculator.GetPowerFromData(economy, data)
	local cashMultiplier = self.EconomyMath.GetCashMultiplier(economy, data.Rebirths or 0)
	local cashReward = self.KickCalculator.GetCashReward(economy, kickPower, cashMultiplier)
	local powerGain = self.KickCalculator.GetPowerGain(economy)

	local flight = self.KickCalculator.GetFlight(economy, origin, direction, kickPower)
	local candidate = self:_chooseCandidate()

	self.DataService:AddCash(player, cashReward)
	self.DataService:AddKickPower(player, powerGain)

	self:_playFlyingVisual(player, candidate, flight)

	task.delay(luckyBlockConfig.Flight.Duration, function()
		if player.Parent then
			self:_setBusy(player, false)
		end
	end)

	return {
		Ok = true,

		Reward = cashReward,
		PowerGain = powerGain,
		KickPower = kickPower + powerGain,

		Flight = {
			StartPosition = flight.StartPosition,
			TargetPosition = flight.TargetPosition,
			ControlPosition = flight.ControlPosition,
			Distance = flight.Distance,
			ArcHeight = flight.ArcHeight,
			Duration = luckyBlockConfig.Flight.Duration,
		},

		Brainrot = if candidate then {
			Name = candidate.Brainrot,
			Mutation = candidate.Mutation,
		} else nil,
	}
end

function HitLuckyBlockService.Client:Hit(player, clientOrigin, clientDirection)
	return HitLuckyBlockService:HandleHit(player, clientOrigin, clientDirection)
end

return HitLuckyBlockService
