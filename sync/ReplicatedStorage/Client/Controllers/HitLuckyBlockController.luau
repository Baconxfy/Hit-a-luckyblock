local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local HitLuckyBlockController = Framework:CreateController("HitLuckyBlockController")

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local KickCalculator = Framework.Utils.KickCalculator
local LuckyBlockFlight = Framework.Utils.LuckyBlockFlight
local Blink = require(ReplicatedStorage:WaitForChild("Blink"):WaitForChild("Client"))
local GuiController = Framework.Utils.GuiController
local PromiseFindFirstChild = Framework.Utils.PromiseFindFirstChild
local ZonePlus = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ZonePlus"))

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera
local cache = {}

local CARRY_BLOCK_OFFSET = CFrame.new(1.08, -0.27, -0.02)

local function EmitParticles(Parent, EmitCount)
	EmitCount = EmitCount or 1
	local particles = {}
	for _,v in pairs(Parent:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			table.insert(particles, v)
		end
	end
	for _,v in pairs(particles) do
		v:Emit(v:GetAttribute("EmitCount") or EmitCount)
	end
end

local function MakeTransparency(Object, TransparencyValue)
	for _, v in pairs(Object:GetDescendants()) do
		if (v:IsA("BasePart") or v:IsA("MeshPart")) and v.Name ~= "Root" then
			v.Transparency = TransparencyValue
		end
	end
end

function HitLuckyBlockController:Initialize()
	self.Assets = ReplicatedStorage:WaitForChild("Assets")
	self.HitLuckyBlockAssets = self.Assets:WaitForChild("HitLuckyBlock")

	self.AnimationsFolder = self.HitLuckyBlockAssets:WaitForChild("Animations")
	self.CarryAnim = self.AnimationsFolder:WaitForChild("CarryAnim")
	self.HoldAnim = self.AnimationsFolder:WaitForChild("HoldAnim")
	self.HitAnim = self.AnimationsFolder:WaitForChild("HitAnim")

	self.LuckyBlockTemplate = self.HitLuckyBlockAssets:WaitForChild("LuckyBlock")
	self.BaseballTemplate = self.HitLuckyBlockAssets:WaitForChild("Baseball")

	self.HitVFX = self.HitLuckyBlockAssets:WaitForChild("HitVFX")
	self.HitGroundAttach = self.HitLuckyBlockAssets:WaitForChild("HitGroundAttach")

	self.CutsceneEvent = ReplicatedStorage:WaitForChild("CutsceneEvent", 30)
	self.BlockLandedEvent = ReplicatedStorage:WaitForChild("BlockLandedEvent", 30)

	self.ZonesFolder = workspace:WaitForChild("Zones")
	self.HitZonePart = self.ZonesFolder:WaitForChild("HitZone", 120)
	self.HitZone = ZonePlus.new(self.HitZonePart)
end

function HitLuckyBlockController:PlayGroundVFX(position)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local vfx = self.HitGroundAttach:Clone()
	vfx.Parent = anchor
	EmitParticles(vfx)

	Debris:AddItem(anchor, 3)
end

function HitLuckyBlockController:PlayBatTipVFX(bat)
	local batMesh = bat:FindFirstChild("Baseball")
	local tip = batMesh and batMesh:FindFirstChild("1")
	if not tip then return end

	for _, child in ipairs(self.HitVFX:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			local emitter = child:Clone()
			emitter.Enabled = false
			emitter.Parent = tip
			emitter:Emit(emitter:GetAttribute("EmitCount") or 15)
			Debris:AddItem(emitter, 2)
		end
	end

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 230, 80)
	light.Brightness = 15
	light.Range = 35
	light.Parent = tip
	TweenService:Create(light, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Brightness = 0,
		Range = 0,
	}):Play()
	Debris:AddItem(light, 0.5)
end

