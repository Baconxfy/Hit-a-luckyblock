--!strict
-- HitMinigameServer
-- Ported from reference game. Adapted paths for this game's asset structure.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")

local HitEvent = ReplicatedStorage:WaitForChild("HitEvent")
local CarryEvent = ReplicatedStorage:FindFirstChild("LuckyBlockCarryEvent")
local CutsceneEvent = ReplicatedStorage:WaitForChild("CutsceneEvent")
local VFXEvent = ReplicatedStorage:WaitForChild("VFXEvent")

-- GroundSmashVFX lives under Server.Utils in this game
local GroundSmashVFX = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Utils"):WaitForChild("GroundSmashVFX"))
local TsunamiWaveVFX = require(ServerScriptService:WaitForChild("Minigame"):WaitForChild("TsunamiWaveVFX"))

-- Assets are stored in ReplicatedStorage.Assets.HitLuckyBlock in this game
local HitLuckyBlockAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HitLuckyBlock")
local LuckyBlockTemplate = HitLuckyBlockAssets:WaitForChild("LuckyBlock")
local BaseballTemplate = HitLuckyBlockAssets:WaitForChild("Baseball")
local HeldBlockTemplate = workspace:FindFirstChild("LuckyBlock2") -- optional prop in workspace
local OpeningVFXTemplate = HitLuckyBlockAssets:FindFirstChild("OpeningVFX")
local FinalRevealVFXTemplate = HitLuckyBlockAssets:FindFirstChild("OBVFX")
local WaveSpawnPart = workspace:FindFirstChild("WaveCommon")
local WaveReachPart = workspace:FindFirstChild("ReachPoint")

local HIT_ANIM_ID = "rbxassetid://109049329968119"
local CARRY_ANIM_ID = "rbxassetid://130233565570548"
local HOLD_ANIM_ID = "rbxassetid://128745131098374"
local CARRY_BLOCK_OFFSET = CFrame.new(1.08, -0.27, -0.02)
local IMPACT_HOLD_TIME = 0
local HIT_MARKER_NAMES = { "hit", "Hit" }
local BLOCK_GROUND_OFFSET = LuckyBlockTemplate:WaitForChild("Root").Size.Y / 2
local LAUNCH_SETTINGS = {
	MinDistance = 10,
	MaxDistance = 100000,
	LandingAreaName = "LandingArea",
	RarityZoneNames = { "Common", "Rare", "Epic", "Legendary", "Mythic" },
	LandingAreaEdgePadding = 2,
	UseLandingAreaEntryDistance = true,
}

local TSUNAMI_WAVE_SETTINGS = {
	Enabled = true,
	WaveName = "TsunamiWave_01",
	WorkspaceWaveName = "TsunamiWave_01",
	SpawnPartName = "WaveCommon",
	ReachPointName = "ReachPoint",
	SpawnBehindDistance = 18,
	UndergroundDepth = nil,
	RiseDuration = 1.8,
	MoveSpeed = 16,
	Lifetime = 120,
	FocusAfterSpawnDelay = 0.1,
	ReleaseAfterRiseDelay = 1,
	MoveAfterReleaseDelay = 0.25,
	DamageEnabled = true,
	DamageAmount = 1000000,
	KnockbackAmount = 0,
}

local MORPH_SETTINGS = {
	WalkSpeed = 24,
	JumpPower = 50,
}

local function GetInstancePivot(instance)
	if not instance then return nil end
	if instance:IsA("BasePart") then return instance.CFrame end
	if instance:IsA("Model") then return instance:GetPivot() end
	return nil
end

local function HideWorkspaceTsunamiTemplate()
	local template = workspace:FindFirstChild(TSUNAMI_WAVE_SETTINGS.WorkspaceWaveName)
	if not template then return end
	local placedCFrame = template:GetAttribute("PlacedCFrame")
	if typeof(placedCFrame) ~= "CFrame" then
		placedCFrame = GetInstancePivot(template)
		if not placedCFrame then return end
		template:SetAttribute("PlacedCFrame", placedCFrame)
	end
	local boxCFrame, boxSize
	if template:IsA("BasePart") then
		boxCFrame = template.CFrame
		boxSize = template.Size
	elseif template:IsA("Model") then
		boxCFrame, boxSize = template:GetBoundingBox()
	else return end
	template:SetAttribute("PlacedFocusPosition", boxCFrame.Position)
	local hiddenOffset = Vector3.new(0, -(boxSize.Y + 8), 0)
	if template:IsA("BasePart") then
		template.CFrame = placedCFrame + hiddenOffset
	else
		template:PivotTo(placedCFrame + hiddenOffset)
	end
end

HideWorkspaceTsunamiTemplate()

local REWARD_REVEAL_SETTINGS = {
	WorkspaceNamePattern = "^B%d+$",
	CandidateSourceFolders = { "Brainrots", "BrainrotRewards", "RewardBrainrots" },
	RollCount = 30,
	RollTime = 5,
	RandomBrainrotSpeed = 3,
	FinalHoldTime = 1.5,
	FocusMoveTime = 0.6,
	OpeningFocusMoveTime = 0.35,
	OpeningVFXFadeTime = 1,
	OpeningVFXHoldAfterFinal = 2,
	PopHeight = 0.5,
	RewardLift = 0.1,
	SilhouetteColor = Color3.fromRGB(0, 0, 0),
	SilhouetteTransparency = 0,
	PopScaleStart = 0.5,
	PopScalePeak = 1.3,
	PopScaleEnd = 0.7,
	FinalPopScalePeak = 1.18,
	SpinRadiansPerSecond = math.rad(180),
}

local playerStates = {}
local busyPlayers = {}

local CarryAnimationObj = Instance.new("Animation")
CarryAnimationObj.AnimationId = CARRY_ANIM_ID
local HoldAnimationObj = Instance.new("Animation")
HoldAnimationObj.AnimationId = HOLD_ANIM_ID
task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({ CarryAnimationObj, HoldAnimationObj })
	end)
