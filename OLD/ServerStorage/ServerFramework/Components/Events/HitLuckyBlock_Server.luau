local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
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

--< Helpers

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

local function CollectCandidates()
	local candidates = {}
	for _, brainrotFolder in ipairs(BrainrotsFolder:GetChildren()) do
		if not brainrotFolder:IsA("Folder") then continue end
		for _, mutation in ipairs(brainrotFolder:GetChildren()) do
			if mutation:IsA("Model") and mutation:FindFirstChildWhichIsA("BasePart", true) then
				table.insert(candidates, mutation)
			end
		end
	end
	return candidates
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
	local candidates = CollectCandidates()
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

	-- Slot machine
	local activeClone = nil
	for i = 1, ROLL_COUNT do
		if activeClone and activeClone.Parent then
			activeClone:Destroy()
			activeClone = nil
		end

		local isFinal = i == ROLL_COUNT
		local pick = if isFinal then finalReward else candidates[math.random(1, #candidates)]
		activeClone = PrepareClone(pick)
		if not isFinal then ApplySilhouette(activeClone) end

		local alpha = i / ROLL_COUNT
		local baseStep = ROLL_TIME / math.max(ROLL_COUNT - 1, 1)
		local stepDuration = if isFinal then 1
			else math.clamp((baseStep * (0.6 + alpha * 0.8)) / ROLL_SPEED, 0.04, 0.55)

		local stepStart = os.clock()
		while activeClone and activeClone.Parent and os.clock() - stepStart < stepDuration do
			local t = math.clamp((os.clock() - stepStart) / stepDuration, 0, 1)
			local popScale = 0.5 + 0.85 * math.sin(t * math.pi)
			local lift = math.sin(t * math.pi) * 0.5
			ScaleClone(activeClone, popScale)
			PlaceClone(activeClone, groundPos + Vector3.new(0, lift, 0), flatDirection)
			RunService.Heartbeat:Wait()
		end
	end

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
	BlockLandedEvent.OnServerEvent:Connect(function(player, landingPos, flatDirection)
		if typeof(landingPos) ~= "Vector3" then return end
		if typeof(flatDirection) ~= "Vector3" then return end
		task.spawn(DoReveal, player, landingPos, flatDirection)
	end)
end
