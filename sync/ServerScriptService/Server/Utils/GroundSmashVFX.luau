-- GroundSmashVFX: crater ring chunks, stray debris, shockwave, glow burst and dust
-- Ported from reference game. Call GroundSmashVFX.Play(impactPosition, groundPart, player)

local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundSmashVFX = {}

-- Created lazily so the event doesn't need to exist at require-time
local function getCameraShakeEvent()
	return ReplicatedStorage:FindFirstChild("GroundSmashCameraEvent")
end

local DEFAULT_SETTINGS = {
	RingChunkCount             = 8,
	RingRadius                 = 4.15,
	RingRadiusJitter           = 0.18,
	RingChunkThickness         = NumberRange.new(0.65, 0.95),
	RingChunkRadialWidth       = NumberRange.new(1.65, 2.25),
	RingChunkTangentialLength  = NumberRange.new(4.8,  6.4),
	RingChunkRise              = NumberRange.new(0.18, 0.42),
	RingChunkTiltDegrees       = NumberRange.new(4,    8),

	StrayChunkCount            = 7,
	StrayInnerRadius           = 6.9,
	StrayOuterRadius           = 10.2,
	StrayChunkThickness        = NumberRange.new(0.65, 1.05),
	StrayChunkWidth            = NumberRange.new(2.5,  3.8),
	StrayChunkLength           = NumberRange.new(4.0,  6.4),
	StrayChunkRise             = NumberRange.new(0.04, 0.16),
	StrayChunkTiltDegrees      = NumberRange.new(5,    11),
	StrayLiftHeight            = NumberRange.new(1.6,  2.8),
	StraySlideOutDistance      = NumberRange.new(1.2,  2.7),
	StrayStartInwardOffset     = NumberRange.new(0.8,  1.8),
	StrayRiseTime              = NumberRange.new(0.12, 0.18),
	StrayFallTime              = NumberRange.new(0.16, 0.24),
	StraySlideTime             = NumberRange.new(0.2,  0.32),
	StrayPopDelay              = NumberRange.new(0,    0.045),
	StrayStartSink             = 0.45,

	ChunkLifetime              = 1.8,
	FadeTime                   = 0.55,

	ShockwaveSize              = 13,
	ShockwaveTime              = 0.32,
	GlowSize                   = 7,
	GlowTime                   = 0.24,

	CameraShakeRadius          = 120,
	CameraShakeDuration        = 0.28,
	CameraShakeMagnitude       = 0.45,
}

local function mergeSettings(overrides)
	local settings = table.clone(DEFAULT_SETTINGS)
	if overrides then
		for k, v in pairs(overrides) do settings[k] = v end
	end
	return settings
end

local function rr(range)
	if typeof(range) == "NumberRange" then
		return range.Min + math.random() * (range.Max - range.Min)
	end
	return range
end

local function getGroundStyle(groundPart)
	local style = {
		Color           = Color3.fromRGB(245, 221, 105),
		Material        = Enum.Material.Plastic,
		MaterialVariant = "",
		Transparency    = 0,
		TopSurface      = Enum.SurfaceType.Studs,
		BottomSurface   = Enum.SurfaceType.Smooth,
	}
	if groundPart and groundPart:IsA("BasePart") then
		style.Color           = groundPart.Color
		style.Material        = groundPart.Material
		style.MaterialVariant = groundPart.MaterialVariant
		style.Transparency    = math.clamp(groundPart.Transparency, 0, 0.25)
		style.TopSurface      = groundPart.TopSurface
		style.BottomSurface   = groundPart.BottomSurface
	end
	return style
end

local function applyGroundStyle(part, style)
	part.Color           = style.Color
	part.Material        = style.Material
	part.MaterialVariant = style.MaterialVariant
	part.Transparency    = style.Transparency
	part.TopSurface      = style.TopSurface
	part.BottomSurface   = style.BottomSurface
	part.LeftSurface     = Enum.SurfaceType.Smooth
	part.RightSurface    = Enum.SurfaceType.Smooth
	part.FrontSurface    = Enum.SurfaceType.Smooth
	part.BackSurface     = Enum.SurfaceType.Smooth
end

local function makePart(name, parent)
	local p = Instance.new("Part")
	p.Name       = name
	p.Anchored   = true
	p.CanCollide = false
	p.CanTouch   = false
	p.CanQuery   = false
	p.CastShadow = true
	p.Parent     = parent
	return p
end