end)

local function Transparen(obj, val)
	for _, v in pairs(obj:GetDescendants()) do
		if (v:IsA("BasePart") or v:IsA("MeshPart")) and v.Name ~= "Root" then
			v.Transparency = val
		end
	end
end

local function SetAllPartTransparency(obj, val)
	for _, v in ipairs(obj:GetDescendants()) do
		if v:IsA("BasePart") then v.Transparency = val end
	end
end

local function ShowBatVisuals(bat)
	for _, v in ipairs(bat:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Transparency = if v.Name == "Handle" then 1 else 0
		end
	end
end

local function StopTrack(track, fadeTime)
	if not track then return end
	pcall(function()
		track:Stop(fadeTime or 0)
		track:Destroy()
	end)
end

local function FreezeCharacterMotion(player, state)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not char or not humanoid or not root then return end
	state.motionBeforeHold = state.motionBeforeHold or {
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate,
	}
	humanoid:Move(Vector3.zero, false)
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	if humanoid.UseJumpPower then
		humanoid.JumpPower = 0
	else
		humanoid.JumpHeight = 0
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0.05)
		end
	end
end

local function RestoreCharacterMotion(player, walkSpeedOverride)
	local state = playerStates[player]
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not humanoid then return end
	local previous = state and state.motionBeforeHold
	humanoid.WalkSpeed = walkSpeedOverride or (previous and previous.WalkSpeed) or 16
	humanoid.AutoRotate = if previous and previous.AutoRotate ~= nil then previous.AutoRotate else true
	if humanoid.UseJumpPower then
		humanoid.JumpPower = (previous and previous.JumpPower) or 50
	else
		humanoid.JumpHeight = (previous and previous.JumpHeight) or 7.2
	end
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = false
	end
	if state then state.motionBeforeHold = nil end
end

local function GetLandingAreaParts()
	local parts = {}
	for _, instance in ipairs(workspace:GetDescendants()) do
		if instance:IsA("BasePart") and instance.Name == LAUNCH_SETTINGS.LandingAreaName then
			table.insert(parts, instance)
		end
	end
	return parts
end

local function IsRarityZoneName(name)
	local lowerName = string.lower(name)
	for _, zoneName in ipairs(LAUNCH_SETTINGS.RarityZoneNames) do
		if lowerName == string.lower(zoneName) then return true end
	end
	return false
end

local function GetRarityZoneParts()
	local parts = {}
	for _, instance in ipairs(workspace:GetDescendants()) do
		if instance:IsA("BasePart") and IsRarityZoneName(instance.Name) then
			table.insert(parts, instance)
		end
	end
	return parts
end

local function IsPointInsidePartXZ(part, worldPosition)
	local localPosition = part.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = part.Size * 0.5
	return localPosition.X >= -halfSize.X and localPosition.X <= halfSize.X
		and localPosition.Z >= -halfSize.Z and localPosition.Z <= halfSize.Z
end

local ClampPointToPartTop

local function GetVisualGroundPartAt(worldPosition)
	local closestPart = nil
	local closestDistance = math.huge
	for _, part in ipairs(GetRarityZoneParts()) do
		if IsPointInsidePartXZ(part, worldPosition) then return part end
		local point = ClampPointToPartTop(part, worldPosition)
		local flatDelta = Vector3.new(point.X - worldPosition.X, 0, point.Z - worldPosition.Z)
		if flatDelta.Magnitude < closestDistance then
			closestDistance = flatDelta.Magnitude
			closestPart = part
		end
	end
	return closestPart
end

function ClampPointToPartTop(part, worldPosition)
	local localPosition = part.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = part.Size * 0.5
	local padding = LAUNCH_SETTINGS.LandingAreaEdgePadding or 2
	local clampedLocal = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X + padding, halfSize.X - padding),
		halfSize.Y,
		math.clamp(localPosition.Z, -halfSize.Z + padding, halfSize.Z - padding)
	)
	return part.CFrame:PointToWorldSpace(clampedLocal)
end

local function GetClosestLandingAreaPoint(horizontalTarget)
	local closestPart, closestPoint, closestDistance = nil, nil, math.huge
	for _, part in ipairs(GetLandingAreaParts()) do
		local point = ClampPointToPartTop(part, horizontalTarget)
		local flatDelta = Vector3.new(point.X - horizontalTarget.X, 0, point.Z - horizontalTarget.Z)
		if flatDelta.Magnitude < closestDistance then
			closestDistance = flatDelta.Magnitude
			closestPart = part
			closestPoint = point
		end
	end
	return closestPart, closestPoint
end

local function GetGroundLandingPosition(horizontalTarget, fallbackY, ignoreInstances)
	local landingPart, landingPoint = GetClosestLandingAreaPoint(horizontalTarget)
	if landingPart and landingPoint then
		return landingPoint + Vector3.new(0, BLOCK_GROUND_OFFSET, 0), landingPart
	end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = ignoreInstances or {}
	local rayOrigin = Vector3.new(horizontalTarget.X, fallbackY + 500, horizontalTarget.Z)
	local result = workspace:Raycast(rayOrigin, Vector3.new(0, -1000, 0), raycastParams)
	if result then
		return Vector3.new(horizontalTarget.X, result.Position.Y + BLOCK_GROUND_OFFSET, horizontalTarget.Z), result.Instance
	end
	return Vector3.new(horizontalTarget.X, fallbackY, horizontalTarget.Z), nil
end

