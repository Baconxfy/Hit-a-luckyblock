local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local HitLuckyBlockService = Framework:CreateService("HitLuckyBlockService")

HitLuckyBlockService.Client = {}

local ROLL_COUNT = 30
local MORPH_WALK_SPEED = 24
local MORPH_JUMP_POWER = 50
local RETURN_TIMEOUT = 90

local function clamp(value: number, minValue: number, maxValue: number): number
	return math.max(minValue, math.min(maxValue, value))
end

local function getCharacter(player: Player): Model?
	local character = player.Character
	if character and character:IsA("Model") then
		return character
	end

	return nil
end

local function getCharacterRoot(player: Player): BasePart?
	local character = getCharacter(player)
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function getHumanoid(player: Player): Humanoid?
	local character = getCharacter(player)
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function getEconomy(config)
	return config.Economy or (config.Shared and config.Shared.Economy) or {}
end

local function getLuckyBlockConfig(config)
	return config.LuckyBlock
		or (config.Shared and config.Shared.LuckyBlock)
		or {
			HitCooldown = 0.35,
			VisualLifetime = 5,
			Flight = {
				Duration = 0.85,
				SpinSpeed = 540,
			},
		}
end

local function flattenDirection(direction: Vector3): Vector3
	local flat = Vector3.new(direction.X, 0, direction.Z)

	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end

	return flat.Unit
end

local function setTransparencyAttribute(instance: Instance, attributeName: string, value: number)
	if instance:GetAttribute(attributeName) == nil then
		instance:SetAttribute(attributeName, value)
	end
end

local function restoreTransparencyAttribute(instance: Instance, attributeName: string)
	local value = instance:GetAttribute(attributeName)

	if typeof(value) == "number" then
		(instance :: any).Transparency = value
		instance:SetAttribute(attributeName, nil)
	end
end

function HitLuckyBlockService:Initialize()
	self.Config = Framework.Config
	self.EconomyMath = Framework.Utils.EconomyMath
	self.KickCalculator = Framework.Utils.KickCalculator

	self._cooldowns = {}
	self._busyPlayers = {}
	self._states = {}
	self._candidateConnections = {}
	self._candidates = {}
	self._rng = Random.new()
	self._safeTouchedConnection = nil
end

function HitLuckyBlockService:Start()
	self.DataService = Framework:GetService("DataService")
	self.HitLuckyBlockVisualController = Framework:GetController("HitLuckyBlockVisualController")

	self:_bindCandidateCache()
	self:_bindSafezone()

	Players.PlayerRemoving:Connect(function(player)
		self:_cleanupPlayer(player, false)
	end)
end

function HitLuckyBlockService:_getBrainrotAssetsFolder()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Brainrots")
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

	for _, brainrotFolder in ipairs(brainrotsFolder:GetChildren()) do
		if not brainrotFolder:IsA("Folder") then
			continue
		end

		for _, mutationOrModel in ipairs(brainrotFolder:GetChildren()) do
			if mutationOrModel:IsA("Model") or mutationOrModel:IsA("BasePart") then
				table.insert(candidates, {
					Brainrot = brainrotFolder.Name,
					Mutation = mutationOrModel.Name,
					Template = mutationOrModel,
				})
			elseif mutationOrModel:IsA("Folder") then
				local template = mutationOrModel:FindFirstChildWhichIsA("Model")
					or mutationOrModel:FindFirstChildWhichIsA("BasePart")

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
		warn("[HitLuckyBlockService] Missing ReplicatedStorage.Assets.Brainrots")
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

function HitLuckyBlockService:_findSafePart(): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local safe = map and map:FindFirstChild("Safe")

	if safe and safe:IsA("BasePart") then
		return safe
	end

	local found = Workspace:FindFirstChild("Safe", true)
	if found and found:IsA("BasePart") then
		return found
	end

	return nil
end

function HitLuckyBlockService:_bindSafezone()
	local safePart = self:_findSafePart()

	if not safePart then
		warn("[HitLuckyBlockService] Safezone not found. Expected workspace.Map.Safe or any BasePart named Safe.")
		return
	end

	self.SafePart = safePart

	self._safeTouchedConnection = safePart.Touched:Connect(function(hit)
		self:_safeTouched(hit)
	end)
end