local function fadeAndClean(part, holdTime, fadeTime)
	task.delay(holdTime, function()
		if not part or not part.Parent then return end
		local tween = TweenService:Create(
			part,
			TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ Transparency = 1, Size = Vector3.new(part.Size.X * 0.96, part.Size.Y * 0.7, part.Size.Z * 0.96) }
		)
		tween:Play()
	end)
	Debris:AddItem(part, holdTime + fadeTime + 0.15)
end

local function createRingChunk(folder, center, angle, style, settings)
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local tangent = Vector3.new(-outward.Z, 0, outward.X)
	local radius  = settings.RingRadius + math.random(-100, 100) / 100 * settings.RingRadiusJitter
	local rise    = rr(settings.RingChunkRise)
	local pos     = center + outward * radius + Vector3.new(0, rise, 0)

	local chunk = makePart("CraterRingChunk", folder)
	chunk.Size  = Vector3.new(rr(settings.RingChunkRadialWidth), rr(settings.RingChunkThickness), rr(settings.RingChunkTangentialLength))
	applyGroundStyle(chunk, style)

	local yawJitter   = math.rad(math.random(-5, 5))
	local outwardTilt = math.rad(rr(settings.RingChunkTiltDegrees))
	local unevenRoll  = math.rad(math.random(-4, 4))
	chunk.CFrame = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(outwardTilt, yawJitter, unevenRoll)

	fadeAndClean(chunk, settings.ChunkLifetime, settings.FadeTime)
end

local function createStrayChunk(folder, center, angle, style, settings)
	local outward          = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local tangent          = Vector3.new(-outward.Z, 0, outward.X)
	local radius           = settings.StrayInnerRadius + (settings.StrayOuterRadius - settings.StrayInnerRadius) * math.random()
	local sideOffset       = tangent * math.random(-90, 90) / 100
	local liftHeight       = rr(settings.StrayLiftHeight)
	local slideOutDistance = rr(settings.StraySlideOutDistance)
	local inwardOffset     = rr(settings.StrayStartInwardOffset)
	local settledRise      = rr(settings.StrayChunkRise)

	local chunk = makePart("CraterStrayChunk", folder)
	chunk.Size  = Vector3.new(rr(settings.StrayChunkWidth), rr(settings.StrayChunkThickness), rr(settings.StrayChunkLength))
	applyGroundStyle(chunk, style)

	local yawJitter    = math.rad(math.random(-10, 10))
	local radialTilt   = math.rad(rr(settings.StrayChunkTiltDegrees))
	local surfaceWobble = math.rad(math.random(-4, 4))
	local halfHeight   = chunk.Size.Y * 0.5
	local startRadius  = math.max(radius - inwardOffset, settings.StrayInnerRadius * 0.7)
	local finalRadius  = radius + slideOutDistance
	local baseY        = center.Y + halfHeight + settledRise

	local startPos = center + outward * startRadius + sideOffset + Vector3.new(0, -settings.StrayStartSink, 0)
	local apexPos  = Vector3.new(startPos.X, baseY + liftHeight, startPos.Z)
	local landPos  = center + outward * radius + sideOffset + Vector3.new(0, halfHeight + settledRise, 0)
	local finalPos = center + outward * finalRadius + sideOffset + Vector3.new(0, halfHeight + settledRise, 0)

	local rot         = CFrame.lookAt(Vector3.zero, tangent) * CFrame.Angles(surfaceWobble, yawJitter, radialTilt)
	local startCF     = CFrame.new(startPos) * rot
	local apexCF      = CFrame.new(apexPos)  * rot
	local landCF      = CFrame.new(landPos)  * rot
	local finalCF     = CFrame.new(finalPos) * rot

	chunk.CFrame = startCF

	task.delay(rr(settings.StrayPopDelay), function()
		if not chunk or not chunk.Parent then return end
		local rise = TweenService:Create(chunk, TweenInfo.new(rr(settings.StrayRiseTime), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = apexCF })
		rise:Play()
		rise.Completed:Once(function()
			if not chunk or not chunk.Parent then return end
			local fall = TweenService:Create(chunk, TweenInfo.new(rr(settings.StrayFallTime), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = landCF })
			fall:Play()
			fall.Completed:Once(function()
				if not chunk or not chunk.Parent then return end
				TweenService:Create(chunk, TweenInfo.new(rr(settings.StraySlideTime), Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = finalCF }):Play()
			end)
		end)
	end)

	fadeAndClean(chunk, settings.ChunkLifetime, settings.FadeTime)
