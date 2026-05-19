local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local HitLuckyBlockVisualController = Framework:CreateController("HitLuckyBlockVisualController")

HitLuckyBlockVisualController.Server = {}

local ROLL_COUNT = 30
local ROLL_TIME = 5
local ROLL_SPEED = 3
local SILHOUETTE_COLOR = Color3.fromRGB(0, 0, 0)

local function flattenDirection(direction: Vector3): Vector3
	local flat = Vector3.new(direction.X, 0, direction.Z)

	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end

	return flat.Unit
end

local function sampleQuadraticBezier(startPosition: Vector3, controlPosition: Vector3, targetPosition: Vector3, alpha: number): Vector3
	local a = startPosition:Lerp(controlPosition, alpha)
	local b = controlPosition:Lerp(targetPosition, alpha)

	return a:Lerp(b, alpha)
end

local function pivotVisual(visual: Instance, cframe: CFrame)
	if visual:IsA("Model") then
		visual:PivotTo(cframe)
	elseif visual:IsA("BasePart") then
		visual.CFrame = cframe
	end
end

local function anchorVisual(visual: Instance)
	if visual:IsA("BasePart") then
		visual.Anchored = true
		visual.CanCollide = false
		visual.CanTouch = false
		visual.CanQuery = false
		return
	end

	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

local function findVisualByNames(root: Instance?, names)
	if not root then
		return nil
	end

	for _, name in ipairs(names) do
		local direct = root:FindFirstChild(name)
		if direct and (direct:IsA("Model") or direct:IsA("BasePart")) then
			return direct
		end

		local deep = root:FindFirstChild(name, true)
		if deep and (deep:IsA("Model") or deep:IsA("BasePart")) then
			return deep
		end
	end

	return nil
end

local function createFallbackLuckyBlock()
	local part = Instance.new("Part")
	part.Name = "FallbackLuckyBlock"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = Vector3.new(5, 5, 5)
	part.Color = Color3.fromRGB(255, 220, 0)
	part.Material = Enum.Material.Neon

	return part
end

local function getLuckyBlockTemplate()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local hitLuckyBlockAssets = assets and assets:FindFirstChild("HitLuckyBlock")

	return findVisualByNames(hitLuckyBlockAssets, {
		"LuckyBlock",
		"LuckyBlockModel",
		"Block",
		"Visual",
	})
		or findVisualByNames(assets, {
			"LuckyBlock",
			"LuckyBlockModel",
		})
end

local function getBrainrotTemplate(brainrotName: string?, mutationName: string?)
	if not brainrotName or not mutationName then
		return nil
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local brainrots = assets and assets:FindFirstChild("Brainrots")
	local brainrotFolder = brainrots and brainrots:FindFirstChild(brainrotName)

	if not brainrotFolder then
		return nil
	end

	local mutation = brainrotFolder:FindFirstChild(mutationName)

	if not mutation then
		return nil
	end

	if mutation:IsA("Model") or mutation:IsA("BasePart") then
		return mutation
	end

	if mutation:IsA("Folder") then
		return mutation:FindFirstChildWhichIsA("Model") or mutation:FindFirstChildWhichIsA("BasePart")
	end

	return nil
end

local function makeHolder(position: Vector3)
	local holder = Instance.new("Part")
	holder.Name = "LocalVFXHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace

	return holder
end

local function emitVFX(root: Instance)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant:Emit(descendant:GetAttribute("EmitCount") or 1)
		end
	end
end

local function enableParticleVFX(root: Instance, enabled: boolean)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = enabled
		end
	end
end

local function findVFXTemplate(names)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local hitLuckyBlockAssets = assets and assets:FindFirstChild("HitLuckyBlock")

	for _, name in ipairs(names) do
		local found = hitLuckyBlockAssets and hitLuckyBlockAssets:FindFirstChild(name, true)
		if found then
			return found
		end
	end

	return nil
end