function HitLuckyBlockService:_safeTouched(hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local state = self._states[player]
	if not state or state.Phase ~= "ReturningToSafezone" then
		return
	end

	self:_collectPlayer(player)
end

function HitLuckyBlockService:_chooseCandidate()
	if #self._candidates == 0 then
		return nil
	end

	return self._candidates[self._rng:NextInteger(1, #self._candidates)]
end

function HitLuckyBlockService:_buildRollCandidates(finalCandidate)
	local rollCandidates = {}

	for _ = 1, math.max(ROLL_COUNT - 1, 1) do
		local candidate = self:_chooseCandidate()

		if candidate then
			table.insert(rollCandidates, {
				Brainrot = candidate.Brainrot,
				Mutation = candidate.Mutation,
			})
		end
	end

	if finalCandidate then
		table.insert(rollCandidates, {
			Brainrot = finalCandidate.Brainrot,
			Mutation = finalCandidate.Mutation,
		})
	end

	return rollCandidates
end

function HitLuckyBlockService:_isOnCooldown(player: Player)
	local now = os.clock()
	local luckyBlockConfig = getLuckyBlockConfig(self.Config)
	local cooldown = luckyBlockConfig.HitCooldown or 0.35
	local nextAllowed = self._cooldowns[player] or 0

	if now < nextAllowed then
		return true, nextAllowed - now
	end

	self._cooldowns[player] = now + cooldown

	return false, 0
end

function HitLuckyBlockService:_setBusy(player: Player, busy: boolean)
	if busy then
		self._busyPlayers[player] = true
	else
		self._busyPlayers[player] = nil
	end
end

function HitLuckyBlockService:_findLandingArea(): BasePart?
	local mapCore = Workspace:FindFirstChild("MapCore")
	local landingArea = mapCore and mapCore:FindFirstChild("LandingArea")

	if landingArea and landingArea:IsA("BasePart") then
		return landingArea
	end

	local preferredNames = {
		"LandingArea",
		"LuckyBlockHitArea",
		"LuckyBlockArea",
		"HitArea",
		"HitField",
		"KickArea",
		"Runway",
	}

	for _, name in ipairs(preferredNames) do
		local found = Workspace:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then
			return found
		end
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant:GetAttribute("LandingArea") == true
				or descendant:GetAttribute("HitArea") == true
				or descendant:GetAttribute("LuckyBlockArea") == true
				or descendant:GetAttribute("KickArea") == true
			then
				return descendant
			end
		end
	end

	return nil
end

function HitLuckyBlockService:_getHitPower(data, economy): number
	return tonumber(data.HitPower)
		or tonumber(data.KickPower)
		or tonumber(economy.StartingKickPower)
		or 1
end

function HitLuckyBlockService:_computeFallbackFlight(root: BasePart, hitPower: number, barValue: number)
	local economy = getEconomy(self.Config)
	local kickConfig = economy.KickPower or {}

	local baseDistance = kickConfig.BaseDistance or 35
	local distancePerPower = kickConfig.DistancePerPower or 3.5
	local maxDistance = kickConfig.MaxDistance or 250

	local barMultiplier = 0.1 + (1.2 - 0.1) * barValue
	local distance = clamp((baseDistance + hitPower * distancePerPower) * barMultiplier, 10, maxDistance)

	local direction = flattenDirection(root.CFrame.LookVector)
	local startPosition = root.Position + direction * 5 + Vector3.new(0, 3, 0)
	local targetPosition = startPosition + direction * distance
	local arcHeight = clamp(distance * 0.35, 16, kickConfig.MaxArcHeight or 80)
	local controlPosition = (startPosition + targetPosition) / 2 + Vector3.new(0, arcHeight, 0)

	return {
		StartCFrame = CFrame.lookAt(startPosition, targetPosition),
		StartPosition = startPosition,
		TargetCFrame = CFrame.lookAt(targetPosition, targetPosition + direction),
		TargetPosition = targetPosition,
		ControlPosition = controlPosition,
		Distance = distance,
		Luck = barValue * 100,
		Normalized = barValue,
		BarMultiplier = barMultiplier,
	}
end

function HitLuckyBlockService:_computeFlight(root: BasePart, hitPower: number, barValue: number)
	local landingArea = self:_findLandingArea()

	if landingArea and self.KickCalculator and self.KickCalculator.Compute then
		local ok, result = pcall(function()
			return self.KickCalculator.Compute(hitPower, barValue, root, landingArea, self._rng)
		end)

		if ok and type(result) == "table" then
			if typeof(result.StartPosition) == "Vector3" and typeof(result.TargetPosition) == "Vector3" then
				result.ControlPosition = result.ControlPosition
					or ((result.StartPosition + result.TargetPosition) / 2 + Vector3.new(0, 30, 0))

				return result
			end
		else
			warn("[HitLuckyBlockService] KickCalculator.Compute failed:", result)
		end
	end

	return self:_computeFallbackFlight(root, hitPower, barValue)
end

function HitLuckyBlockService:_getRewards(data, hitPower: number)
	local economy = getEconomy(self.Config)

	local cashMultiplier = 1
	if self.EconomyMath and self.EconomyMath.GetCashMultiplier then
		cashMultiplier = self.EconomyMath.GetCashMultiplier(economy, data.Rebirths or 0)
	end

	local cashReward = 10
	if self.KickCalculator and self.KickCalculator.GetCashReward then
		cashReward = self.KickCalculator.GetCashReward(economy, hitPower, cashMultiplier)
	end

	local powerGain = 1
	if self.KickCalculator and self.KickCalculator.GetPowerGain then
		powerGain = self.KickCalculator.GetPowerGain(economy)
	end

	return cashReward, powerGain
end

function HitLuckyBlockService:_fireVisual(player: Player, methodName: string, payload)
	local controller = self.HitLuckyBlockVisualController

	if not controller or not controller.Server or not controller.Server.Fire then
		return
	end

	local ok, err = pcall(function()
		controller.Server.Fire[methodName](controller.Server.Fire, player, payload)
	end)

	if not ok then
		warn(("[HitLuckyBlockService] Failed visual event %s: %s"):format(methodName, tostring(err)))
	end
end

function HitLuckyBlockService:StartHitSequence(player: Player, barValue: number)
	barValue = tonumber(barValue) or 0

	if barValue > 1 then
		barValue = 0
	end

	barValue = clamp(barValue, 0, 1)

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

	local root = getCharacterRoot(player)
	if not root then
		return {
			Ok = false,
			Reason = "NoCharacter",
		}
	end

	local profile = self.DataService:GetProfile(player)
	if not profile then
		return {
			Ok = false,
			Reason = "DataNotLoaded",
		}
	end

	local finalCandidate = self:_chooseCandidate()
	if not finalCandidate then
		return {
			Ok = false,
			Reason = "NoBrainrotCandidates",
		}
	end

	self:_setBusy(player, true)

	local data = profile.Data
	local economy = getEconomy(self.Config)
	local hitPower = self:_getHitPower(data, economy)
	local flight = self:_computeFlight(root, hitPower, barValue)
	local cashReward, powerGain = self:_getRewards(data, hitPower)
	local flightId = HttpService:GenerateGUID(false)

	local flatDirection = flattenDirection(flight.TargetPosition - flight.StartPosition)
	local rollCandidates = self:_buildRollCandidates(finalCandidate)

	self._states[player] = {
		Phase = "Flying",
		FlightId = flightId,
		StartedAt = os.clock(),
		BarValue = barValue,
		Flight = flight,
		FlatDirection = flatDirection,
		FinalCandidate = finalCandidate,
		RollCandidates = rollCandidates,
		CashReward = cashReward,
		PowerGain = powerGain,
		HitPower = hitPower,
	}

	local luckyBlockConfig = getLuckyBlockConfig(self.Config)
	local flightConfig = luckyBlockConfig.Flight or {}

	self:_fireVisual(player, "BeginHitSequence", {
		FlightId = flightId,
		StartCFrame = flight.StartCFrame,
		StartPosition = flight.StartPosition,
		ControlPosition = flight.ControlPosition,
		TargetCFrame = flight.TargetCFrame,
		TargetPosition = flight.TargetPosition,
		FlatDirection = flatDirection,
		Duration = flightConfig.Duration or 0.85,
		SpinSpeed = flightConfig.SpinSpeed or 540,
		VisualLifetime = luckyBlockConfig.VisualLifetime or 5,
		BarValue = barValue,
	})

	task.delay(12, function()
		local state = self._states[player]
		if state and state.FlightId == flightId and state.Phase == "Flying" then
			self:_failSequence(player, "LandingTimeout")
		end
	end)

	return {
		Ok = true,
		FlightId = flightId,
		HitPower = hitPower,
		RewardPreview = cashReward,
		PowerGainPreview = powerGain,
	}
end

function HitLuckyBlockService:BlockLanded(player: Player, flightId: string, landingPosition: Vector3, flatDirection: Vector3)
	local state = self._states[player]

	if not state or state.Phase ~= "Flying" or state.FlightId ~= flightId then
		return
	end

	if typeof(landingPosition) ~= "Vector3" then
		return
	end

	if typeof(flatDirection) ~= "Vector3" then
		flatDirection = state.FlatDirection
	end

	local expectedPosition = state.Flight.TargetPosition
	if (landingPosition - expectedPosition).Magnitude > 45 then
		landingPosition = expectedPosition
	end

	flatDirection = flattenDirection(flatDirection)

	state.Phase = "Revealing"
	state.LandingPosition = landingPosition
	state.FlatDirection = flatDirection

	local finalCandidate = state.FinalCandidate

	self:_fireVisual(player, "BeginReveal", {
		FlightId = flightId,
		GroundPosition = landingPosition,
		FlatDirection = flatDirection,
		CandidateNames = state.RollCandidates,
		FinalBrainrot = finalCandidate.Brainrot,
		FinalMutation = finalCandidate.Mutation,
		RollCount = ROLL_COUNT,
		RollTime = 5,
		RollSpeed = 3,
	})

	task.delay(18, function()
		local currentState = self._states[player]
		if currentState and currentState.FlightId == flightId and currentState.Phase == "Revealing" then
			self:_failSequence(player, "RevealTimeout")
		end
	end)
end

function HitLuckyBlockService:RevealFinished(player: Player, flightId: string)
	local state = self._states[player]

	if not state or state.Phase ~= "Revealing" or state.FlightId ~= flightId then
		return
	end

	local candidate = state.FinalCandidate
	if not candidate or not candidate.Template then
		self:_failSequence(player, "MissingFinalCandidate")
		return
	end

	local ok = self:_morphPlayer(player, candidate.Template, -state.FlatDirection, state.LandingPosition)
	if not ok then
		self:_failSequence(player, "MorphFailed")
		return
	end

	state.Phase = "ReturningToSafezone"
	state.ReturnStartedAt = os.clock()

	self:_fireVisual(player, "BeginReturnRun", {
		FlightId = flightId,
		Brainrot = candidate.Brainrot,
		Mutation = candidate.Mutation,
		SafePosition = self.SafePart and self.SafePart.Position or nil,
	})

	task.delay(RETURN_TIMEOUT, function()
		local currentState = self._states[player]
		if currentState and currentState.FlightId == flightId and currentState.Phase == "ReturningToSafezone" then
			self:_failSequence(player, "ReturnTimeout")
		end
	end)
end

function HitLuckyBlockService:_morphPlayer(player: Player, rewardSource: Instance, facingDirection: Vector3, groundPosition: Vector3): boolean
	local character = getCharacter(player)
	local humanoid = getHumanoid(player)
	local root = getCharacterRoot(player)

	if not character or not humanoid or not root then
		return false
	end

	local oldMorph = character:FindFirstChild("BrainrotMorph")
	if oldMorph then
		oldMorph:Destroy()
	end

	local state = self._states[player]
	if state then
		state.OldWalkSpeed = humanoid.WalkSpeed
		state.OldJumpPower = humanoid.JumpPower
		state.OldJumpHeight = humanoid.JumpHeight
		state.OldAutoRotate = humanoid.AutoRotate
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= root then
			setTransparencyAttribute(descendant, "__HALB_PreMorphTransparency", descendant.Transparency)
			descendant.Transparency = 1
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			setTransparencyAttribute(descendant, "__HALB_PreMorphTransparency", descendant.Transparency)
			descendant.Transparency = 1
		end
	end

	local morphModel: Model

	if rewardSource:IsA("Model") then
		morphModel = rewardSource:Clone()
	elseif rewardSource:IsA("BasePart") then
		morphModel = Instance.new("Model")
		local part = rewardSource:Clone()
		part.Parent = morphModel
		morphModel.PrimaryPart = part
	else
		return false
	end

	morphModel.Name = "BrainrotMorph"
	morphModel.Parent = character

	for _, descendant in ipairs(morphModel:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("Humanoid") then
			descendant:Destroy()
		end
	end

	local fd = flattenDirection(facingDirection)
	local rootTargetPosition = Vector3.new(
		groundPosition.X,
		groundPosition.Y + humanoid.HipHeight + root.Size.Y / 2,
		groundPosition.Z
	)

	root.CFrame = CFrame.lookAt(rootTargetPosition, rootTargetPosition + fd)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = false

	local ok, boxCFrame, boxSize = pcall(function()
		return morphModel:GetBoundingBox()
	end)

	if not ok then
		morphModel:Destroy()
		return false
	end

	local centerPosition = Vector3.new(groundPosition.X, groundPosition.Y + boxSize.Y / 2, groundPosition.Z)
	local targetCFrame = CFrame.lookAt(centerPosition, centerPosition + fd)
	local pivotToBox = morphModel:GetPivot():ToObjectSpace(boxCFrame)

	morphModel:PivotTo(targetCFrame * pivotToBox:Inverse())

	for _, part in ipairs(morphModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end

	humanoid.AutoRotate = true
	humanoid.WalkSpeed = MORPH_WALK_SPEED

	if humanoid.UseJumpPower then
		humanoid.JumpPower = MORPH_JUMP_POWER
	else
		humanoid.JumpHeight = 7.2
	end

	return true
end

function HitLuckyBlockService:_unmorphPlayer(player: Player)
	local character = getCharacter(player)
	local humanoid = getHumanoid(player)

	if not character then
		return
	end

	local morph = character:FindFirstChild("BrainrotMorph")
	if morph then
		morph:Destroy()
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			restoreTransparencyAttribute(descendant, "__HALB_PreMorphTransparency")
		end
	end

	local state = self._states[player]
	if humanoid and state then
		if typeof(state.OldWalkSpeed) == "number" then
			humanoid.WalkSpeed = state.OldWalkSpeed
		end

		if typeof(state.OldJumpPower) == "number" then
			humanoid.JumpPower = state.OldJumpPower
		end

		if typeof(state.OldJumpHeight) == "number" then
			humanoid.JumpHeight = state.OldJumpHeight
		end

		if typeof(state.OldAutoRotate) == "boolean" then
			humanoid.AutoRotate = state.OldAutoRotate
		end
	end
end

function HitLuckyBlockService:_collectPlayer(player: Player)
	local state = self._states[player]
	if not state or state.Phase ~= "ReturningToSafezone" then
		return
	end

	local candidate = state.FinalCandidate
	if not candidate then
		self:_failSequence(player, "MissingReward")
		return
	end

	local collectedAt = os.time()
	local rewardId = ("%s_%s_%s"):format(candidate.Brainrot, candidate.Mutation, HttpService:GenerateGUID(false))

	local ok, result = self.DataService:Mutate(player, function(data)
		data.Cash = math.max(0, (data.Cash or 0) + (state.CashReward or 0))

		local newHitPower = math.max(0, (data.HitPower or data.KickPower or 0) + (state.PowerGain or 0))
		data.HitPower = newHitPower
		data.KickPower = newHitPower

		data.Inventory = data.Inventory or {}
		data.Inventory.Brainrots = data.Inventory.Brainrots or {}

		table.insert(data.Inventory.Brainrots, {
			Id = rewardId,
			Brainrot = candidate.Brainrot,
			Mutation = candidate.Mutation,
			Level = 1,
			CollectedAt = collectedAt,
		})

		data.BrainrotIndex = data.BrainrotIndex or {}
		data.BrainrotIndex[("%s_%s"):format(candidate.Brainrot, candidate.Mutation)] = true

		return {
			Cash = data.Cash,
			HitPower = newHitPower,
			RewardId = rewardId,
		}
	end)

	if not ok then
		warn("[HitLuckyBlockService] Failed to collect reward:", result)
		self:_failSequence(player, "DataMutationFailed")
		return
	end

	self:_unmorphPlayer(player)

	self:_fireVisual(player, "SequenceComplete", {
		FlightId = state.FlightId,
		Brainrot = candidate.Brainrot,
		Mutation = candidate.Mutation,
		CashReward = state.CashReward,
		PowerGain = state.PowerGain,
		RewardId = rewardId,
	})

	self._states[player] = nil
	self:_setBusy(player, false)
end

function HitLuckyBlockService:_failSequence(player: Player, reason: string)
	local state = self._states[player]

	self:_unmorphPlayer(player)

	if state then
		self:_fireVisual(player, "SequenceFailed", {
			FlightId = state.FlightId,
			Reason = reason,
		})
	end

	self._states[player] = nil
	self:_setBusy(player, false)

	warn(("[HitLuckyBlockService] Sequence failed for %s: %s"):format(player.Name, reason))
end

function HitLuckyBlockService:_cleanupPlayer(player: Player, fireClient: boolean)
	local state = self._states[player]

	self:_unmorphPlayer(player)

	if fireClient and state then
		self:_fireVisual(player, "SequenceFailed", {
			FlightId = state.FlightId,
			Reason = "Cleanup",
		})
	end

	self._states[player] = nil
	self._cooldowns[player] = nil
	self:_setBusy(player, false)
end

function HitLuckyBlockService.Client.Hit(service, player: Player, barValue: number)
	return service:StartHitSequence(player, barValue)
end

return HitLuckyBlockService