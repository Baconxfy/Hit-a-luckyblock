--< Services
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--< Modules
local KickCalculator = require(ReplicatedStorage:WaitForChild("Framework"):WaitForChild("KickCalculator"))
local LuckyBlockFlight = require(ReplicatedStorage:WaitForChild("Framework"):WaitForChild("Modules"):WaitForChild("LuckyBlockFlight"))
local Blink = require(ReplicatedStorage:WaitForChild("Blink"):WaitForChild("Client"))
local GuiController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("GuiController"))
local PromiseFindFirstChild = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("PromiseFindFirstChild"))
local ZonePlus = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ZonePlus"))

--< Variables
local LocalPlayer = Players.LocalPlayer

--< Resources
local Assets = ReplicatedStorage:WaitForChild("Assets")
local HitLuckyBlockAssets = Assets.HitLuckyBlock

local AnimationsFolder = HitLuckyBlockAssets.Animations
local CarryAnim = AnimationsFolder.CarryAnim
local HoldAnim = AnimationsFolder.HoldAnim
local HitAnim = AnimationsFolder.HitAnim

local LuckyBlockTemplate = HitLuckyBlockAssets.LuckyBlock
local BaseballTemplate = HitLuckyBlockAssets.Baseball

-- VFX
local HitVFX = HitLuckyBlockAssets.HitVFX
local HitGroundAttach = HitLuckyBlockAssets.HitGroundAttach

--< Remote Events (created by HitLuckyBlock_Server on startup)
local CutsceneEvent = ReplicatedStorage:WaitForChild("CutsceneEvent", 30)
local BlockLandedEvent = ReplicatedStorage:WaitForChild("BlockLandedEvent", 30)

--< Workspace Variables
local ZonesFolder = workspace:WaitForChild("Zones")
local HitZonePart = ZonesFolder:WaitForChild("HitZone", 120)
local HitZone = ZonePlus.new(HitZonePart)

--< Gui Variables (resolved lazily inside Init to avoid timing issues)
local HitMinigameGUI = nil
local HitMinigameGUI_MainFrame = nil
local HitButton = nil

--< Variables
local CurrentCamera = workspace.CurrentCamera
local cache :{[Player]:{Track:AnimationTrack, LuckyBlock:BasePart, LuckyBlockMotor6D:Motor6D}} = {}

--< Constants
local CARRY_BLOCK_OFFSET = CFrame.new(1.08, -0.27, -0.02)

--< Helper Functions
local function EmitParticles(Parent:Instance, EmitCount:number?)
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

