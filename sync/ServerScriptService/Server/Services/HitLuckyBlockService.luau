local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local HitLuckyBlockService = Framework:CreateService("HitLuckyBlockService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

function HitLuckyBlockService:Initialize()
	self.Assets = ReplicatedStorage:WaitForChild("Assets")
	self.HitLuckyBlockAssets = self.Assets:WaitForChild("HitLuckyBlock")
	self.BrainrotsFolder = self.Assets:WaitForChild("Brainrots")
	self.TsunamiWavesFolder = ReplicatedStorage:WaitForChild("VFX"):WaitForChild("TsunamiWaves")
	self.OpeningVFXTemplate = self.HitLuckyBlockAssets:WaitForChild("OpeningVFX")
	self.OBVFXTemplate = self.HitLuckyBlockAssets:WaitForChild("OBVFX")
	self.MapCoreFolder = workspace:WaitForChild("MapCore")
	self.LandingArea = self.MapCoreFolder:WaitForChild("LandingArea")
	self.WaveSectionsFolder = self.MapCoreFolder:WaitForChild("WaveSections")
	self.SafeZone = workspace:WaitForChild("Zones"):WaitForChild("SafeZone")

	self.ROLL_COUNT = 20
	self.ROLL_FAST_STEP_TIME = 0.08
	self.ROLL_SLOW_STEP_TIME = 0.4
	self.ROLL_FINAL_STEP_TIME = 0.9
	self.ROLL_START_SCALE = 0.8
	self.ROLL_END_SCALE = 1
	self.ROLL_POP_SCALE = 1.08
	self.ROLL_POP_FRACTION = 0.3
	self.SILHOUETTE_COLOR = Color3.fromRGB(0, 0, 0)
	self.MORPH_WALK_SPEED = 24
	self.MORPH_JUMP_POWER = 50
	self.TSUNAMI_DELAY_AFTER_RELEASE = 0.6
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

function HitLuckyBlockService:GetRollStepDuration(index, total)
	if index >= total then
		return self.ROLL_FINAL_STEP_TIME
	end

	local alpha = math.clamp((index - 1) / math.max(total - 1, 1), 0, 1)
	local slowedAlpha = alpha * alpha
	return self.ROLL_FAST_STEP_TIME
		+ (self.ROLL_SLOW_STEP_TIME - self.ROLL_FAST_STEP_TIME) * slowedAlpha
end

function HitLuckyBlockService:AnimateRollClone(clone, groundPos, facingDir, duration)
	self:ScaleClone(clone, self.ROLL_START_SCALE)
	self:PlaceClone(clone, groundPos, facingDir)

	local startedAt = os.clock()
	while clone and clone.Parent do
		local alpha = math.clamp((os.clock() - startedAt) / duration, 0, 1)
		local scale
		if alpha <= self.ROLL_POP_FRACTION then
			local popAlpha = TweenService:GetValue(alpha / self.ROLL_POP_FRACTION, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			scale = self.ROLL_START_SCALE + (self.ROLL_POP_SCALE - self.ROLL_START_SCALE) * popAlpha
		else
			local settleAlpha = (alpha - self.ROLL_POP_FRACTION) / (1 - self.ROLL_POP_FRACTION)
			settleAlpha = TweenService:GetValue(settleAlpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			scale = self.ROLL_POP_SCALE + (self.ROLL_END_SCALE - self.ROLL_POP_SCALE) * settleAlpha
		end

		self:ScaleClone(clone, scale)
		self:PlaceClone(clone, groundPos, facingDir)

		if alpha >= 1 then
			break
		end

		RunService.Heartbeat:Wait()
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

function HitLuckyBlockService:GetClosestWaveSection(landingPos)
	local closestSection = nil
	local closestDistance = math.huge

	for _, section in ipairs(self.WaveSectionsFolder:GetChildren()) do
		if section:IsA("BasePart") then
			local delta = Vector3.new(section.Position.X - landingPos.X, 0, section.Position.Z - landingPos.Z)
			local distance = delta.Magnitude
			if distance < closestDistance then
				closestSection = section
				closestDistance = distance
			end
		end
	end

	return closestSection
end

function HitLuckyBlockService:GetWaveRouteDirection(waveSection)
	local useXAxis = self.LandingArea.Size.X >= self.LandingArea.Size.Z
	local routeAxis = if useXAxis then self.LandingArea.CFrame.RightVector else self.LandingArea.CFrame.LookVector
	routeAxis = Vector3.new(routeAxis.X, 0, routeAxis.Z)
	if routeAxis.Magnitude < 0.05 then
		routeAxis = Vector3.new(0, 0, -1)
	else
		routeAxis = routeAxis.Unit
	end

	local toSafeZone = Vector3.new(
		self.SafeZone.Position.X - waveSection.Position.X,
		0,
		self.SafeZone.Position.Z - waveSection.Position.Z
	)
	if routeAxis:Dot(toSafeZone) < 0 then
		routeAxis = -routeAxis
	end

	return routeAxis
end

function HitLuckyBlockService:GetSafeZoneStopPosition(spawnPos, routeDirection, groundY)
	local safeZone = self.SafeZone
	local horizontalToSafeZone = Vector3.new(safeZone.Position.X - spawnPos.X, 0, safeZone.Position.Z - spawnPos.Z)
	local centerDistance = horizontalToSafeZone:Dot(routeDirection)
	local right = safeZone.CFrame.RightVector
	local look = safeZone.CFrame.LookVector
	local safeHalfExtent = math.abs(right:Dot(routeDirection)) * safeZone.Size.X / 2
		+ math.abs(look:Dot(routeDirection)) * safeZone.Size.Z / 2
	local stopDistance = math.max(centerDistance - safeHalfExtent, 0)
	local stopPos = spawnPos + routeDirection * stopDistance

	return Vector3.new(stopPos.X, groundY, stopPos.Z)
end

function HitLuckyBlockService:StartTsunamiCatchCheck(wave, player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { character }

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not wave.Parent or humanoid.Health <= 0 or character ~= player.Character then
			connection:Disconnect()
			return
		end

		if not character:FindFirstChild("BrainrotMorph") then
			return
		end

		local boxCFrame, boxSize = wave:GetBoundingBox()
		local touchingParts = workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams)
		if #touchingParts > 0 then
			player.CharacterAdded:Once(function()
				if wave and wave.Parent then
					wave:Destroy()
				end
			end)
			humanoid.Health = 0
			connection:Disconnect()
		end
	end)
end

function HitLuckyBlockService:SpawnTsunamiWave(player, landingPos)
	local waves = self.TsunamiWavesFolder:GetChildren()
	if #waves == 0 then
		warn("[HitLuckyBlockService] No tsunami waves found in ReplicatedStorage.VFX.TsunamiWaves")
		return nil
	end
	local wave = waves[math.random(1, #waves)]:Clone()

	local waveRoot = wave:FindFirstChild("Root")
	if not waveRoot then
		warn("[HitLuckyBlockService] Tsunami wave model is missing a Root part")
		wave:Destroy()
		return nil
	end

	local waveSection = self:GetClosestWaveSection(landingPos)
	if not waveSection then
		warn("[HitLuckyBlockService] No wave sections found in workspace.MapCore.WaveSections")
		wave:Destroy()
		return nil
	end

	local _, waveSize = wave:GetBoundingBox()
	local groundY = landingPos.Y
	local sectionPos = waveSection.Position
	local spawnPos = Vector3.new(sectionPos.X, groundY - waveSize.Y - 4, sectionPos.Z)
	local routeDirection = self:GetWaveRouteDirection(waveSection)
	local targetPos = self:GetSafeZoneStopPosition(spawnPos, routeDirection, groundY)
	local spawnCFrame = CFrame.lookAt(spawnPos, spawnPos + routeDirection)

	wave:PivotTo(spawnCFrame)
	wave.Parent = workspace

	for _, part in ipairs(wave:GetDescendants()) do
		if part:IsA("BasePart") and part ~= waveRoot then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true

			local weld = part:FindFirstChild("TsunamiWeld") or Instance.new("WeldConstraint")
			weld.Name = "TsunamiWeld"
			weld.Part0 = waveRoot
			weld.Part1 = part
			weld.Parent = part
		end
	end
	waveRoot.Anchored = true
	waveRoot.CanCollide = false
	waveRoot.CFrame = spawnCFrame
	self:StartTsunamiCatchCheck(wave, player)

	local risePos = Vector3.new(spawnPos.X, groundY, spawnPos.Z)
	local riseCFrame = CFrame.lookAt(risePos, risePos + routeDirection)
	local riseTween = TweenService:Create(waveRoot, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = riseCFrame.Position,
	})
	riseTween:Play()

	task.delay(2.0, function()
		if waveRoot and waveRoot.Parent then
			local moveTween = TweenService:Create(waveRoot, TweenInfo.new(10, Enum.EasingStyle.Linear), {
				CFrame = CFrame.lookAt(targetPos, targetPos + routeDirection)
			})
			moveTween:Play()
			moveTween.Completed:Once(function()
				if wave and wave.Parent then
					wave:Destroy()
				end
			end)
		end
	end)

	Debris:AddItem(wave, 15)
	return waveRoot
end

function HitLuckyBlockService:DoReveal(player, landingPos, flatDirection)
	local candidates = self:CollectCandidates()
	if #candidates == 0 then
		warn("[HitLuckyBlockService] No candidates found! Releasing client.")
		self.HitLuckyBlockController.Server.Fire:CutsceneEvent(player, "Release", nil)
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

	self.HitLuckyBlockController.Server.Fire:CutsceneEvent(player, "FocusReveal", {
		Position = groundPos,
		Direction = flatDirection,
	})
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

		self:AnimateRollClone(
			activeClone,
			groundPos,
			flatDirection,
			self:GetRollStepDuration(i, self.ROLL_COUNT)
		)
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

		self:MorphPlayer(player, activeClone, -flatDirection, groundPos)
		activeClone:Destroy()
		self.HitLuckyBlockController.Server.Fire:CutsceneEvent(player, "Release", nil)

		task.delay(self.TSUNAMI_DELAY_AFTER_RELEASE, function()
			self:SpawnTsunamiWave(player, landingPos)
		end)
	else
		self.HitLuckyBlockController.Server.Fire:CutsceneEvent(player, "Release", nil)
	end
end

function HitLuckyBlockService:Start()
	self.HitLuckyBlockController = Framework:GetController("HitLuckyBlockController")
end

function HitLuckyBlockService.Client:BlockLanded(player, landingPos, flatDirection)
	if typeof(landingPos) ~= "Vector3" then
		return
	end
	if typeof(flatDirection) ~= "Vector3" then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			self:DoReveal(player, landingPos, flatDirection)
		end)
		if not ok then
			warn("[HitLuckyBlockService] Error in DoReveal task:", err)
		end
	end)
end

return HitLuckyBlockService