local function applySilhouette(visual: Instance)
	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("SurfaceAppearance") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant:Destroy()
		elseif descendant:IsA("SpecialMesh") then
			descendant.TextureId = ""
		elseif descendant:IsA("BasePart") and descendant.Transparency < 1 then
			descendant.Color = SILHOUETTE_COLOR
			descendant.Material = Enum.Material.SmoothPlastic
			descendant.Reflectance = 0

			if descendant:IsA("MeshPart") then
				descendant.TextureID = ""
			end
		end
	end
end

local function scaleVisual(visual: Instance, multiplier: number)
	if visual:IsA("Model") then
		local baseScale = visual:GetAttribute("_baseScale") or 1

		pcall(function()
			visual:ScaleTo(baseScale * multiplier)
		end)
	elseif visual:IsA("BasePart") then
		local baseSize = visual:GetAttribute("_baseSize")
		if typeof(baseSize) ~= "Vector3" then
			visual:SetAttribute("_baseSize", visual.Size)
			baseSize = visual.Size
		end

		visual.Size = baseSize * multiplier
	end
end

local function placeVisualOnGround(visual: Instance, groundPosition: Vector3, facingDirection: Vector3, lift: number?)
	local ok, boxCFrame, boxSize

	if visual:IsA("Model") then
		ok, boxCFrame, boxSize = pcall(function()
			return visual:GetBoundingBox()
		end)
	elseif visual:IsA("BasePart") then
		ok, boxCFrame, boxSize = true, visual.CFrame, visual.Size
	end

	if not ok then
		return
	end

	local fd = flattenDirection(facingDirection)
	local centerPosition = Vector3.new(
		groundPosition.X,
		groundPosition.Y + boxSize.Y / 2 + (lift or 0),
		groundPosition.Z
	)

	local targetCFrame = CFrame.lookAt(centerPosition, centerPosition + fd)

	if visual:IsA("Model") then
		local pivotToBox = visual:GetPivot():ToObjectSpace(boxCFrame)
		visual:PivotTo(targetCFrame * pivotToBox:Inverse())
	else
		visual.CFrame = targetCFrame
	end
end

local function prepareRevealVisual(template: Instance)
	local visual = template:Clone()
	visual.Name = "LocalRewardRevealVisual"
	visual.Parent = workspace

	if visual:IsA("Model") then
		local ok, scale = pcall(function()
			return visual:GetScale()
		end)

		if ok then
			visual:SetAttribute("_baseScale", scale)
		end
	elseif visual:IsA("BasePart") then
		visual:SetAttribute("_baseSize", visual.Size)
	end

	anchorVisual(visual)

	return visual
end

