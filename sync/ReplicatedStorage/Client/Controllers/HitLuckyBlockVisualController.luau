local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local HitLuckyBlockVisualController = Framework:CreateController("HitLuckyBlockVisualController")

HitLuckyBlockVisualController.Server = {}

local function pivotVisual(visual, cframe)
	if visual:IsA("Model") then
		visual:PivotTo(cframe)
	elseif visual:IsA("BasePart") then
		visual.CFrame = cframe
	end
end

local function anchorVisual(visual)
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

local function getTemplate(brainrotName, mutationName)
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

local function sampleQuadraticBezier(startPosition, controlPosition, targetPosition, alpha)
	local a = startPosition:Lerp(controlPosition, alpha)
	local b = controlPosition:Lerp(targetPosition, alpha)

	return a:Lerp(b, alpha)
end

local function applySilhouette(visual)
	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("SurfaceAppearance") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant:Destroy()
		elseif descendant:IsA("SpecialMesh") then
			descendant.TextureId = ""
		elseif descendant:IsA("BasePart") and descendant.Transparency < 1 then
			descendant.Color = Color3.new(0, 0, 0)
			descendant.Material = Enum.Material.SmoothPlastic
			descendant.Reflectance = 0

			if descendant:IsA("MeshPart") then
				descendant.TextureID = ""
			end
		end
	end
end

local function scaleVisual(visual, multiplier)
	if visual:IsA("Model") then
		local baseScale = visual:GetAttribute("_baseScale") or 1
		pcall(function()
			visual:ScaleTo(baseScale * multiplier)
		end)
	end
end

local function placeVisualOnGround(visual, groundPosition, facingDirection, lift)
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

	local flatDirection = Vector3.new(facingDirection.X, 0, facingDirection.Z)

	if flatDirection.Magnitude < 0.05 then
		flatDirection = Vector3.new(0, 0, -1)
	else
		flatDirection = flatDirection.Unit
	end

	local centerPosition = Vector3.new(
		groundPosition.X,
		groundPosition.Y + boxSize.Y / 2 + (lift or 0),
		groundPosition.Z
	)
	local targetCFrame = CFrame.lookAt(centerPosition, centerPosition + flatDirection)

	if visual:IsA("Model") then
		local pivotToBox = visual:GetPivot():ToObjectSpace(boxCFrame)
		visual:PivotTo(targetCFrame * pivotToBox:Inverse())
	else
		visual.CFrame = targetCFrame
	end
end

local function prepareRevealVisual(template)
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
	end

	anchorVisual(visual)

	return visual
end

function HitLuckyBlockVisualController:_playRewardReveal(data)
	if type(data) ~= "table" then
		return
	end

	if typeof(data.GroundPosition) ~= "Vector3" or typeof(data.Direction) ~= "Vector3" then
		return
	end

	local candidates = if type(data.CandidateNames) == "table" then data.CandidateNames else {}
	local finalInfo = {
		Brainrot = data.FinalBrainrot,
		Mutation = data.FinalMutation,
	}

	if #candidates == 0 then
		table.insert(candidates, finalInfo)
	end

	local duration = math.max(tonumber(data.Duration) or 2.6, 0.5)
	local rollCount = math.max(#candidates, 1)
	local activeVisual = nil

	for index = 1, rollCount do
		if activeVisual then
			activeVisual:Destroy()
			activeVisual = nil
		end

		local isFinal = index == rollCount
		local info = if isFinal then finalInfo else candidates[index]
		local template = getTemplate(info.Brainrot, info.Mutation)

		if template then
			activeVisual = prepareRevealVisual(template)

			if not isFinal then
				applySilhouette(activeVisual)
			end
		end

		local stepDuration = if isFinal then 0.8 else duration / rollCount
		local stepStart = os.clock()

		while activeVisual and activeVisual.Parent and os.clock() - stepStart < stepDuration do
			local alpha = math.clamp((os.clock() - stepStart) / stepDuration, 0, 1)
			local popScale = 0.5 + 0.85 * math.sin(alpha * math.pi)
			local lift = math.sin(alpha * math.pi) * 0.5

			scaleVisual(activeVisual, popScale)
			placeVisualOnGround(activeVisual, data.GroundPosition, data.Direction, lift)
			RunService.Heartbeat:Wait()
		end
	end

	if activeVisual then
		activeVisual:Destroy()
	end
end

function HitLuckyBlockVisualController:Start()
	task.spawn(function()
		local cutsceneEvent = ReplicatedStorage:FindFirstChild("CutsceneEvent") or ReplicatedStorage:WaitForChild("CutsceneEvent", 30)

		if not cutsceneEvent then
			return
		end

		cutsceneEvent.OnClientEvent:Connect(function(eventType, data)
			if eventType == "RewardReveal" then
				task.spawn(function()
					self:_playRewardReveal(data)
				end)
			end
		end)
	end)
end

function HitLuckyBlockVisualController.Server:PlayFlight(data)
	if type(data) ~= "table" then
		return
	end

	if typeof(data.StartPosition) ~= "Vector3"
		or typeof(data.ControlPosition) ~= "Vector3"
		or typeof(data.TargetPosition) ~= "Vector3"
	then
		return
	end

	local template = getTemplate(data.Brainrot, data.Mutation)

	if not template then
		warn("[HitLuckyBlockVisualController] Missing visual template:", data.Brainrot, data.Mutation)
		return
	end

	local visual = template:Clone()
	visual.Name = `{data.Brainrot}_{data.Mutation}_LocalHitVisual`
	visual.Parent = workspace

	anchorVisual(visual)
	pivotVisual(visual, CFrame.new(data.StartPosition))

	local duration = math.max(tonumber(data.Duration) or 0.85, 0.05)
	local spinSpeed = math.rad(tonumber(data.SpinSpeed) or 540)
	local startTime = os.clock()

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not visual.Parent then
			connection:Disconnect()
			return
		end

		local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
		local position = sampleQuadraticBezier(
			data.StartPosition,
			data.ControlPosition,
			data.TargetPosition,
			alpha
		)

		local spin = spinSpeed * alpha
		pivotVisual(visual, CFrame.new(position) * CFrame.Angles(spin, spin * 0.65, spin * 0.35))

		if alpha >= 1 then
			connection:Disconnect()
			pivotVisual(visual, CFrame.new(data.TargetPosition))
		end
	end)

	Debris:AddItem(visual, tonumber(data.VisualLifetime) or 5)
end

return HitLuckyBlockVisualController
