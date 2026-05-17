--!strict
-- LuckyBlockFlight (ModuleScript)
-- ReplicatedStorage.Shared.Utils.LuckyBlockFlight
--
-- Animates a BasePart from a start point to a target with a focus on a
-- REALISTIC feel across all three phases:
--
--   LAUNCH  - leaves fast (the kick), horizontal speed bleeds off via "drag".
--   AIR     - vertical motion is a real gravity parabola: it rises slowing
--             down, then FALLS ACCELERATING. A symmetric Bezier looks floaty;
--             real projectiles fall faster than they rise visually. Spin also
--             speeds up slightly on the way down.
--   IMPACT  - a quick, small, snappy bounce + a short high-frequency shake
--             that decays fast. Reads as "it hit HARD" without being silly.
--             OnHit fires with the landing position AND an impact strength
--             (0..1) so you can scale your ground-rock effects to the kick.
--
-- All of this is one connection; everything is computed up front. Frame-rate
-- independent (uses dt). Designed for RunService.Heartbeat.

local RunService = game:GetService("RunService")

local LuckyBlockFlight = {}

-- =========================================================================
-- CONFIG
-- =========================================================================
local CONFIG = {
	-- ---- ARC SHAPE ----------------------------------------------------
	-- Peak height of the arc as a fraction of flat distance. A longer kick
	-- gets a proportionally taller arc, which (via the physics below) also
	-- means a proportionally longer time in the air — that's what sells it.
	ARC_HEIGHT_FRACTION = 0.4,
	ARC_HEIGHT_MIN      = 25,
	ARC_HEIGHT_MAX      = 600,  -- raised: a 1448-stud kick needs a big arc

	-- ---- TIMING (physics-based, NOT a hand-tuned formula) -------------
	-- The flight time is derived from real projectile motion:
	--   * A taller arc => longer hang time:  t_arc = 2 * sqrt(2 * h / g)
	--   * But also capped so the block never exceeds a believable horizontal
	--     speed (otherwise a 1448-stud kick would look like a teleport).
	-- GRAVITY here is just a tuning knob for hang time, not Roblox gravity.
	-- Lower = floatier / longer airtime. Higher = snappier.
	FLIGHT_GRAVITY      = 95,   -- studs/s^2, tuning knob for hang time (lower = slower)
	-- Hard cap on horizontal speed. Distance / this = minimum sane duration.
	MAX_HORIZONTAL_SPEED = 200, -- studs per second (lower = slower long kicks)
	-- Absolute floor so even a tiny kick has a readable little arc.
	MIN_DURATION        = 0.8,  -- seconds
	-- Absolute ceiling so a max-range kick doesn't drag forever.
	MAX_DURATION        = 8.0,  -- seconds

	-- Fraction of the flight (at the END) over which the spin winds down to
	-- zero, so the block lands NOT rotating. 0.25 = last quarter of the flight
	-- is used to smoothly stop the tumble. Set to 0 to keep spinning to impact.
	SPIN_SETTLE_FRACTION = 0.28,

	-- Where in the flight the apex happens (0..1). <0.5 means it reaches the
	-- top quickly then spends longer falling -> reads as gravity pulling down.
	APEX_TIME_FRACTION = 0.42,

	-- ---- HORIZONTAL "DRAG" --------------------------------------------
	-- Horizontal progress easing exponent. >1 = leaves fast then slows down,
	-- like a kicked object losing momentum. 1 = constant speed.
	HORIZONTAL_DRAG_EXP = 1.6,

	-- ---- SPIN ---------------------------------------------------------
	-- Base spin on the block's own axes (radians/second) during the rise.
	SPIN_X = 9,
	SPIN_Y = 3,
	SPIN_Z = 7,
	-- Spin multiplier reached at the moment of impact (tumbles faster falling).
	SPIN_FALL_BOOST = 1.6,

	-- ---- IMPACT BOUNCE ------------------------------------------------
	-- One quick, small bounce after touchdown. Small height, short time.
	BOUNCE_HEIGHT_STUDS = 4.5,  -- how high the little bounce goes
	BOUNCE_DURATION     = 0.16, -- seconds for the bounce up-and-down

	-- ---- IMPACT SHAKE -------------------------------------------------
	-- High-frequency positional jitter that decays fast. "Strong but brief."
	SHAKE_DURATION   = 0.32, -- total seconds the shake lasts
	SHAKE_AMPLITUDE  = 0.9,  -- max offset in studs (kept small on purpose)
	SHAKE_FREQUENCY  = 38,   -- oscillations per second (high = sharp buzz)
	SHAKE_VERTICAL_FACTOR = 0.45, -- vertical shake is a fraction of horizontal

	-- The block lands UPRIGHT — no leftover tumble. The spin winds down over
	-- SPIN_SETTLE_FRACTION of the flight and the final orientation snaps clean
	-- to TargetCFrame. (Set true only if you want it to keep its tumble.)
	KEEP_SPIN_ORIENTATION_ON_LAND = false,
}

-- =========================================================================
-- HELPERS
-- =========================================================================