local function getAnimator(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end

	animator = Instance.new("Animator")
	animator.Parent = humanoid

	return animator
end

local function findHitAnimation()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local hitLuckyBlockAssets = assets and assets:FindFirstChild("HitLuckyBlock")
	local animations = hitLuckyBlockAssets and hitLuckyBlockAssets:FindFirstChild("Animations")

	if not animations then
		return nil
	end

	for _, name in ipairs({ "HitAnim", "KickAnim", "SwingAnim", "BatHit", "Hit" }) do
		local animation = animations:FindFirstChild(name)
		if animation and animation:IsA("Animation") then
			return animation
		end
	end

	return nil
end

local function getControls(localPlayer: Player)
	local ok, controls = pcall(function()
		local playerScripts = localPlayer:WaitForChild("PlayerScripts")
		local playerModule = require(playerScripts:WaitForChild("PlayerModule"))
		return playerModule:GetControls()
	end)

	if ok then
		return controls
	end

	return nil
end

function HitLuckyBlockVisualController:Initialize()
	self.Player = Players.LocalPlayer
	self.Camera = workspace.CurrentCamera
	self.StartHitService = Framework:GetService("StartHitService")
	self.Controls = getControls(self.Player)

	self._sequenceId = nil
	self._cameraConnection = nil
	self._activeVisuals = {}
	self._cameraWasScriptable = false
end

function HitLuckyBlockVisualController:Start()
	-- Server events are attached by ClientLoader because this controller has a Server table.
end

function HitLuckyBlockVisualController:_setControlsEnabled(enabled: boolean)
	if not self.Controls then
		return
	end

	if enabled then
		self.Controls:Enable()
	else
		self.Controls:Disable()
	end
end

function HitLuckyBlockVisualController:_trackVisual(visual: Instance)
	table.insert(self._activeVisuals, visual)
end

function HitLuckyBlockVisualController:_clearVisuals()
	for _, visual in ipairs(self._activeVisuals) do
		if visual and visual.Parent then
			visual:Destroy()
		end
	end

	table.clear(self._activeVisuals)
end

function HitLuckyBlockVisualController:_disconnectCamera()
	if self._cameraConnection then
		self._cameraConnection:Disconnect()
		self._cameraConnection = nil
	end
end

function HitLuckyBlockVisualController:_setCameraFollow(getPosition, lookOffset: Vector3?)
	self:_disconnectCamera()

	local camera = workspace.CurrentCamera
	self.Camera = camera
	self._cameraWasScriptable = true
	camera.CameraType = Enum.CameraType.Scriptable

	self._cameraConnection = RunService.RenderStepped:Connect(function()
		local position = getPosition()

		if typeof(position) ~= "Vector3" then
			return
		end

		local direction = lookOffset or Vector3.new(0, 8, 18)
		local cameraPosition = position + direction

		camera.CFrame = CFrame.lookAt(cameraPosition, position)
	end)
end

function HitLuckyBlockVisualController:_releaseCamera()
	self:_disconnectCamera()

	local camera = workspace.CurrentCamera
	local character = self.Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		camera.CameraSubject = humanoid
	end

	camera.CameraType = Enum.CameraType.Custom
end

function HitLuckyBlockVisualController:_playHitAnimation()
	local character = self.Player.Character
	if not character then
		return
	end

	local animation = findHitAnimation()
	if not animation then
		return
	end

	local animator = getAnimator(character)
	if not animator then
		return
	end

	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	track:Play()

	task.delay(math.max(track.Length, 0.5) + 0.1, function()
		track:Destroy()
	end)
end

function HitLuckyBlockVisualController:_playLandingVFX(position: Vector3)
	local template = findVFXTemplate({ "LandingVFX", "OpeningVFX", "OBVFX" })
	if not template then
		return
	end

	local holder = makeHolder(position)
	local vfx = template:Clone()
	vfx.Parent = holder

	emitVFX(vfx)

	Debris:AddItem(holder, 3)
end

function HitLuckyBlockVisualController:_playOpeningVFX(position: Vector3)
	local template = findVFXTemplate({ "OpeningVFX" })
	if not template then
		return nil
	end

	local holder = makeHolder(position)
	local vfx = template:Clone()
	vfx.Parent = holder

	enableParticleVFX(vfx, true)
	emitVFX(vfx)

	Debris:AddItem(holder, 8)

	return holder, vfx
end

function HitLuckyBlockVisualController:_playOBVFX(position: Vector3)
	local template = findVFXTemplate({ "OBVFX", "OpeningBurstVFX", "RewardVFX" })
	if not template then
		return
	end

	local holder = makeHolder(position + Vector3.new(0, 1, 0))
	local vfx = template:Clone()
	vfx.Parent = holder

	emitVFX(vfx)

	Debris:AddItem(holder, 3)
end

function HitLuckyBlockVisualController:_spawnLocalTsunami(landingPosition: Vector3, flatDirection: Vector3)
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	local wavesFolder = vfxFolder and vfxFolder:FindFirstChild("TsunamiWaves")

	if not wavesFolder then
		return nil
	end

	local waves = wavesFolder:GetChildren()
	if #waves == 0 then
		return nil
	end

	local wave = waves[math.random(1, #waves)]:Clone()
	wave.Name = "LocalTsunamiWave"
	wave.Parent = workspace

	anchorVisual(wave)

	local waveRoot = nil
	if wave:IsA("Model") then
		waveRoot = wave:FindFirstChild("Root") or wave.PrimaryPart or wave:FindFirstChildWhichIsA("BasePart", true)
	elseif wave:IsA("BasePart") then
		waveRoot = wave
	end

	if not waveRoot or not waveRoot:IsA("BasePart") then
		wave:Destroy()
		return nil
	end

	local _, waveSize = if wave:IsA("Model")
		then wave:GetBoundingBox()
		else waveRoot.CFrame, waveRoot.Size

	local spawnPosition = landingPosition + (-flatDirection) * 18
	spawnPosition = Vector3.new(spawnPosition.X, landingPosition.Y - waveSize.Y - 4, spawnPosition.Z)

	pivotVisual(wave, CFrame.lookAt(spawnPosition, spawnPosition + flatDirection))

	local risePosition = Vector3.new(spawnPosition.X, landingPosition.Y, spawnPosition.Z)
	local moveTarget = landingPosition + flatDirection * 80

	TweenService:Create(
		waveRoot,
		TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			CFrame = CFrame.lookAt(risePosition, risePosition + flatDirection),
		}
	):Play()

	task.delay(2, function()
		if waveRoot and waveRoot.Parent then
			TweenService:Create(
				waveRoot,
				TweenInfo.new(6, Enum.EasingStyle.Linear),
				{
					CFrame = CFrame.lookAt(moveTarget, moveTarget + flatDirection),
				}
			):Play()
		end
	end)

	Debris:AddItem(wave, 12)
	self:_trackVisual(wave)

	return waveRoot
end

function HitLuckyBlockVisualController.Server:BeginHitSequence(data)
	if type(data) ~= "table" then
		return
	end

	if typeof(data.StartPosition) ~= "Vector3"
		or typeof(data.ControlPosition) ~= "Vector3"
		or typeof(data.TargetPosition) ~= "Vector3"
	then
		return
	end

	self._sequenceId = data.FlightId
	self:_clearVisuals()
	self:_setControlsEnabled(false)

	local flatDirection = flattenDirection(data.FlatDirection or (data.TargetPosition - data.StartPosition))
	local cameraOffset = -flatDirection * 20 + Vector3.new(0, 9, 0)

	local template = getLuckyBlockTemplate()
	local visual = if template then template:Clone() else createFallbackLuckyBlock()

	visual.Name = "LocalLuckyBlockHitVisual"
	visual.Parent = workspace

	anchorVisual(visual)
	pivotVisual(visual, CFrame.new(data.StartPosition))
	self:_trackVisual(visual)

	local currentPosition = data.StartPosition

	self:_setCameraFollow(function()
		return currentPosition
	end, cameraOffset)

	self:_playHitAnimation()

	task.wait(0.35)

	local duration = math.max(tonumber(data.Duration) or 0.85, 0.05)
	local spinSpeed = math.rad(tonumber(data.SpinSpeed) or 540)
	local startTime = os.clock()

	while visual.Parent and os.clock() - startTime < duration do
		local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
		currentPosition = sampleQuadraticBezier(
			data.StartPosition,
			data.ControlPosition,
			data.TargetPosition,
			alpha
		)

		local spin = spinSpeed * alpha

		pivotVisual(
			visual,
			CFrame.new(currentPosition) * CFrame.Angles(spin, spin * 0.65, spin * 0.35)
		)

		RunService.RenderStepped:Wait()
	end

	currentPosition = data.TargetPosition
	pivotVisual(visual, CFrame.new(data.TargetPosition))
	self:_playLandingVFX(data.TargetPosition)

	task.wait(0.2)

	if visual and visual.Parent then
		visual:Destroy()
	end

	self.StartHitService.Fire:BlockLanded(data.FlightId, data.TargetPosition, flatDirection)
end

function HitLuckyBlockVisualController.Server:BeginReveal(data)
	if type(data) ~= "table" then
		return
	end

	if data.FlightId ~= self._sequenceId then
		return
	end

	if typeof(data.GroundPosition) ~= "Vector3" or typeof(data.FlatDirection) ~= "Vector3" then
		return
	end

	local groundPosition = data.GroundPosition
	local flatDirection = flattenDirection(data.FlatDirection)

	self:_setCameraFollow(function()
		return groundPosition + Vector3.new(0, 4, 0)
	end, -flatDirection * 15 + Vector3.new(0, 7, 0))

	local openingHolder, openingVFX = self:_playOpeningVFX(groundPosition)

	task.wait(0.6)

	self:_setCameraFollow(function()
		return groundPosition + Vector3.new(0, 5, 0)
	end, -flatDirection * 12 + Vector3.new(0, 6, 0))

	task.wait(0.35)

	local candidates = if type(data.CandidateNames) == "table" then data.CandidateNames else {}
	local finalInfo = {
		Brainrot = data.FinalBrainrot,
		Mutation = data.FinalMutation,
	}

	if #candidates == 0 then
		table.insert(candidates, finalInfo)
	end

	local rollCount = math.max(tonumber(data.RollCount) or ROLL_COUNT, 1)
	local rollTime = math.max(tonumber(data.RollTime) or ROLL_TIME, 0.5)
	local rollSpeed = math.max(tonumber(data.RollSpeed) or ROLL_SPEED, 0.1)

	local activeVisual = nil

	for i = 1, rollCount do
		if activeVisual and activeVisual.Parent then
			activeVisual:Destroy()
			activeVisual = nil
		end

		local isFinal = i == rollCount
		local info = if isFinal then finalInfo else candidates[((i - 1) % #candidates) + 1]
		local template = getBrainrotTemplate(info.Brainrot, info.Mutation)

		if template then
			activeVisual = prepareRevealVisual(template)
			self:_trackVisual(activeVisual)

			if not isFinal then
				applySilhouette(activeVisual)
			end
		end

		local alpha = i / rollCount
		local baseStep = rollTime / math.max(rollCount - 1, 1)
		local stepDuration = if isFinal then 1 else math.clamp((baseStep * (0.6 + alpha * 0.8)) / rollSpeed, 0.04, 0.55)
		local stepStart = os.clock()

		while activeVisual and activeVisual.Parent and os.clock() - stepStart < stepDuration do
			local t = math.clamp((os.clock() - stepStart) / stepDuration, 0, 1)
			local popScale = 0.5 + 0.85 * math.sin(t * math.pi)
			local lift = math.sin(t * math.pi) * 0.5

			scaleVisual(activeVisual, popScale)
			placeVisualOnGround(activeVisual, groundPosition, flatDirection, lift)

			RunService.RenderStepped:Wait()
		end
	end

	if openingVFX and openingVFX.Parent then
		enableParticleVFX(openingVFX, false)
	end

	if openingHolder then
		Debris:AddItem(openingHolder, 2)
	end

	if activeVisual and activeVisual.Parent then
		scaleVisual(activeVisual, 1)
		placeVisualOnGround(activeVisual, groundPosition, flatDirection, 0)
	end

	self:_playOBVFX(groundPosition)

	local waveRoot = self:_spawnLocalTsunami(groundPosition, flatDirection)
	if waveRoot then
		self:_setCameraFollow(function()
			if waveRoot and waveRoot.Parent then
				return waveRoot.Position
			end

			return groundPosition
		end, -flatDirection * 22 + Vector3.new(0, 10, 0))

		task.wait(2.5)
	else
		task.wait(0.6)
	end

	if activeVisual and activeVisual.Parent then
		activeVisual:Destroy()
	end

	self.StartHitService.Fire:RevealFinished(data.FlightId)
end

function HitLuckyBlockVisualController.Server:BeginReturnRun(data)
	if type(data) ~= "table" then
		return
	end

	if data.FlightId ~= self._sequenceId then
		return
	end

	self:_releaseCamera()
	self:_setControlsEnabled(true)
end

function HitLuckyBlockVisualController.Server:SequenceComplete(data)
	if type(data) == "table" and data.FlightId ~= self._sequenceId then
		return
	end

	self:_releaseCamera()
	self:_setControlsEnabled(true)
	self:_clearVisuals()
	self._sequenceId = nil
end

function HitLuckyBlockVisualController.Server:SequenceFailed(data)
	if type(data) == "table" and self._sequenceId and data.FlightId and data.FlightId ~= self._sequenceId then
		return
	end

	self:_releaseCamera()
	self:_setControlsEnabled(true)
	self:_clearVisuals()
	self._sequenceId = nil
end

return HitLuckyBlockVisualController