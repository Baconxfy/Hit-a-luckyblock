local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- Create shared RemoteEvents so the client can WaitForChild them
local CutsceneEvent = Instance.new("RemoteEvent")
CutsceneEvent.Name = "CutsceneEvent"
CutsceneEvent.Parent = ReplicatedStorage

local BlockLandedEvent = Instance.new("RemoteEvent")
BlockLandedEvent.Name = "BlockLandedEvent"
BlockLandedEvent.Parent = ReplicatedStorage

--< Assets
local Assets = ReplicatedStorage:WaitForChild("Assets")
local HitLuckyBlockAssets = Assets.HitLuckyBlock
local BrainrotsFolder = Assets.Brainrots
local TsunamiWavesFolder = ReplicatedStorage:WaitForChild("VFX"):WaitForChild("TsunamiWaves")
local OpeningVFXTemplate = HitLuckyBlockAssets.OpeningVFX
local OBVFXTemplate = HitLuckyBlockAssets.OBVFX

--< Workspace refs
local SafePart = workspace:WaitForChild("Map"):WaitForChild("Safe")

--< Settings
local ROLL_COUNT = 30
local ROLL_TIME = 5
local ROLL_SPEED = 3
local SILHOUETTE_COLOR = Color3.fromRGB(0, 0, 0)
local MORPH_WALK_SPEED = 24
local MORPH_JUMP_POWER = 50
local REVEAL_VISUAL_DURATION = (ROLL_TIME / ROLL_SPEED) + 1

--< Helpers
local RewardCandidates = {}
local CandidateConnections = {}

local function EmitVFX(parent)
	for _, e in ipairs(parent:GetDescendants()) do
		if e:IsA("ParticleEmitter") then
			e:Emit(e:GetAttribute("EmitCount") or 1)
		end
	end
end

local function MakeHolder(position)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(position)
	part.Parent = workspace
	return part
end

local function DisconnectCandidateCache()
	for _, connection in ipairs(CandidateConnections) do
		connection:Disconnect()
	end

	table.clear(CandidateConnections)
end

local function RebuildRewardCandidates()
	local candidates = {}

	for _, brainrotFolder in ipairs(BrainrotsFolder:GetChildren()) do
		if not brainrotFolder:IsA("Folder") then continue end
		for _, mutation in ipairs(brainrotFolder:GetChildren()) do
			if mutation:IsA("Model") and mutation:FindFirstChildWhichIsA("BasePart", true) then
				table.insert(candidates, {
					instance = mutation,
					brainrot = brainrotFolder.Name,
					mutation = mutation.Name,
				})
			end
		end
	end

	RewardCandidates = candidates
end

local function BindRewardCandidateCache()
	DisconnectCandidateCache()
	RebuildRewardCandidates()

	local function watchBrainrotFolder(brainrotFolder)
		if not brainrotFolder:IsA("Folder") then
			return
		end

		table.insert(CandidateConnections, brainrotFolder.ChildAdded:Connect(RebuildRewardCandidates))
		table.insert(CandidateConnections, brainrotFolder.ChildRemoved:Connect(RebuildRewardCandidates))
	end

	for _, brainrotFolder in ipairs(BrainrotsFolder:GetChildren()) do
		watchBrainrotFolder(brainrotFolder)
	end

	table.insert(CandidateConnections, BrainrotsFolder.ChildAdded:Connect(function(child)
		watchBrainrotFolder(child)
		RebuildRewardCandidates()
	end))

	table.insert(CandidateConnections, BrainrotsFolder.ChildRemoved:Connect(RebuildRewardCandidates))
end