local function clamp(n: number, lo: number, hi: number): number
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Vertical height of the arc at horizontal progress h (0..1).
-- Built as TWO parabola halves joined at the apex, with the apex placed at
-- APEX_TIME_FRACTION. The falling half is steeper -> looks like gravity.
local function arcHeightAt(h: number, peak: number, apex: number): number
	if h <= apex then
		-- Rising half: 0 -> peak as h goes 0 -> apex
		local k = h / apex
		-- ease-out-ish rise (slows as it approaches the top)
		return peak * (1 - (1 - k) * (1 - k))
	else
		-- Falling half: peak -> 0 as h goes apex -> 1
		local k = (h - apex) / (1 - apex)
		-- ease-in fall (accelerates downward) -> quadratic
		return peak * (1 - k * k)
	end
end

-- =========================================================================
-- API
-- =========================================================================

export type FlightOptions = {
	Duration   : number?,
	ArcHeight  : number?,
	-- Optional 0..1 from KickCalculator (result.Normalized). Used to scale
	-- the impact intensity. Defaults to 1 (full strength) if not provided.
	Intensity  : number?,
	OnComplete : (() -> ())?,
	-- Fires the instant the block touches down, BEFORE the bounce/shake.
	-- impactStrength is 0..1 — hook your ground-rock effects to this.
	OnHit      : ((position: Vector3, impactStrength: number) -> ())?,
}

