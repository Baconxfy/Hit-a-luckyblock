local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local HitLuckyBlockService = Framework:CreateService("HitLuckyBlockService")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

function HitLuckyBlockService:Initialize()
	-- Create shared RemoteEvents so the client can WaitForChild them
	self.CutsceneEvent = ReplicatedStorage:FindFirstChild("CutsceneEvent") or Instance.new("RemoteEvent")
	self.CutsceneEvent.Name = "CutsceneEvent"
	self.CutsceneEvent.Parent = ReplicatedStorage
	
	self.BlockLandedEvent = ReplicatedStorage:FindFirstChild("BlockLandedEvent") or Instance.new("RemoteEvent")
	self.BlockLandedEvent.Name = "BlockLandedEvent"
	self.BlockLandedEvent.Parent = ReplicatedStorage
	
	self.Assets = ReplicatedStorage:WaitForChild("Assets")
	self.HitLuckyBlockAssets = self.Assets:WaitForChild("HitLuckyBlock")
	self.BrainrotsFolder = self.Assets:WaitForChild("Brainrots")
	self.TsunamiWavesFolder = ReplicatedStorage:WaitForChild("VFX"):WaitForChild("TsunamiWaves")
	self.OpeningVFXTemplate = self.HitLuckyBlockAssets:WaitForChild("OpeningVFX")
	self.OBVFXTemplate = self.HitLuckyBlockAssets:WaitForChild("OBVFX")
	
	self.SafePart = workspace:WaitForChild("Map"):WaitForChild("Safe")
	
	self.ROLL_COUNT = 30
	self.ROLL_TIME = 5
	self.ROLL_SPEED = 3
	self.SILHOUETTE_COLOR = Color3.fromRGB(0, 0, 0)
	self.MORPH_WALK_SPEED = 24
	self.MORPH_JUMP_POWER = 50
end

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

function HitLuckyBlockService:CollectCandidates()
	local candidates = {}
	for _, brainrotFolder in ipairs(self.BrainrotsFolder:GetChildren()) do
		if not brainrotFolder:IsA("Folder") then continue end
		for _, mutation in ipairs(brainrotFolder:GetChildren()) do
			if mutation:IsA("Model") and mutation:FindFirstChildWhichIsA("BasePart", true) then
				table.insert(candidates, mutation)
			end
		end
	end
	return candidates
end

function HitLuckyBlockService:ApplySilhouette(clone)
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("SurfaceAppearance") or desc:IsA("Decal") or desc:IsA("Texture") then
			desc:Destroy()
		elseif desc:IsA("SpecialMesh") then
			desc.TextureId = ""
		elseif desc:IsA("BasePart") and desc.Transparency < 1 then
			desc.Color = self.SILHOUETTE_COLOR
			desc.Material = Enum.Material.SmoothPlastic
			desc.Reflectance = 0
			if desc:IsA("MeshPart") then
				desc.TextureID = ""
			end
		end
	end
end

function HitLuckyBlockService:PrepareClone(template)
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

function HitLuckyBlockService:ScaleClone(clone, mult)
	if not clone or not clone.Parent then return end
	pcall(function()
		local base = clone:GetAttribute("_baseScale") or 1
		clone:ScaleTo(base * mult)
	end)
end

function HitLuckyBlockService:PlaceClone(clone, groundPos, facingDir)
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

function HitLuckyBlockService:MorphPlayer(player, rewardSource, facingDir, groundPos)
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
	humanoid.WalkSpeed = self.MORPH_WALK_SPEED
	if humanoid.UseJumpPower then
		humanoid.JumpPower = self.MORPH_JUMP_POWER
	else
		humanoid.JumpHeight = 7.2
	end
end

function HitLuckyBlockService:SpawnTsunamiWave(landingPos, flatDirection)
	local waves = self.TsunamiWavesFolder:GetChildren()
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

function HitLuckyBlockService:DoReveal(player, landingPos, flatDirection)
	local candidates = self:CollectCandidates()
	if #candidates == 0 then
		self.CutsceneEvent:FireClient(player, "Release", nil)
		return
	end

	local finalReward = candidates[math.random(1, #candidates)]
	local groundPos = landingPos

	local openingHolder = MakeHolder(groundPos)
	local openingVFX = self.OpeningVFXTemplate:Clone()
	openingVFX.Parent = openingHolder
	for _, e in ipairs(openingVFX:GetDescendants()) do
		if e:IsA("ParticleEmitter") then e.Enabled = true end
	end
	EmitVFX(openingVFX)

	self.CutsceneEvent:FireClient(player, "FocusReward", groundPos)
	task.wait(0.6)
	self.CutsceneEvent:FireClient(player, "FocusOpening", groundPos)
	task.wait(0.35)

	local activeClone = nil
	for i = 1, self.ROLL_COUNT do
		if activeClone and activeClone.Parent then
			activeClone:Destroy()
			activeClone = nil
		end

		local isFinal = i == self.ROLL_COUNT
		local pick = if isFinal then finalReward else candidates[math.random(1, #candidates)]
		activeClone = self:PrepareClone(pick)
		if not isFinal then self:ApplySilhouette(activeClone) end

		local alpha = i / self.ROLL_COUNT
		local baseStep = self.ROLL_TIME / math.max(self.ROLL_COUNT - 1, 1)
		local stepDuration = if isFinal then 1
			else math.clamp((baseStep * (0.6 + alpha * 0.8)) / self.ROLL_SPEED, 0.04, 0.55)

		local stepStart = os.clock()
		while activeClone and activeClone.Parent and os.clock() - stepStart < stepDuration do
			local t = math.clamp((os.clock() - stepStart) / stepDuration, 0, 1)
			local popScale = 0.5 + 0.85 * math.sin(t * math.pi)
			local lift = math.sin(t * math.pi) * 0.5
			self:ScaleClone(activeClone, popScale)
			self:PlaceClone(activeClone, groundPos + Vector3.new(0, lift, 0), flatDirection)
			RunService.Heartbeat:Wait()
		end
	end

	if openingVFX and openingVFX.Parent then
		for _, e in ipairs(openingVFX:GetDescendants()) do
			if e:IsA("ParticleEmitter") then e.Enabled = false end
		end
		Debris:AddItem(openingHolder, 2)
	end

	if activeClone and activeClone.Parent then
		self:ScaleClone(activeClone, 1)
		self:PlaceClone(activeClone, groundPos, flatDirection)

		local obvfxHolder = MakeHolder(groundPos + Vector3.new(0, 1, 0))
		local obvfx = self.OBVFXTemplate:Clone()
		obvfx.Parent = obvfxHolder
		EmitVFX(obvfx)
		Debris:AddItem(obvfxHolder, 3)

		task.spawn(function()
			local waveRoot = self:SpawnTsunamiWave(landingPos, flatDirection)
			if waveRoot then
				self.CutsceneEvent:FireClient(player, "FocusTsunami", waveRoot)
				task.wait(2.5)
			end

			if activeClone and activeClone.Parent then
				self:MorphPlayer(player, activeClone, -flatDirection, groundPos)
				activeClone:Destroy()
			end

			self.CutsceneEvent:FireClient(player, "Release", nil)
		end)
	else
		self.CutsceneEvent:FireClient(player, "Release", nil)
	end
end

function HitLuckyBlockService:Start()
	self.BlockLandedEvent.OnServerEvent:Connect(function(player, landingPos, flatDirection)
		if typeof(landingPos) ~= "Vector3" then return end
		if typeof(flatDirection) ~= "Vector3" then return end
		task.spawn(function() self:DoReveal(player, landingPos, flatDirection) end)
	end)
end

return HitLuckyBlockService