function HitLuckyBlockController:JointLuckyBlock(leftHand)
	local heldBlock = Instance.new("Part")
	heldBlock.Name = "LuckyBlock"
	heldBlock.Size = Vector3.new(1, 1, 1)
	heldBlock.Transparency = 1

	local template = self.LuckyBlockTemplate:Clone()
	template.Name = "HeldLuckyBlock"
	for _, child in ipairs(template:GetChildren()) do
		child.Parent = heldBlock
	end
	template:Destroy()

	local rootPart = heldBlock:FindFirstChild("Root")
	if not rootPart then
		heldBlock:Destroy()
		return nil
	end

	local rootMotor = Instance.new("Motor6D")
	rootMotor.Name = "RootR6D"
	rootMotor.Part0 = heldBlock
	rootMotor.Part1 = rootPart
	rootMotor.Parent = heldBlock

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

	rootPart = heldBlock:FindFirstChild("Root")
	if not rootPart then
		heldBlock:Destroy()
		return nil
	end

	local handMotor = Instance.new("Motor6D")
	handMotor.Name = "LuckyBlock"
	handMotor.Part0 = leftHand
	handMotor.Part1 = heldBlock
	handMotor.C0 = CARRY_BLOCK_OFFSET
	handMotor.Parent = leftHand

	MakeTransparency(heldBlock, 0)
	return heldBlock, handMotor
end

function HitLuckyBlockController:WeldBat(rightHand)
	local bat = self.BaseballTemplate:Clone()
	local handle = bat:FindFirstChild("Handle")
	for _, m in ipairs(handle:GetChildren()) do
		if m:IsA("Motor6D") and m.Name == "RightHand" then
			m:Destroy()
		end
	end
	handle.CFrame = rightHand.CFrame * CFrame.new(0, -0.15, 0)
	handle.Anchored = false
	handle.CanCollide = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rightHand
	weld.Part1 = handle
	weld.Parent = handle

	for _, v in ipairs(bat:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Transparency = if v.Name == "Handle" then 1 else 0
		end
	end

	return bat
end

function HitLuckyBlockController:HandleCutsceneEvent(eventType, data)
	if eventType == "FocusReward" then
		local pos = data
		CurrentCamera.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(CurrentCamera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(pos + Vector3.new(0, 25, 20), pos)
		}):Play()

	elseif eventType == "FocusOpening" then
		local pos = data
		TweenService:Create(CurrentCamera, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(pos + Vector3.new(10, 15, -12), pos)
		}):Play()

	elseif eventType == "FocusTsunami" then
		local waveRoot = data
		if waveRoot and waveRoot.Parent then
			CurrentCamera.CameraType = Enum.CameraType.Custom
			CurrentCamera.CameraSubject = waveRoot
		end

	elseif eventType == "Release" then
		local char = LocalPlayer.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			CurrentCamera.CameraType = Enum.CameraType.Custom
			CurrentCamera.CameraSubject = humanoid
		end
		local PlayerModule = GuiController:GetVariable("PlayerModule")
		if PlayerModule then
			pcall(function() PlayerModule:GetControls():Enable() end)
		end
	end
end

-- GUI show/hide is handled by HitGUIController via Touched/TouchEnded.
-- These functions only handle the carry animation and lucky block attachment.

function HitLuckyBlockController:OnPlayerEnteredZone(player)
	if cache[player] then return end
	cache[player] = {}

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChild("Animator")
	if not animator then return end

	local leftHand = character:FindFirstChild("LeftHand")
	if not leftHand then return end

	local luckyBlock, luckyBlockMotor6D = self:JointLuckyBlock(leftHand)
	luckyBlock.Parent = character

	cache[player].LuckyBlock = luckyBlock
	cache[player].LuckyBlockMotor6D = luckyBlockMotor6D

	local carryTrack = animator:LoadAnimation(self.CarryAnim)
	carryTrack.Priority = Enum.AnimationPriority.Action
	carryTrack.Looped = true
	carryTrack:Play()

	cache[player].Track = carryTrack
end

function HitLuckyBlockController:OnPlayerExitedZone(player)
	local playerCache = cache[player]
	cache[player] = nil

	if not playerCache then return end

	if playerCache.LuckyBlock then
		playerCache.LuckyBlock:Destroy()
	end

	if playerCache.LuckyBlockMotor6D then
		playerCache.LuckyBlockMotor6D:Destroy()
	end

	if playerCache.Track then
		playerCache.Track:Stop()
		playerCache.Track:Destroy()
	end
end