--[[
	Launches the block from its current position toward targetCFrame.

	@param block        BasePart - the LuckyBlock (must be Anchored = true)
	@param targetCFrame CFrame   - landing CFrame from KickCalculator
	@param options      table?   - optional, see FlightOptions

	@return RBXScriptConnection
]]
function LuckyBlockFlight.Launch(
	block: BasePart,
	targetCFrame: CFrame,
	options: FlightOptions?
): RBXScriptConnection
	options = options or {}

	assert(block.Anchored, "The LuckyBlock must be Anchored = true during the flight")

	local startPos = block.Position
	local endPos   = targetCFrame.Position

	-- Flat (horizontal) distance drives arc height and duration.
	local startFlat = Vector3.new(startPos.X, 0, startPos.Z)
	local endFlat   = Vector3.new(endPos.X, 0, endPos.Z)
	local flatDist  = (endFlat - startFlat).Magnitude

	-- Arc height: proportional to distance. A long kick gets a tall arc, which
	-- (via the hang-time physics below) also means more time in the air.
	local arcHeight = options.ArcHeight or clamp(
		flatDist * CONFIG.ARC_HEIGHT_FRACTION,
		CONFIG.ARC_HEIGHT_MIN,
		CONFIG.ARC_HEIGHT_MAX
	)

	-- ---------------------------------------------------------------------
	-- FLIGHT DURATION — derived from projectile physics, not a guessed formula.
	-- Two independent constraints, we take whichever is LONGER:
	--
	--  (a) Hang time from the arc height. For a projectile, the time to go up
	--      to height h and come back down is t = 2 * sqrt(2h/g). A taller arc
	--      genuinely takes longer — this is what makes big kicks feel weighty.
	--
	--  (b) A horizontal speed cap. distance / MAX_HORIZONTAL_SPEED is the
	--      fastest a kick is allowed to cross its distance. Without this, a
	--      1448-stud kick with a modest arc would still cross in ~1s and look
	--      like a teleport.
	--
	-- Taking the max of the two means: short kicks are paced by their arc,
	-- long kicks are paced by the speed cap — and both look believable.
	-- Finally clamp to [MIN_DURATION, MAX_DURATION] as sanity rails.
	-- ---------------------------------------------------------------------
	local hangTime  = 2 * math.sqrt(2 * arcHeight / CONFIG.FLIGHT_GRAVITY)
	local speedTime = flatDist / CONFIG.MAX_HORIZONTAL_SPEED
	local flightDuration = options.Duration
		or clamp(math.max(hangTime, speedTime), CONFIG.MIN_DURATION, CONFIG.MAX_DURATION)

	-- Impact strength: how "hard" the landing reads. Scales the bounce + shake.
	local intensity = clamp(options.Intensity or 1, 0, 1)

	-- Horizontal axis for the shake (perpendicular-agnostic; we just need any
	-- stable basis). Forward = flight direction, side = forward rotated 90 deg.
	local forwardDir: Vector3
	if flatDist > 0.001 then
		forwardDir = (endFlat - startFlat).Unit
	else
		forwardDir = Vector3.new(0, 0, 1)
	end
	local sideDir = Vector3.new(-forwardDir.Z, 0, forwardDir.X)

	-- Spin state: starts from current orientation, accumulates over time.
	local currentSpin = block.CFrame - block.Position

	-- The upright orientation the block must settle into on landing. Position
	-- is stripped out — this is rotation only.
	local uprightOrientation = targetCFrame - targetCFrame.Position

	-- Phase machine: "flight" -> "bounce" -> "shake" -> done.
	local phase = "flight"
	local elapsed = 0          -- time within the current phase
	local landedOrientation: CFrame? = nil

	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt

		-- =================================================================
		-- PHASE 1: FLIGHT
		-- =================================================================
		if phase == "flight" then
			local t = clamp(elapsed / flightDuration, 0, 1)

			-- Horizontal progress with drag: leaves fast, slows down.
			-- h = 1 - (1 - t)^DRAG_EXP gives an ease-out curve.
			local h = 1 - (1 - t) ^ CONFIG.HORIZONTAL_DRAG_EXP

			-- Horizontal position: straight line from start to end, eased by h.
			local flatPos = startFlat:Lerp(endFlat, h)

			-- Vertical position: ground line interpolated by h, plus the
			-- asymmetric arc (rises slow, falls accelerating).
			local groundY = lerp(startPos.Y, endPos.Y, h)
			local y = groundY + arcHeightAt(h, arcHeight, CONFIG.APEX_TIME_FRACTION)

			local pos = Vector3.new(flatPos.X, y, flatPos.Z)

			-- Spin: tumbles through the air, faster on the way down...
			local spinScale = lerp(1, CONFIG.SPIN_FALL_BOOST, h)
			currentSpin = currentSpin * CFrame.Angles(
				CONFIG.SPIN_X * spinScale * dt,
				CONFIG.SPIN_Y * spinScale * dt,
				CONFIG.SPIN_Z * spinScale * dt
			)

			-- ...but over the LAST SPIN_SETTLE_FRACTION of the flight, it
			-- smoothly winds down toward the upright orientation, so the block
			-- lands NOT rotating and perfectly straight.
			local orientation = currentSpin
			if CONFIG.SPIN_SETTLE_FRACTION > 0 then
				local settleStart = 1 - CONFIG.SPIN_SETTLE_FRACTION
				if t >= settleStart then
					-- 0 at the start of the settle window, 1 at touchdown.
					local s = (t - settleStart) / CONFIG.SPIN_SETTLE_FRACTION
					-- ease-in-out so the stop feels natural, not robotic.
					local sEased = s * s * (3 - 2 * s)
					orientation = currentSpin:Lerp(uprightOrientation, sEased)
				end
			end

			block.CFrame = CFrame.new(pos) * orientation

			-- Touchdown.
			if t >= 1 then
				-- Block is upright now — that's the orientation everything
				-- after this point (bounce, shake, final settle) uses.
				landedOrientation = uprightOrientation
				-- Fire the hit hook NOW, before bounce/shake, so ground-rock
				-- effects spawn exactly on contact.
				if options.OnHit then
					options.OnHit(endPos, intensity)
				end
				phase = "bounce"
				elapsed = 0
			end

			-- =================================================================
			-- PHASE 2: BOUNCE  (one quick, small hop — sells the hard landing)
			-- =================================================================
		elseif phase == "bounce" then
			local bd = CONFIG.BOUNCE_DURATION
			local bt = clamp(elapsed / bd, 0, 1)

			-- Small parabola: up and back down. 4*t*(1-t) peaks at t=0.5.
			local hop = 4 * bt * (1 - bt) * CONFIG.BOUNCE_HEIGHT_STUDS * intensity

			local pos = endPos + Vector3.new(0, hop, 0)
			local orient = landedOrientation or currentSpin
			block.CFrame = CFrame.new(pos) * orient

			if bt >= 1 then
				phase = "shake"
				elapsed = 0
			end

			-- =================================================================
			-- PHASE 3: SHAKE  (strong but brief high-frequency vibration)
			-- =================================================================
		elseif phase == "shake" then
			local sd = CONFIG.SHAKE_DURATION
			local st = clamp(elapsed / sd, 0, 1)

			-- Decay envelope: full strength at impact, fades to 0. Squared so
			-- it drops off quickly — "strong but doesn't linger".
			local decay = (1 - st) * (1 - st)

			-- High-frequency oscillation. Two slightly different frequencies
			-- on the two axes so it doesn't look like a clean sine wobble.
			local phaseT = elapsed * CONFIG.SHAKE_FREQUENCY * math.pi * 2
			local amp    = CONFIG.SHAKE_AMPLITUDE * intensity * decay

			local sideOffset    = math.sin(phaseT)        * amp
			local forwardOffset = math.sin(phaseT * 0.87) * amp
			local vertOffset    = math.sin(phaseT * 1.31) * amp * CONFIG.SHAKE_VERTICAL_FACTOR

			local shakeVec = sideDir * sideOffset
				+ forwardDir * forwardOffset
				+ Vector3.new(0, vertOffset, 0)

			local orient = landedOrientation or currentSpin
			block.CFrame = CFrame.new(endPos + shakeVec) * orient

			if st >= 1 then
				conn:Disconnect()
				-- Settle exactly.
				if CONFIG.KEEP_SPIN_ORIENTATION_ON_LAND and landedOrientation then
					block.CFrame = CFrame.new(endPos) * landedOrientation
				else
					block.CFrame = targetCFrame
				end
				if options.OnComplete then
					options.OnComplete()
				end
			end
		end
	end)

	return conn
end

return LuckyBlockFlight