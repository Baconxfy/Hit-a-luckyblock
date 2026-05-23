-- TsunamiWaveVFX
-- Full implementation. Picks a random wave from RS.VFX.TsunamiWaves,
-- spawns it underground, rises it up, then chases the player toward the safe zone.

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TsunamiWaveVFX = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function getWaveTemplate()
	local vfx = ReplicatedStorage:FindFirstChild("VFX")
	local wavesFolder = vfx and vfx:FindFirstChild("TsunamiWaves")
	if not wavesFolder then return nil end
	local children = wavesFolder:GetChildren()
	if #children == 0 then return nil end
	return children[math.random(1, #children)]
end

local function getWaveRoot(wave)
	if wave:IsA("BasePart") then return wave end
	if wave:IsA("Model") then
		return wave:FindFirstChild("Root")
			or wave.PrimaryPart
			or wave:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- Move all parts of the wave to a new CFrame (handles both Model and BasePart).
-- Uses PivotTo for Models (all parts move together regardless of weld/anchor state).
local function pivotWave(wave, newCFrame)
	if wave:IsA("Model") then
		wave:PivotTo(newCFrame)
	elseif wave:IsA("BasePart") then
		wave.CFrame = newCFrame
	end
end

local function getCurrentPivot(wave, waveRoot)
	if wave:IsA("Model") then
		return wave:GetPivot()
	else
		return waveRoot.CFrame
	end
end

-- Linearly interpolate between two CFrames
local function lerpCFrame(a, b, t)
	return a:Lerp(b, t)
end

-- ── Main Spawn ────────────────────────────────────────────────────────────────

function TsunamiWaveVFX.Spawn(config)
	local template = getWaveTemplate()
	if not template then
		warn("[TsunamiWaveVFX] No wave templates found in ReplicatedStorage.VFX.TsunamiWaves")
		return nil
	end

	local wave = template:Clone()
	wave.Parent = workspace

	local waveRoot = getWaveRoot(wave)
	if not waveRoot then
		wave:Destroy()
		warn("[TsunamiWaveVFX] Wave template has no root part")
		return nil
	end

	-- Anchor and make non-collidable so it slides through the world visually
	for _, p in ipairs(wave:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = true
			p.CanQuery = false
			p.CastShadow = false
		elseif p:IsA("BillboardGui") then
			p.Enabled = false -- hide debug text baked into wave templates
		end
	end
	if waveRoot:IsA("BasePart") then
		waveRoot.Anchored = true
		waveRoot.CanCollide = false
		waveRoot.CanTouch = true
	end

	-- Config values
	local spawnCFrame     = config.SpawnCFrame or CFrame.new(0, 0, 0)
	local moveDir         = config.MoveDirection and config.MoveDirection.Unit or Vector3.new(1, 0, 0)
	local moveSpeed       = config.MoveSpeed or 16
	local riseDuration    = config.RiseDuration or 1.8
	local moveStartDelay  = config.MoveStartDelay or (riseDuration + 1)
	local lifetime        = config.Lifetime or 120
	local targetPos       = config.TargetPosition
	local targetChar      = config.TargetCharacter
	local targetPlayer    = config.TargetPlayer
	local safePart        = config.SafePart
	local destroyOnHit    = config.DestroyOnPlayerHit ~= false
	local destroyOnSafe   = config.DestroyOnSafeReached ~= false
	local damageEnabled   = config.DamageEnabled ~= false
	local damageAmount    = config.DamageAmount or 1000000

	-- Measure wave height so we know how far underground to start
	local waveHeight = 20
	if wave:IsA("Model") then
		local ok, _, sz = pcall(function() return wave:GetBoundingBox() end)
		if ok and sz then waveHeight = sz.Y end
	elseif waveRoot:IsA("BasePart") then
		waveHeight = waveRoot.Size.Y
	end
	local underDepth = (config.UndergroundDepth or (waveHeight + 6))

	-- Place underground at spawn position
	local underCFrame = spawnCFrame * CFrame.new(0, -underDepth, 0)
	pivotWave(wave, underCFrame)

	-- ── Phase 1: Rise ────────────────────────────────────────────────────────
	local riseConn
	local riseStart = tick()
	riseConn = RunService.Heartbeat:Connect(function()
		if not wave or not wave.Parent then
			riseConn:Disconnect()
			return
		end
		local t = math.clamp((tick() - riseStart) / riseDuration, 0, 1)
		local eased = 1 - (1 - t) ^ 2 -- ease out quad
		pivotWave(wave, lerpCFrame(underCFrame, spawnCFrame, eased))
		if t >= 1 then
			riseConn:Disconnect()
		end
	end)

	-- ── Phase 2: Move (after delay) ──────────────────────────────────────────
	local destroyed = false
	local function destroyWave()
		if destroyed then return end
		destroyed = true
		if wave and wave.Parent then
			Debris:AddItem(wave, 0.1)
		end
	end

	-- Touch detection — fires when wave hits the target player
	local hitPlayer = false
	local touchConn
	touchConn = waveRoot.Touched:Connect(function(hit)
		if hitPlayer or destroyed then return end
		if not targetChar then return end
		if not hit:IsDescendantOf(targetChar) then return end
		hitPlayer = true
		touchConn:Disconnect()

		if damageEnabled and targetPlayer then
			local char = targetPlayer.Character
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(damageAmount)
			end
		end

		if destroyOnHit then
			task.delay(0.3, destroyWave)
		end
	end)

	task.delay(moveStartDelay, function()
		if destroyed or not wave or not wave.Parent then return end

		local moveStart = tick()
		local startPos = getCurrentPivot(wave, waveRoot).Position
		local moveConn
		moveConn = RunService.Heartbeat:Connect(function()
			if destroyed or not wave or not wave.Parent then
				moveConn:Disconnect()
				return
			end

			local elapsed = tick() - moveStart
			local newPos = startPos + moveDir * moveSpeed * elapsed
			local newCFrame = CFrame.lookAt(newPos, newPos + moveDir)
			pivotWave(wave, newCFrame)

			-- Check if passed the target position
			if targetPos then
				local travelVec = newPos - startPos
				local targetVec = targetPos - startPos
				if travelVec:Dot(moveDir) >= targetVec:Dot(moveDir) then
					moveConn:Disconnect()
					if destroyOnSafe then destroyWave() end
					return
				end
			end

			-- Check if wave entered the safe zone
			if safePart and safePart:IsA("BasePart") then
				local localPos = safePart.CFrame:PointToObjectSpace(newPos)
				local half = safePart.Size * 0.5
				if math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z then
					moveConn:Disconnect()
					if destroyOnSafe then destroyWave() end
					return
				end
			end
		end)

		-- Clean up after lifetime expires
		task.delay(lifetime, function()
			moveConn:Disconnect()
			destroyWave()
		end)
	end)

	-- Safety cleanup in case something goes wrong
	task.delay(moveStartDelay + lifetime + 5, function()
		if touchConn then pcall(function() touchConn:Disconnect() end) end
		destroyWave()
	end)

	return waveRoot
end

return TsunamiWaveVFX