function HitLuckyBlockController:OnInitHit(Info)
	local Player = Info.Player
	local Result = Info.Result

	local Character = Player.Character
	if not Character then return end

	local rootPart = Character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local humanoid = Character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChild("Animator")
	if not animator then return end

	local rightHand = Character:FindFirstChild("RightHand")
	if not rightHand then return end

	local playerCache = cache[Player]
	cache[Player] = nil

	if not playerCache then return end

	local luckyBlock = playerCache.LuckyBlock
	local luckyBlockMotor6D = playerCache.LuckyBlockMotor6D

	if playerCache.Track then
		playerCache.Track:Stop()
		playerCache.Track:Destroy()
	end

	local Bat = self:WeldBat(rightHand)
	Bat.Parent = Character

	local TrackList = {}
	for _,track in pairs(animator:GetPlayingAnimationTracks()) do
		table.insert(TrackList, track)
		track:Stop()
	end

	local isLocalPlayer = Player == LocalPlayer
	local CameraTween

	if isLocalPlayer then
		CurrentCamera.CameraType = Enum.CameraType.Scriptable
		CurrentCamera.CFrame = rootPart.CFrame
		CurrentCamera.CFrame *= CFrame.new(12, 2.5, 10)
		CurrentCamera.CFrame *= CFrame.Angles(0, math.rad(50), 0)

		CameraTween = TweenService:Create(
			CurrentCamera,
			TweenInfo.new(3, Enum.EasingStyle.Linear),
			{ CFrame = CurrentCamera.CFrame * CFrame.new(0, 0, -2) }
		)
		CameraTween:Play()
	end

	local hitTrack = animator:LoadAnimation(self.HitAnim)
	hitTrack.Priority = Enum.AnimationPriority.Action

	hitTrack:GetMarkerReachedSignal("Hit"):Once(function(...)
		if isLocalPlayer then
			if CameraTween then CameraTween:Cancel() end
			CurrentCamera.CameraType = Enum.CameraType.Custom
			CurrentCamera.CameraSubject = luckyBlock
		end

		task.spawn(function()
			self:PlayBatTipVFX(Bat)

			local Highlight = Instance.new("Highlight")
			Highlight.FillTransparency = 0
			Highlight.OutlineTransparency = 1
			Highlight.FillColor = Color3.fromRGB(255, 255, 255)
			Highlight.Enabled = true
			Highlight.Parent = Character

			local HitVFXClone = self.HitVFX:Clone()
			HitVFXClone.Parent = luckyBlock
			EmitParticles(HitVFXClone)
			task.wait(0.1)
			Highlight:Destroy()
		end)

		task.delay(3, function()
			hitTrack:Stop()
			hitTrack:Destroy()
			Bat:Destroy()
			for _, track in pairs(TrackList) do
				track:Play()
			end
		end)

		luckyBlock.Anchored = true
		luckyBlock.CanCollide = false
		luckyBlockMotor6D:Destroy()
		LuckyBlockFlight.Launch(luckyBlock, Result.TargetCFrame, {
			Intensity = Result.Normalized,

			OnHit = function(pos, impactStrength)
				self:PlayGroundVFX(pos)
			end,

			OnComplete = function()
				if isLocalPlayer then
					rootPart.Anchored = false
					CurrentCamera.CameraType = Enum.CameraType.Custom
					CurrentCamera.CameraSubject = humanoid

					local startPos = rootPart.Position
					local targetPos = Result.TargetCFrame.Position
					local flatDir = Vector3.new(targetPos.X - startPos.X, 0, targetPos.Z - startPos.Z)
					if flatDir.Magnitude > 0.05 then flatDir = flatDir.Unit end
					if self.BlockLandedEvent then
						self.BlockLandedEvent:FireServer(targetPos, flatDir)
					end
				end

				if luckyBlock and luckyBlock.Parent then
					Debris:AddItem(luckyBlock, 0)
				end
			end,
		})

	end)

	hitTrack:Play()
end

function HitLuckyBlockController:Start()
	Blink.HitInfo.On(function(Info)
		self:OnInitHit(Info)
	end)

	-- localPlayerEntered/localPlayerExited for animation only (carry block, anim).
	-- GUI show/hide is handled separately by HitGUIController via Touched/TouchEnded.
	self.HitZone.localPlayerEntered:Connect(function()
		self:OnPlayerEnteredZone(LocalPlayer)
	end)
	self.HitZone.localPlayerExited:Connect(function()
		self:OnPlayerExitedZone(LocalPlayer)
	end)

	if self.CutsceneEvent then
		self.CutsceneEvent.OnClientEvent:Connect(function(e, d) self:HandleCutsceneEvent(e, d) end)
	end
end

return HitLuckyBlockController