local function PlayGroundVFX(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local vfx = HitGroundAttach:Clone()
	vfx.Parent = anchor
	EmitParticles(vfx)

	Debris:AddItem(anchor, 3)
end

local function PlayBatTipVFX(bat: Model)
	local batMesh = bat:FindFirstChild("Baseball")
	local tip = batMesh and batMesh:FindFirstChild("1")
	if not tip then return end

	for _, child in ipairs(HitVFX:GetChildren()) do
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

local function MakeTransparency(Object:Instance, TransparencyValue:number)
	for _, v in pairs(Object:GetDescendants()) do
		if (v:IsA("BasePart") or v:IsA("MeshPart")) and v.Name ~= "Root" then
			v.Transparency = TransparencyValue
		end
	end
end

local function JointLuckyBlock(leftHand:BasePart) :(BasePart, Motor6D)
	local heldBlock = Instance.new("Part")
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

	local rootPart = heldBlock:FindFirstChild("Root")
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

local function WeldBat(rightHand:BasePart) :Model
	local bat = BaseballTemplate:Clone()
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

--< Camera Cutscene Handler
local function handleCutsceneEvent(eventType, data)
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

--< Main Functions

local function onPlayerEnteredZone(player:Player)
	if LocalPlayer == player then
		GuiController:LockGui(HitMinigameGUI)
		-- Use OpenMainFrame explicitly instead of Toggle so the frame
		-- always opens regardless of what state CurrentMainFrame is in.
		GuiController:OpenMainFrame(HitMinigameGUI_MainFrame)
		if HitButton then
			HitButton.Visible = true
		end
	end

	if cache[player] then return end
	cache[player] = {}

	local character = player.Character
	if not character then return end

	local humanoid: Humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator :Animator = humanoid:FindFirstChild("Animator")
	if not animator then return end

	local leftHand = character:FindFirstChild("LeftHand")
	if not leftHand then return end

	local luckyBlock, luckyBlockMotor6D = JointLuckyBlock(leftHand)
	luckyBlock.Parent = character

	cache[player].LuckyBlock = luckyBlock
	cache[player].LuckyBlockMotor6D = luckyBlockMotor6D

	local carryTrack :AnimationTrack = animator:LoadAnimation(CarryAnim)
	carryTrack.Priority = Enum.AnimationPriority.Action
	carryTrack.Looped = true
	carryTrack:Play()

	cache[player].Track = carryTrack
end

local function onPlayerExitedZone(player:Player)
	if LocalPlayer == player then
		GuiController:UnlockGui(HitMinigameGUI)
		GuiController:CloseMainFrame(HitMinigameGUI_MainFrame)
		if HitButton then
			HitButton.Visible = false
		end
	end

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

local function onInitHit(Info:{ Player:Player, Result:KickCalculator.KickResult })

	local Player = Info.Player
	local Result = Info.Result

	local Character = Player.Character
	if not Character then return end

	local rootPart :BasePart = Character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local humanoid :Humanoid = Character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator :Animator = humanoid:FindFirstChild("Animator")
	if not animator then return end

	local rightHand :BasePart = Character:FindFirstChild("RightHand")
	if not rightHand then return end

	local playerCache = cache[Player]
	cache[Player] = nil

	if not playerCache then return end

	local luckyBlock :BasePart = playerCache.LuckyBlock
	local luckyBlockMotor6D :Motor6D = playerCache.LuckyBlockMotor6D

	if playerCache.Track then
		playerCache.Track:Stop()
		playerCache.Track:Destroy()
	end

	local Bat = WeldBat(rightHand)
	Bat.Parent = Character

	local TrackList = {}
	for _,track:AnimationTrack in pairs(animator:GetPlayingAnimationTracks()) do
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

	local hitTrack :AnimationTrack = animator:LoadAnimation(HitAnim)
	hitTrack.Priority = Enum.AnimationPriority.Action

	hitTrack:GetMarkerReachedSignal("Hit"):Once(function(...)

		if isLocalPlayer then
			if CameraTween then CameraTween:Cancel() end
			CurrentCamera.CameraType = Enum.CameraType.Custom
			CurrentCamera.CameraSubject = luckyBlock
		end

		task.spawn(function()
			PlayBatTipVFX(Bat)

			local Highlight = Instance.new("Highlight")
			Highlight.FillTransparency = 0
			Highlight.OutlineTransparency = 1
			Highlight.FillColor = Color3.fromRGB(255, 255, 255)
			Highlight.Enabled = true
			Highlight.Parent = Character

			local HitVFXClone = HitVFX:Clone()
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
				PlayGroundVFX(pos)
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
					if BlockLandedEvent then
						BlockLandedEvent:FireServer(targetPos, flatDir)
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

local module = {}

function module.SetupHitZone() :{playerEntered:RBXScriptConnection, playerExited:RBXScriptConnection}
	return {
		playerEntered = HitZone.playerEntered:Connect(onPlayerEnteredZone),
		playerExited  = HitZone.playerExited:Connect(onPlayerExitedZone),
	}
end

function module.HitInfoEvent() :RBXScriptConnection
	return Blink.HitInfo.On(onInitHit)
end

function module:Init()
	-- Resolve GUI refs here after the framework has fully initialised,
	-- avoiding the race condition where module top-level code runs before
	-- GuiController:SetMainFrame has been called for HitMinigame.
	HitMinigameGUI = GuiController:GetGui("HitMinigame")
	HitMinigameGUI_MainFrame = HitMinigameGUI and (
		GuiController:GetMainFrame(HitMinigameGUI)
		or HitMinigameGUI:FindFirstChildOfClass("Frame")
	)
	HitButton = HitMinigameGUI_MainFrame and HitMinigameGUI_MainFrame:FindFirstChild("HitButton")

	self:HitInfoEvent()
	self:SetupHitZone()

	if CutsceneEvent then
		CutsceneEvent.OnClientEvent:Connect(handleCutsceneEvent)
	end
end

return module