local function GetRayRectEntryExit(localOrigin, localDirection, halfSize, padding)
	local tMin = -math.huge
	local tMax = math.huge
	local function includeAxis(origin, direction, minBound, maxBound)
		if math.abs(direction) < 0.0001 then
			return origin >= minBound and origin <= maxBound
		end
		local t1 = (minBound - origin) / direction
		local t2 = (maxBound - origin) / direction
		if t1 > t2 then t1, t2 = t2, t1 end
		tMin = math.max(tMin, t1)
		tMax = math.min(tMax, t2)
		return tMin <= tMax
	end
	local minX, maxX = -halfSize.X + padding, halfSize.X - padding
	local minZ, maxZ = -halfSize.Z + padding, halfSize.Z - padding
	if minX > maxX or minZ > maxZ then return nil, nil end
	if not includeAxis(localOrigin.X, localDirection.X, minX, maxX) then return nil, nil end
	if not includeAxis(localOrigin.Z, localDirection.Z, minZ, maxZ) then return nil, nil end
	if tMax < 0 then return nil, nil end
	return math.max(tMin, 0), tMax
end

local function GetLandingAreaDistanceTarget(origin, flatDirection, distance)
	if not LAUNCH_SETTINGS.UseLandingAreaEntryDistance then return nil end
	if flatDirection.Magnitude < 0.05 then return nil end
	local bestEntry, bestTarget = math.huge, nil
	local padding = LAUNCH_SETTINGS.LandingAreaEdgePadding or 2
	for _, part in ipairs(GetLandingAreaParts()) do
		local localOrigin = part.CFrame:PointToObjectSpace(origin)
		local localDirection = part.CFrame:VectorToObjectSpace(flatDirection.Unit)
		local entryT, exitT = GetRayRectEntryExit(localOrigin, localDirection, part.Size * 0.5, padding)
		if entryT and exitT and entryT < bestEntry then
			local targetT = math.clamp(entryT + distance, entryT + padding, math.max(entryT + padding, exitT - padding))
			bestEntry = entryT
			bestTarget = origin + flatDirection.Unit * targetT
		end
	end
	return bestTarget
end

local function GetRewardFocusPart(target)
	if not target then return nil end
	if target:IsA("BasePart") then return target end
	if not target:IsA("Model") then return nil end
	return target:FindFirstChild("Root") or target:FindFirstChild("RootPart")
		or target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
end

local function HasRewardParts(instance)
	return instance and (instance:IsA("BasePart") or instance:FindFirstChildWhichIsA("BasePart", true) ~= nil)
end

local function AddRewardCandidate(candidates, instance, brainrotName, mutationName, brainrotWeight, mutationWeight)
	if not HasRewardParts(instance) then return end
	table.insert(candidates, {
		instance = instance,
		brainrot = brainrotName or instance.Name,
		mutation = mutationName or "Default",
		brainrotWeight = brainrotWeight or 1,
		mutationWeight = mutationWeight or 1,
	})
end

local function CollectRewardCandidates()
	local candidates = {}
	-- This game stores brainrots under RS.Assets.Brainrots
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local brainrotsFolder = assetsFolder and assetsFolder:FindFirstChild("Brainrots")
	if brainrotsFolder then
		for _, brainrot in ipairs(brainrotsFolder:GetChildren()) do
			local addedMutation = false
			for _, mutation in ipairs(brainrot:GetChildren()) do
				if HasRewardParts(mutation) then
					AddRewardCandidate(candidates, mutation, brainrot.Name, mutation.Name)
					addedMutation = true
				end
			end
			if not addedMutation then
				AddRewardCandidate(candidates, brainrot, brainrot.Name, "Default")
			end
		end
	end
	for _, folderName in ipairs(REWARD_REVEAL_SETTINGS.CandidateSourceFolders) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, reward in ipairs(folder:GetChildren()) do
				AddRewardCandidate(candidates, reward, reward.Name, "Default")
			end
		end
	end
	if #candidates == 0 then
		for _, reward in ipairs(workspace:GetChildren()) do
			if reward:IsA("Model") and reward.Name:match(REWARD_REVEAL_SETTINGS.WorkspaceNamePattern) then
				AddRewardCandidate(candidates, reward, reward.Name, "Default")
			end
		end
	end
	return candidates
end