end

local function createShockwave(folder, center, settings)
	local s = makePart("ShockwaveRing", folder)
	s.Shape        = Enum.PartType.Cylinder
	s.Material     = Enum.Material.Neon
	s.Color        = Color3.fromRGB(255, 153, 55)
	s.Transparency = 0.45
	s.CastShadow   = false
	s.Size         = Vector3.new(0.08, 1.4, 1.4)
	s.CFrame       = CFrame.new(center + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	TweenService:Create(s, TweenInfo.new(settings.ShockwaveTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.08, settings.ShockwaveSize, settings.ShockwaveSize), Transparency = 1
	}):Play()
	Debris:AddItem(s, settings.ShockwaveTime + 0.1)
end

local function createGlowBurst(folder, center, settings)
	local g = makePart("ImpactGlow", folder)
	g.Shape        = Enum.PartType.Ball
	g.Material     = Enum.Material.Neon
	g.Color        = Color3.fromRGB(255, 110, 35)
	g.Transparency = 0.25
	g.CastShadow   = false
	g.Size         = Vector3.new(1, 1, 1)
	g.CFrame       = CFrame.new(center + Vector3.new(0, 0.55, 0))

	local light = Instance.new("PointLight")
	light.Color      = g.Color
	light.Brightness = 4
	light.Range      = 15
	light.Shadows    = false
	light.Parent     = g

	TweenService:Create(g, TweenInfo.new(settings.GlowTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(settings.GlowSize, settings.GlowSize * 0.55, settings.GlowSize), Transparency = 1
	}):Play()
	TweenService:Create(light, TweenInfo.new(settings.GlowTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0, Range = 0
	}):Play()
	Debris:AddItem(g, settings.GlowTime + 0.1)
end

local function createDust(folder, center)
	local anchor = makePart("ImpactDustAnchor", folder)
	anchor.Transparency = 1
	anchor.CastShadow   = false
	anchor.Size         = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame       = CFrame.new(center + Vector3.new(0, 0.15, 0))

	local att  = Instance.new("Attachment")
	att.Parent = anchor

	local dust = Instance.new("ParticleEmitter")
	dust.Name         = "DustBurst"
	dust.Enabled      = false
	dust.Texture      = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color        = ColorSequence.new(Color3.fromRGB(255, 203, 97), Color3.fromRGB(168, 117, 66))
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.2),
		NumberSequenceKeypoint.new(0.6, 0.5),
		NumberSequenceKeypoint.new(1,   1),
	})
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,    1.5),
		NumberSequenceKeypoint.new(0.35, 5.5),
		NumberSequenceKeypoint.new(1,    7),
	})
	dust.Lifetime    = NumberRange.new(0.35, 0.65)
	dust.Speed       = NumberRange.new(7, 16)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Acceleration = Vector3.new(0, 8, 0)
	dust.Drag        = 8
	dust.Rate        = 0
	dust.LightEmission = 0.2
	dust.Parent      = att
	dust:Emit(28)

	Debris:AddItem(anchor, 1)
end

function GroundSmashVFX.Play(impactPosition, groundPart, player, overrides)
	local settings    = mergeSettings(overrides)
	local style       = getGroundStyle(groundPart)
	local center      = Vector3.new(impactPosition.X, impactPosition.Y, impactPosition.Z)

	local folder      = Instance.new("Folder")
	folder.Name       = "GroundSmashVFX"
	folder.Parent     = workspace
	Debris:AddItem(folder, settings.ChunkLifetime + settings.FadeTime + 0.5)

	local angleOffset = math.random() * math.pi * 2
	for i = 1, settings.RingChunkCount do
		local angle = angleOffset + (i / settings.RingChunkCount) * math.pi * 2 + math.rad(math.random(-3, 3))
		createRingChunk(folder, center, angle, style, settings)
	end
	for i = 1, settings.StrayChunkCount do
		local angle = angleOffset + (i / settings.StrayChunkCount) * math.pi * 2 + math.rad(math.random(-16, 16))
		createStrayChunk(folder, center, angle, style, settings)
	end

	createShockwave(folder, center, settings)
	createGlowBurst(folder, center, settings)
	createDust(folder, center)

	if player then
		local ev = getCameraShakeEvent()
		if ev then
			ev:FireClient(player, center, settings.CameraShakeMagnitude, settings.CameraShakeDuration, settings.CameraShakeRadius)
		end
	end
end

return GroundSmashVFX