local function BuildRevealPayload(candidates, finalReward, groundPos, flatDirection)
	local names = table.create(math.min(#candidates, ROLL_COUNT))

	for index = 1, math.min(#candidates, ROLL_COUNT) do
		local candidate = candidates[index]
		table.insert(names, {
			Brainrot = candidate.brainrot,
			Mutation = candidate.mutation,
		})
	end

	return {
		FinalBrainrot = finalReward.brainrot,
		FinalMutation = finalReward.mutation,
		CandidateNames = names,
		GroundPosition = groundPos,
		Direction = flatDirection,
		Duration = REVEAL_VISUAL_DURATION,
	}
end

local function ApplySilhouette(clone)
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("SurfaceAppearance") or desc:IsA("Decal") or desc:IsA("Texture") then
			desc:Destroy()
		elseif desc:IsA("SpecialMesh") then
			desc.TextureId = ""
		elseif desc:IsA("BasePart") and desc.Transparency < 1 then
			desc.Color = SILHOUETTE_COLOR
			desc.Material = Enum.Material.SmoothPlastic
			desc.Reflectance = 0
			if desc:IsA("MeshPart") then
				desc.TextureID = ""
			end
		end
	end
end

local function PrepareClone(template)
	local clone = template:Clone()
	clone.Parent = workspace
	local ok, scale = pcall(function() return clone:GetScale() end)
	if ok then clone:SetAttribute("_baseScale", scale) end
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

local function ScaleClone(clone, mult)
	if not clone or not clone.Parent then return end
	pcall(function()
		local base = clone:GetAttribute("_baseScale") or 1
		clone:ScaleTo(base * mult)
	end)
end

local function PlaceClone(clone, groundPos, facingDir)
	if not clone or not clone.Parent then return end
	local ok, boxCFrame, boxSize = pcall(function() return clone:GetBoundingBox() end)
	if not ok then return end
	local fd = if facingDir.Magnitude > 0.05 then facingDir.Unit else Vector3.new(0, 0, -1)
	local centerPos = Vector3.new(groundPos.X, groundPos.Y + boxSize.Y / 2, groundPos.Z)
	local targetCFrame = CFrame.lookAt(centerPos, centerPos + fd)
	local delta = targetCFrame * boxCFrame:Inverse()
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CFrame = delta * part.CFrame
		end
	end
end

-- groundPos is the landing position — the player is teleported there before morphing
local function MorphPlayer(player, rewardSource, facingDir, groundPos)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root then return end

	local oldMorph = character:FindFirstChild("BrainrotMorph")
	if oldMorph then oldMorph:Destroy() end

	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") and desc ~= root then
			desc.Transparency = 1
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = 1
		end
	end

	local morph = rewardSource:Clone()
	morph.Name = "BrainrotMorph"
	morph.Parent = character

	for _, desc in ipairs(morph:GetDescendants()) do
		if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("Humanoid") then
			desc:Destroy()
		end
	end

	-- Teleport the player's root to the landing position
	local fd = Vector3.new(facingDir.X, 0, facingDir.Z)
	if fd.Magnitude < 0.05 then fd = root.CFrame.LookVector end
	fd = fd.Unit

	local rootTargetPos = Vector3.new(
		groundPos.X,
		groundPos.Y + humanoid.HipHeight + root.Size.Y / 2,
		groundPos.Z
	)
	root.CFrame = CFrame.lookAt(rootTargetPos, rootTargetPos + fd)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	-- Position the morph at the same ground position
	local ok, boxCFrame, boxSize = pcall(function() return morph:GetBoundingBox() end)
	if not ok then return end

	local centerPos = Vector3.new(groundPos.X, groundPos.Y + boxSize.Y / 2, groundPos.Z)
	local targetCFrame = CFrame.lookAt(centerPos, centerPos + fd)
	local delta = targetCFrame * boxCFrame:Inverse()

	for _, part in ipairs(morph:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CFrame = delta * part.CFrame
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

	root.Anchored = false
	humanoid.AutoRotate = true
	humanoid.WalkSpeed = MORPH_WALK_SPEED
	if humanoid.UseJumpPower then
		humanoid.JumpPower = MORPH_JUMP_POWER
	else
		humanoid.JumpHeight = 7.2
	end
end

local function SpawnTsunamiWave(landingPos, flatDirection)
	local waves = TsunamiWavesFolder:GetChildren()
	if #waves == 0 then return nil end
	local wave = waves[math.random(1, #waves)]:Clone()
	wave.Parent = workspace

	local waveRoot = wave:FindFirstChild("Root")
	if not waveRoot then
		wave:Destroy()
		return nil
	end

	local _, waveSize = wave:GetBoundingBox()
	local spawnPos = landingPos + (-flatDirection) * 18
	spawnPos = Vector3.new(spawnPos.X, landingPos.Y - waveSize.Y - 4, spawnPos.Z)
	wave:PivotTo(CFrame.lookAt(spawnPos, spawnPos + flatDirection))

	local risePos = Vector3.new(spawnPos.X, landingPos.Y, spawnPos.Z)
	TweenService:Create(waveRoot, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.lookAt(risePos, risePos + flatDirection)
	}):Play()
	task.wait(2.0)

	local moveTarget = landingPos + flatDirection * 80
	TweenService:Create(waveRoot, TweenInfo.new(6, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(moveTarget, moveTarget + flatDirection)
	}):Play()

	Debris:AddItem(wave, 12)
	return waveRoot
end

local function DoReveal(player, landingPos, flatDirection)
	local candidates = RewardCandidates
	if #candidates == 0 then
		warn("[HitLuckyBlock_Server] No brainrot candidates")
		CutsceneEvent:FireClient(player, "Release", nil)
		return
	end

	local finalReward = candidates[math.random(1, #candidates)]
	local groundPos = landingPos

	-- Opening VFX
	local openingHolder = MakeHolder(groundPos)
	local openingVFX = OpeningVFXTemplate:Clone()
	openingVFX.Parent = openingHolder
	for _, e in ipairs(openingVFX:GetDescendants()) do
		if e:IsA("ParticleEmitter") then e.Enabled = true end
	end
	EmitVFX(openingVFX)

	CutsceneEvent:FireClient(player, "FocusReward", groundPos)
	task.wait(0.6)
	CutsceneEvent:FireClient(player, "FocusOpening", groundPos)
	task.wait(0.35)

	CutsceneEvent:FireClient(player, "RewardReveal", BuildRevealPayload(candidates, finalReward, groundPos, flatDirection))
	task.wait(REVEAL_VISUAL_DURATION)

	local activeClone = PrepareClone(finalReward.instance)

	-- Stop opening VFX
	if openingVFX and openingVFX.Parent then
		for _, e in ipairs(openingVFX:GetDescendants()) do
			if e:IsA("ParticleEmitter") then e.Enabled = false end
		end
		Debris:AddItem(openingHolder, 2)
	end

	if activeClone and activeClone.Parent then
		ScaleClone(activeClone, 1)
		PlaceClone(activeClone, groundPos, flatDirection)

		-- OBVFX burst
		local obvfxHolder = MakeHolder(groundPos + Vector3.new(0, 1, 0))
		local obvfx = OBVFXTemplate:Clone()
		obvfx.Parent = obvfxHolder
		EmitVFX(obvfx)
		Debris:AddItem(obvfxHolder, 3)

		-- Tsunami + morph
		task.spawn(function()
			local waveRoot = SpawnTsunamiWave(landingPos, flatDirection)
			if waveRoot then
				CutsceneEvent:FireClient(player, "FocusTsunami", waveRoot)
				task.wait(2.5)
			end

			if activeClone and activeClone.Parent then
				MorphPlayer(player, activeClone, -flatDirection, groundPos)
				activeClone:Destroy()
			end

			CutsceneEvent:FireClient(player, "Release", nil)
		end)
	else
		CutsceneEvent:FireClient(player, "Release", nil)
	end
end

return function()
	BindRewardCandidateCache()

	BlockLandedEvent.OnServerEvent:Connect(function(player, landingPos, flatDirection)
		if typeof(landingPos) ~= "Vector3" then return end
		if typeof(flatDirection) ~= "Vector3" then return end
		task.spawn(DoReveal, player, landingPos, flatDirection)
	end)
end