local function RollReward(candidates)
	local rarityModule = ServerScriptService:FindFirstChild("RaritySystem")
	if rarityModule then
		local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
		if assetsFolder and assetsFolder:FindFirstChild("Brainrots") then
			local ok, result = pcall(function() return require(rarityModule).Roll() end)
			if ok and result and HasRewardParts(result.instance) then return result end
		end
	end
	if #candidates == 0 then return nil end
	local pick = candidates[math.random(1, #candidates)]
	return { brainrot = pick.brainrot, mutation = pick.mutation, instance = pick.instance,
		brainrotWeight = pick.brainrotWeight, mutationWeight = pick.mutationWeight }
end

local function PrepareRewardClone(template)
	local clone = template:Clone()
	clone.Name = "Reward_" .. template.Name
	clone.Parent = workspace
	if clone:IsA("BasePart") then
		clone:SetAttribute("RewardOriginalSize", clone.Size)
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanTouch = false
		clone.CanQuery = false
		return clone
	end
	clone:SetAttribute("RewardBaseScale", clone:GetScale())
	local focusPart = GetRewardFocusPart(clone)
	if focusPart and clone:IsA("Model") then clone.PrimaryPart = focusPart end
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	return clone
end

local function SetRewardScale(reward, scaleMultiplier)
	if not reward or not reward.Parent then return end
	if reward:IsA("BasePart") then
		local originalSize = reward:GetAttribute("RewardOriginalSize") or reward.Size
		reward.Size = originalSize * scaleMultiplier
		return
	end
	local baseScale = reward:GetAttribute("RewardBaseScale") or reward:GetScale()
	reward:ScaleTo(baseScale * scaleMultiplier)
end

local function ApplyRewardSilhouette(reward, isSilhouette)
	if not reward or not reward.Parent then return end
	reward:SetAttribute("RewardSilhouette", isSilhouette)
	if not isSilhouette then return end
	for _, descendant in ipairs(reward:GetDescendants()) do
		if descendant:IsA("SurfaceAppearance") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant:Destroy()
		elseif descendant:IsA("SpecialMesh") then
			descendant.TextureId = ""
		elseif descendant:IsA("BasePart") and descendant.Transparency < 1 then
			descendant.Color = REWARD_REVEAL_SETTINGS.SilhouetteColor
			descendant.Material = Enum.Material.SmoothPlastic
			descendant.Reflectance = 0
			descendant.Transparency = REWARD_REVEAL_SETTINGS.SilhouetteTransparency
			if descendant:IsA("MeshPart") then descendant.TextureID = "" end
		end
	end
end

local function GetPopScale(alpha, isFinal)
	local startScale = REWARD_REVEAL_SETTINGS.PopScaleStart
	local peakScale = if isFinal then REWARD_REVEAL_SETTINGS.FinalPopScalePeak else REWARD_REVEAL_SETTINGS.PopScalePeak
	local endScale = if isFinal then 1 else REWARD_REVEAL_SETTINGS.PopScaleEnd
	local easedAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if alpha < 0.55 then
		return startScale + (peakScale - startScale) * TweenService:GetValue(alpha / 0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end
	local settleAlpha = (alpha - 0.55) / 0.45
	return peakScale + (endScale - peakScale) * easedAlpha * settleAlpha
end

local function ApplyRewardTransform(reward, targetCFrame)
	if reward:IsA("BasePart") then
		reward.CFrame = targetCFrame
		return
	end
	local currentCFrame = reward:GetBoundingBox()
	local delta = targetCFrame * currentCFrame:Inverse()
	for _, part in ipairs(reward:GetDescendants()) do
		if part:IsA("BasePart") then part.CFrame = delta * part.CFrame end
	end
end

local function ForceRewardAboveGround(reward, groundPosition, facingDirection, yaw, lift)
	if not reward or not reward.Parent then return end
	local floorY = groundPosition.Y + (lift or 0)
	facingDirection = facingDirection or Vector3.new(0, 0, -1)
	local cameraDirection = -facingDirection
	if cameraDirection.Magnitude < 0.05 then
		cameraDirection = Vector3.new(0, 0, -1)
	else
		cameraDirection = cameraDirection.Unit
	end
	if reward:IsA("BasePart") then
		local centerPosition = Vector3.new(groundPosition.X, floorY + reward.Size.Y / 2, groundPosition.Z)
		reward.CFrame = CFrame.lookAt(centerPosition, centerPosition + cameraDirection)
		return
	end
	local boxCFrame, boxSize = reward:GetBoundingBox()
	local centerPosition = Vector3.new(groundPosition.X, floorY + boxSize.Y / 2, groundPosition.Z)
	local targetCFrame = CFrame.lookAt(centerPosition, centerPosition + cameraDirection)
	local delta = targetCFrame * boxCFrame:Inverse()
	for _, part in ipairs(reward:GetDescendants()) do
		if part:IsA("BasePart") then part.CFrame = delta * part.CFrame end
	end
end

local function PlaceRewardOnGround(reward, groundPosition, facingDirection, yaw, lift)
	ForceRewardAboveGround(reward, groundPosition, facingDirection, yaw, lift)
end

local function MorphPlayerAsReward(player, rewardSource, facingDirection)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root or not rewardSource then return end
	local oldMorph = character:FindFirstChild("BrainrotMorph")
	if oldMorph then oldMorph:Destroy() end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= root then
			descendant.Transparency = 1
			for _, child in ipairs(descendant:GetChildren()) do
				if child:IsA("Decal") or child:IsA("Texture") then child.Transparency = 1 end
			end
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		end
	end
	local morph = rewardSource:Clone()
	morph.Name = "BrainrotMorph"
	morph.Parent = character
	for _, descendant in ipairs(morph:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("Humanoid") then
			descendant:Destroy()
		end
	end
	facingDirection = Vector3.new(facingDirection.X, 0, facingDirection.Z)
	if facingDirection.Magnitude < 0.05 then
		facingDirection = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	if facingDirection.Magnitude < 0.05 then
		facingDirection = Vector3.new(0, 0, -1)
	else
		facingDirection = facingDirection.Unit
	end
	local sourceCFrame, sourceSize
	if rewardSource:IsA("BasePart") then
		sourceCFrame = rewardSource.CFrame
		sourceSize = rewardSource.Size
	else
		sourceCFrame, sourceSize = rewardSource:GetBoundingBox()
	end
	local sourceFloorY = sourceCFrame.Position.Y - sourceSize.Y / 2
	local rootPosition = Vector3.new(sourceCFrame.Position.X, sourceFloorY + humanoid.HipHeight + root.Size.Y / 2, sourceCFrame.Position.Z)
	root.CFrame = CFrame.lookAt(rootPosition, rootPosition + facingDirection)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local _, boxSize
	if morph:IsA("BasePart") then
		boxSize = morph.Size
	else
		_, boxSize = morph:GetBoundingBox()
	end
	local floorY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	local centerPosition = Vector3.new(root.Position.X, floorY + boxSize.Y / 2, root.Position.Z)
	ApplyRewardTransform(morph, CFrame.lookAt(centerPosition, centerPosition + facingDirection))
	local function preparePart(part)
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
	if morph:IsA("BasePart") then
		preparePart(morph)
	else
		for _, descendant in ipairs(morph:GetDescendants()) do
			if descendant:IsA("BasePart") then preparePart(descendant) end
		end
	end
	root.Anchored = false
	humanoid.AutoRotate = true
	humanoid.WalkSpeed = MORPH_SETTINGS.WalkSpeed
	humanoid.JumpPower = MORPH_SETTINGS.JumpPower
	return morph
end

local function EmitAttachmentVFX(vfxRoot)
	for _, emitter in ipairs(vfxRoot:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then
			local emitCount = emitter:GetAttribute("EmitCount") or emitter:GetAttribute("emitCount") or 1
			emitter:Emit(emitCount)
		end
	end
end

local function PlayOpeningVFX(block)
	local rootPart = block and block:FindFirstChild("Root")
	if not OpeningVFXTemplate or not rootPart then return nil end
	local holder = Instance.new("Part")
	holder.Name = "OpeningVFXHolder"
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CFrame = rootPart.CFrame
	holder.Parent = workspace
	local vfx = OpeningVFXTemplate:Clone()
	vfx.Name = "OpeningVFXActive"
	vfx.Parent = holder
	if vfx:IsA("Attachment") then vfx.Position = Vector3.new(0, 0, 0) end
	for _, emitter in ipairs(vfx:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then emitter.Enabled = true end
	end
	EmitAttachmentVFX(vfx)
	return holder
end

local function StopOpeningVFX(vfxHolder)
	if not vfxHolder or not vfxHolder.Parent then return end
	for _, emitter in ipairs(vfxHolder:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then emitter.Enabled = false end
	end
	Debris:AddItem(vfxHolder, REWARD_REVEAL_SETTINGS.OpeningVFXFadeTime)
end

local function GetVFXPosition(target)
	if not target then return nil end
	if target:IsA("BasePart") then return target.Position end
	if target:IsA("Model") then return target:GetBoundingBox().Position end
	return nil
end

local function PlayFinalRevealVFX(target)
	local position = GetVFXPosition(target)
	if not FinalRevealVFXTemplate or not position then return end
	local holder = Instance.new("Part")
	holder.Name = "OBVFXHolder"
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace
	local vfx = FinalRevealVFXTemplate:Clone()
	vfx.Name = "OBVFXActive"
	vfx.Parent = holder
	if vfx:IsA("Attachment") then vfx.Position = Vector3.new(0, 0, 0) end
	EmitAttachmentVFX(vfx)
	Debris:AddItem(holder, 3)
end

local function HideLuckyBlockVisuals(block)
	if not block then return end
	for _, part in ipairs(block:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "Root" then part.Transparency = 1 end
	end
end

local function PlayRewardReveal(player, block, targetPos, flatDirection)
	workspace:SetAttribute("RewardRevealError", nil)
	local candidates = CollectRewardCandidates()
	local finalReward = RollReward(candidates)
	if not finalReward then
		warn("[HitMinigameServer] No brainrot reward candidates found.")
		CutsceneEvent:FireClient(player, "End", block)
		RestoreCharacterMotion(player)
		return
	end
	if #candidates == 0 then
		AddRewardCandidate(candidates, finalReward.instance, finalReward.brainrot, finalReward.mutation, finalReward.brainrotWeight, finalReward.mutationWeight)
	end
	local groundPosition = Vector3.new(targetPos.X, targetPos.Y - BLOCK_GROUND_OFFSET, targetPos.Z)
	CutsceneEvent:FireClient(player, "FocusReward", block)
	task.wait(REWARD_REVEAL_SETTINGS.FocusMoveTime)
	CutsceneEvent:FireClient(player, "FocusOpening", block)
	task.wait(REWARD_REVEAL_SETTINGS.OpeningFocusMoveTime)
	local openingVFX = PlayOpeningVFX(block)
	local openTween = block and block:FindFirstChild("Root") and TweenService:Create(
		block.Root,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ CFrame = block.Root.CFrame * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, math.rad(18), 0) }
	)
	if openTween then
		openTween:Play()
		openTween.Completed:Wait()
	else
		task.wait(0.25)
	end
	HideLuckyBlockVisuals(block)
	local activeClone = nil
	local rollCount = math.max(REWARD_REVEAL_SETTINGS.RollCount, 2)
	for index = 1, rollCount do
		if activeClone then activeClone:Destroy(); activeClone = nil end
		local isFinalStep = index == rollCount
		local candidate = if isFinalStep then finalReward else candidates[math.random(1, #candidates)]
		activeClone = PrepareRewardClone(candidate.instance)
		ApplyRewardSilhouette(activeClone, not isFinalStep)
		local alpha = index / rollCount
		local baseStepDuration = REWARD_REVEAL_SETTINGS.RollTime / math.max(rollCount - 1, 1)
		local speed = math.max(REWARD_REVEAL_SETTINGS.RandomBrainrotSpeed, 0.01)
		local stepDuration = if isFinalStep then 1 else math.clamp((baseStepDuration * (0.6 + alpha * 0.8)) / speed, 0.04, 0.55)
		local stepStart = os.clock()
		while activeClone and activeClone.Parent and os.clock() - stepStart < stepDuration do
			local localAlpha = math.clamp((os.clock() - stepStart) / stepDuration, 0, 1)
			local popScale = GetPopScale(localAlpha, isFinalStep)
			local popLift = REWARD_REVEAL_SETTINGS.RewardLift + math.sin(localAlpha * math.pi) * REWARD_REVEAL_SETTINGS.PopHeight
			local yaw = os.clock() * REWARD_REVEAL_SETTINGS.SpinRadiansPerSecond
			SetRewardScale(activeClone, popScale)
			PlaceRewardOnGround(activeClone, groundPosition, flatDirection, yaw, popLift)
			RunService.Heartbeat:Wait()
		end
	end
	if activeClone and activeClone.Parent then
		SetRewardScale(activeClone, 1)
		ApplyRewardSilhouette(activeClone, false)
		PlaceRewardOnGround(activeClone, groundPosition, flatDirection, 0, REWARD_REVEAL_SETTINGS.RewardLift)
		StopOpeningVFX(openingVFX)
		PlayFinalRevealVFX(activeClone)
		if TSUNAMI_WAVE_SETTINGS.Enabled then
			local waveTemplate = workspace:FindFirstChild(TSUNAMI_WAVE_SETTINGS.WorkspaceWaveName)
			local hasPlacedWorkspaceWave = waveTemplate ~= nil
			local placedWaveCFrame = waveTemplate and waveTemplate:GetAttribute("PlacedCFrame")
			if typeof(placedWaveCFrame) ~= "CFrame" then
				placedWaveCFrame = GetInstancePivot(waveTemplate)
			end
			local spawnPart = workspace:FindFirstChild(TSUNAMI_WAVE_SETTINGS.SpawnPartName) or WaveSpawnPart
			local reachPart = workspace:FindFirstChild(TSUNAMI_WAVE_SETTINGS.ReachPointName) or WaveReachPart
			local mapFolder = workspace:FindFirstChild("Map")
			local safePart = mapFolder and mapFolder:FindFirstChild("Safe")
			local fallbackSpawnPosition = if spawnPart and spawnPart:IsA("BasePart") then spawnPart.Position else groundPosition + flatDirection * TSUNAMI_WAVE_SETTINGS.SpawnBehindDistance
			local routeDirection = Vector3.new(1, 0, 0)
			local targetPosition = nil
			if reachPart and reachPart:IsA("BasePart") then
				local toReach = Vector3.new(reachPart.Position.X - fallbackSpawnPosition.X, 0, reachPart.Position.Z - fallbackSpawnPosition.Z)
				if math.abs(toReach.X) >= math.abs(toReach.Z) and math.abs(toReach.X) > 0.05 then
					routeDirection = Vector3.new(math.sign(toReach.X), 0, 0)
					targetPosition = Vector3.new(reachPart.Position.X, fallbackSpawnPosition.Y, fallbackSpawnPosition.Z)
				elseif math.abs(toReach.Z) > 0.05 then
					routeDirection = Vector3.new(0, 0, math.sign(toReach.Z))
					targetPosition = Vector3.new(fallbackSpawnPosition.X, fallbackSpawnPosition.Y, reachPart.Position.Z)
				end
			end
			local fallbackSpawnCFrame = CFrame.lookAt(fallbackSpawnPosition, fallbackSpawnPosition + routeDirection)
			local waveSpawnCFrame = placedWaveCFrame or fallbackSpawnCFrame
			local waveMoveDirection = routeDirection
			if placedWaveCFrame and targetPosition then
				if math.abs(routeDirection.X) > 0 then
					targetPosition = Vector3.new(targetPosition.X, placedWaveCFrame.Position.Y, placedWaveCFrame.Position.Z)
				else
					targetPosition = Vector3.new(placedWaveCFrame.Position.X, placedWaveCFrame.Position.Y, targetPosition.Z)
				end
			end
			local placedWaveFocusPosition = waveTemplate and waveTemplate:GetAttribute("PlacedFocusPosition")
			local waveFocusPosition = if typeof(placedWaveFocusPosition) == "Vector3" then placedWaveFocusPosition elseif typeof(placedWaveCFrame) == "CFrame" then placedWaveCFrame.Position else fallbackSpawnPosition
			local tsunamiWave = TsunamiWaveVFX.Spawn({
				WaveName = TSUNAMI_WAVE_SETTINGS.WaveName,
				WorkspaceWaveName = TSUNAMI_WAVE_SETTINGS.WorkspaceWaveName,
				UsePlacedCFrame = hasPlacedWorkspaceWave,
				SpawnCFrame = waveSpawnCFrame,
				MoveDirection = waveMoveDirection,
				TargetPosition = targetPosition,
				StopAtTargetPosition = false,
				TargetPlayer = player,
				TargetCharacter = player.Character,
				SafePart = safePart,
				DestroyOnPlayerHit = true,
				DestroyOnSafeReached = true,
				UndergroundDepth = TSUNAMI_WAVE_SETTINGS.UndergroundDepth,
				RiseDuration = TSUNAMI_WAVE_SETTINGS.RiseDuration,
				MoveSpeed = TSUNAMI_WAVE_SETTINGS.MoveSpeed,
				Lifetime = TSUNAMI_WAVE_SETTINGS.Lifetime,
				MoveStartDelay = TSUNAMI_WAVE_SETTINGS.FocusAfterSpawnDelay + TSUNAMI_WAVE_SETTINGS.ReleaseAfterRiseDelay + TSUNAMI_WAVE_SETTINGS.MoveAfterReleaseDelay,
				DamageEnabled = TSUNAMI_WAVE_SETTINGS.DamageEnabled,
				DamageAmount = TSUNAMI_WAVE_SETTINGS.DamageAmount,
				KnockbackAmount = TSUNAMI_WAVE_SETTINGS.KnockbackAmount,
			})
			if tsunamiWave then
				task.wait(TSUNAMI_WAVE_SETTINGS.FocusAfterSpawnDelay)
				CutsceneEvent:FireClient(player, "FocusTsunami", {
					Target = tsunamiWave,
					FocusPosition = waveFocusPosition,
					MoveDirection = waveMoveDirection,
				})
				task.wait(TSUNAMI_WAVE_SETTINGS.RiseDuration + TSUNAMI_WAVE_SETTINGS.ReleaseAfterRiseDelay)
			end
		end
		MorphPlayerAsReward(player, activeClone, -flatDirection)
		if activeClone and activeClone.Parent then activeClone:Destroy() end
		CutsceneEvent:FireClient(player, "Release", { WalkSpeed = MORPH_SETTINGS.WalkSpeed })
		RestoreCharacterMotion(player, MORPH_SETTINGS.WalkSpeed)
	else
		StopOpeningVFX(openingVFX)
		CutsceneEvent:FireClient(player, "End", block)
		RestoreCharacterMotion(player)
	end
	if block and block.Parent then Debris:AddItem(block, 1) end
end

local function ConnectHitMarker(track, callback)
	local fired = false
	local connections = {}
	local function fireOnce()
		if fired then return end
		fired = true
		for _, connection in ipairs(connections) do connection:Disconnect() end
		callback()
	end
	for _, markerName in ipairs(HIT_MARKER_NAMES) do
		table.insert(connections, track:GetMarkerReachedSignal(markerName):Connect(fireOnce))
	end
	return function()
		for _, connection in ipairs(connections) do connection:Disconnect() end
	end
end

local function GetState(player)
	local state = playerStates[player]
	if not state then
		state = {}
		playerStates[player] = state
	end
	return state
end

local function ClearHeldBlock(state)
	if state.heldBlockMotor and state.heldBlockMotor.Parent then state.heldBlockMotor:Destroy() end
	if state.heldBlock and state.heldBlock.Parent then state.heldBlock:Destroy() end
	state.heldBlock = nil
	state.heldBlockMotor = nil
end

local function ClearPlayerState(player)
	local state = playerStates[player]
	if not state then return end
	StopTrack(state.carryTrack, 0.1)
	StopTrack(state.hitTrack, 0)
	state.carryTrack = nil
	state.hitTrack = nil
	if state.bat then state.bat:Destroy() end
	state.bat = nil
	ClearHeldBlock(state)
end

local function CreateHeldLuckyBlock(leftHand)
	local heldBlock
	if HeldBlockTemplate and HeldBlockTemplate:IsA("BasePart") then
		heldBlock = HeldBlockTemplate:Clone()
		heldBlock.Name = "LuckyBlock"
	else
		heldBlock = Instance.new("Part")
		heldBlock.Name = "LuckyBlock"
		heldBlock.Size = Vector3.new(1, 1, 1)
		heldBlock.Transparency = 1
		local template = LuckyBlockTemplate:Clone()
		template.Name = "HeldLuckyBlock"
		for _, child in ipairs(template:GetChildren()) do
			child.Parent = heldBlock
		end
		template:Destroy()
		local rootPart = heldBlock:FindFirstChild("Root")
		if not rootPart then heldBlock:Destroy(); return nil end
		local rootMotor = Instance.new("Motor6D")
		rootMotor.Name = "RootR6D"
		rootMotor.Part0 = heldBlock
		rootMotor.Part1 = rootPart
		rootMotor.Parent = heldBlock
	end
	for _, descendant in ipairs(heldBlock:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
	heldBlock.CanCollide = false
	heldBlock.CanTouch = false
	heldBlock.CanQuery = false
	heldBlock.Massless = true
	heldBlock.Anchored = false
	heldBlock.CFrame = leftHand.CFrame * CARRY_BLOCK_OFFSET
	local rootPart = heldBlock:FindFirstChild("Root")
	if not rootPart then heldBlock:Destroy(); return nil end
	local handMotor = Instance.new("Motor6D")
	handMotor.Name = "LuckyBlock"
	handMotor.Part0 = leftHand
	handMotor.Part1 = heldBlock
	handMotor.C0 = CARRY_BLOCK_OFFSET
	handMotor.Parent = leftHand
	Transparen(heldBlock, 0)
	return heldBlock, handMotor
end

local function StartCarry(player, animationObj, label)
	if busyPlayers[player] then return end
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local leftHand = char:FindFirstChild("LeftHand")
	if not animator or not leftHand then return end
	local state = GetState(player)
	if label == "Hold" then FreezeCharacterMotion(player, state) end
	if not (state.heldBlock and state.heldBlock.Parent == char) then
		ClearHeldBlock(state)
		local heldBlock, heldBlockMotor = CreateHeldLuckyBlock(leftHand)
		if not heldBlock then return end
		heldBlock.Parent = char
		state.heldBlock = heldBlock
		state.heldBlockMotor = heldBlockMotor
	end
	StopTrack(state.carryTrack, 0)
	state.carryTrack = nil
	local animationToPlay = animationObj or CarryAnimationObj
	local ok, trackOrError = pcall(function()
		local track = animator:LoadAnimation(animationToPlay)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0)
		return track
	end)
	if ok then
		state.carryTrack = trackOrError
		state.carryAnimationId = animationToPlay.AnimationId
	else
		warn("[HitMinigameServer] " .. (label or "Carry") .. " animation failed:", trackOrError)
	end
end

local function StopCarry(player)
	local state = playerStates[player]
	if not state or busyPlayers[player] then return end
	StopTrack(state.carryTrack, 0.15)
	state.carryTrack = nil
	state.carryAnimationId = nil
	RestoreCharacterMotion(player)
	ClearHeldBlock(state)
end

local function handleCarryRequest(player, shouldCarry)
	if shouldCarry == "Hold" then
		StartCarry(player, HoldAnimationObj, "Hold")
	elseif shouldCarry then
		StartCarry(player, CarryAnimationObj, "Carry")
	else
		StopCarry(player)
	end
end

local function handleHitRequest(player, distance)
	if busyPlayers[player] then return end
	busyPlayers[player] = true
	distance = math.clamp(distance or 80, LAUNCH_SETTINGS.MinDistance, LAUNCH_SETTINGS.MaxDistance)
	local char = player.Character
	if not char then busyPlayers[player] = nil; return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local root = char:FindFirstChild("HumanoidRootPart")
	local rightHand = char:FindFirstChild("RightHand")
	local leftHand = char:FindFirstChild("LeftHand")
	if not animator or not root or not rightHand or not leftHand then
		busyPlayers[player] = nil; return
	end
	local state = GetState(player)
	if not (state.heldBlock and state.heldBlock.Parent == char and state.heldBlockMotor and state.heldBlockMotor.Parent) then
		ClearHeldBlock(state)
		local heldBlock, heldBlockMotor = CreateHeldLuckyBlock(leftHand)
		if not heldBlock then busyPlayers[player] = nil; return end
		heldBlock.Parent = char
		state.heldBlock = heldBlock
		state.heldBlockMotor = heldBlockMotor
	end
	local bat = BaseballTemplate:Clone()
	local handle = bat:FindFirstChild("Handle")
	for _, m in ipairs(handle:GetChildren()) do
		if m:IsA("Motor6D") and m.Name == "RightHand" then m:Destroy() end
	end
	handle.CFrame = rightHand.CFrame * CFrame.new(0, -0.15, 0)
	handle.Anchored = false
	handle.CanCollide = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rightHand
	weld.Part1 = handle
	weld.Parent = handle
	SetAllPartTransparency(bat, 1)
	bat.Parent = char
	state.bat = bat
	local animObj = Instance.new("Animation")
	animObj.AnimationId = HIT_ANIM_ID
	ContentProvider:PreloadAsync({ animObj })
	local track = animator:LoadAnimation(animObj)
	animObj:Destroy()
	track.Priority = Enum.AnimationPriority.Action
	state.hitTrack = track
	local hitMarkerCleanup
	hitMarkerCleanup = ConnectHitMarker(track, function()
		if hitMarkerCleanup then hitMarkerCleanup(); hitMarkerCleanup = nil end
		local heldBlock = state.heldBlock
		local startCFrame = heldBlock and heldBlock:FindFirstChild("Root") and heldBlock.Root.CFrame or (root.CFrame * CFrame.new(0, 1.5, -2))
		if heldBlock then Transparen(heldBlock, 1) end
		ClearHeldBlock(state)
		VFXEvent:FireClient(player, state.bat, startCFrame.Position)
		local block = LuckyBlockTemplate:Clone()
		block:PivotTo(startCFrame)
		Transparen(block, 1)
		block.Parent = workspace
		Debris:AddItem(block, 12)
		task.wait(IMPACT_HOLD_TIME)
		CutsceneEvent:FireClient(player, "FollowBlock", block)
		local startPos = startCFrame.Position
		local flatLaunchDirection = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if flatLaunchDirection.Magnitude < 0.05 then
			flatLaunchDirection = Vector3.new(0, 0, -1)
		else
			flatLaunchDirection = flatLaunchDirection.Unit
		end
		local horizontalTarget = GetLandingAreaDistanceTarget(root.Position, flatLaunchDirection, distance) or (root.Position + flatLaunchDirection * distance)
		local targetPos, groundPart = GetGroundLandingPosition(horizontalTarget, root.Position.Y, { char })
		local visualGroundPart = GetVisualGroundPartAt(targetPos) or groundPart
		local actualFlatDistance = Vector3.new(targetPos.X - startPos.X, 0, targetPos.Z - startPos.Z).Magnitude
		local height = actualFlatDistance / 4
		local duration = math.clamp(actualFlatDistance / 120, 0.6, 2)
		local cp = (startPos + targetPos) / 2 + Vector3.new(0, height, 0)
		local t0 = tick()
		local lastPos = startPos
		local firstFrame = true
		local spinSeed = math.random() * math.pi * 2
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if firstFrame then
				firstFrame = false
				Transparen(block, 0)
			end
			local t = (tick() - t0) / duration
			if t >= 1 then
				local flatDirection = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
				if flatDirection.Magnitude < 0.05 then flatDirection = Vector3.new(0, 0, -1) else flatDirection = flatDirection.Unit end
				if block.Parent then block.Root.CFrame = CFrame.lookAt(targetPos, targetPos + flatDirection) end
				GroundSmashVFX.Play(Vector3.new(targetPos.X, targetPos.Y - BLOCK_GROUND_OFFSET, targetPos.Z), visualGroundPart, player)
				conn:Disconnect()
				task.spawn(function()
					PlayRewardReveal(player, block, targetPos, flatDirection)
				end)
				return
			end
			local pos = (1 - t)^2 * startPos + 2 * (1 - t) * t * cp + t^2 * targetPos
			if block.Parent then
				local travelDirection = pos - lastPos
				if travelDirection.Magnitude < 0.05 then travelDirection = root.CFrame.LookVector end
				local tumble = CFrame.Angles(t * math.pi * 6 + spinSeed, t * math.pi * 1.5 + spinSeed * 0.15, t * math.pi * 4 + spinSeed * 0.7)
				block.Root.CFrame = CFrame.lookAt(pos, pos + travelDirection) * tumble
			end
			lastPos = pos
		end)
	end)
	CutsceneEvent:FireClient(player, "Start", nil)
	if state.bat then ShowBatVisuals(state.bat) end
	task.wait(0)
	local carryTrack = state.carryTrack
	state.carryTrack = nil
	track:Play(0.05)
	if carryTrack then StopTrack(carryTrack, 0.05) end
	track.Stopped:Wait()
	if hitMarkerCleanup then hitMarkerCleanup(); hitMarkerCleanup = nil end
	StopTrack(track, 0)
	state.hitTrack = nil
	if state.bat then state.bat:Destroy() end
	state.bat = nil
	ClearHeldBlock(state)
	busyPlayers[player] = nil
end

local function HookPlayer(player)
	player.CharacterRemoving:Connect(function()
		busyPlayers[player] = nil
		ClearPlayerState(player)
	end)
end

local function connectEvents()
	for _, player in ipairs(Players:GetPlayers()) do HookPlayer(player) end
	Players.PlayerAdded:Connect(HookPlayer)
	Players.PlayerRemoving:Connect(function(player)
		busyPlayers[player] = nil
		ClearPlayerState(player)
		playerStates[player] = nil
	end)
end

local function connectBindables() end

local function connectRemotes()
	CarryEvent.OnServerEvent:Connect(handleCarryRequest)
	HitEvent.OnServerEvent:Connect(handleHitRequest)
end

connectEvents()
connectBindables()
connectRemotes()
print("[HitMinigameServer] Started")
