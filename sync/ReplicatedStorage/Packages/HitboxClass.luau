--[[


░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

--[[

Enhanced HitboxClass Module v2.2
Highly optimized for server-side performance with advanced features

HitMode behavior:
- "Weak" (default): Fires OnHit once per character, on the first part hit.
- "Strong": Fires OnHit for every part hit on the same character.
- "Cooldown": Fires OnHit once per character, then ignores further hits on that character until the cooldown (HitCooldown, default 1 second) expires.

HitboxType options (Instant - execute once):
- "Box": Single box overlap at specified CFrame/Position/Part with given size (or proportional if opts.proportional provided).
- "Ball": Single sphere overlap at specified CFrame/Position/Part with given radius (or proportional if opts.proportional provided).
- "InPart": Uses an actual BasePart for precise collision detection (requires BasePart root).
- "Magnitude": Distance-based detection from a source point (more precise than Ball, uses exact distance calculation).
- "Cylinder": Cylindrical detection area (requires size for height and radius).

HitboxType options (Timed - repeated over duration):
- "TimedBox": Box overlap repeated over duration with interval at specified CFrame/Position/Part (proportional supported).
- "TimedBall": Sphere overlap repeated over duration with interval at specified CFrame/Position/Part (proportional supported).

HitboxType options (Welded - follows root BasePart over duration):
- "WeldedBox": Box overlap welded to root BasePart, updated continuously over duration with interval (proportional supported).
- "WeldedBall": Sphere overlap welded to root BasePart, updated continuously over duration with interval (proportional supported).

Enhanced Opts table:
- root (BasePart/CFrame/Vector3): Required for all types; if opts.proportional is provided, root must be BasePart.
- size (Vector3): Size of box or diameter vector for sphere (use size.X for radius * 2). Ignored if opts.proportional is provided.
- duration (number): Duration in seconds. Works for ALL hitbox types EXCEPT Box/Ball. If not provided and lifecycleInstance exists, hitbox runs until lifecycleInstance is destroyed.
- interval (number): Interval in seconds between repeated queries (default 0.05). Used when duration is provided.
- lifecycleInstance (Instance): Instance to track for lifecycle. If this instance is destroyed/removed, the hitbox is automatically destroyed. Defaults to root if not specified. If provided without duration, hitbox runs until instance is destroyed.
- overlapParams (OverlapParams): Custom overlap parameters for spatial queries.
- debug (boolean): Whether to enable debug drawing.
- HitMode (string): "Weak" (default), "Strong", or "Cooldown".
- HitCooldown (number): Cooldown seconds for "Cooldown" mode (default 1).
- IgnoreCharacters (table): Array of Models to ignore (OnHit will not fire for these).
- proportional (table or nil): If present, enables proportional sizing and offset.
    - scaleMultiplier (Vector3): Multiplier for size scaling.
    - offsetMultiplier (number): Multiplier for offset distance.
- velocityPrediction (boolean): Predicts target movement for moving hitboxes (default false).
- velocityMultiplier (number): Multiplier for velocity prediction (default 6).
- dotProductFilter (table): Directional filtering based on dot product.
    - dotProduct (number): Minimum dot product required (-1 to 1).
    - referenceVector (Vector3): Reference direction vector.
    - sourcePosition (Vector3/BasePart): Source position for direction calculation.
- blacklistParts (table): Array of BaseParts to ignore for granular filtering.
- hitboxId (string/number): Optional ID for tracking and cleanup.

Usage:
Create with HitboxClass.new(HitboxType, opts), then call :Start() to begin detection.
Listen to OnHit event: OnHit:Connect(function(characterModel, hitPart) ... end)
Call :Destroy() to stop and clean up.

--]]

local RunService = game:GetService("RunService")
local SpatialHitbox = require(script.SpatialHitbox)
local FastSignal = require(script.Parent.FastSignal)

local HitboxClass = {}
HitboxClass.__index = HitboxClass

-- Global registry for ID-based cleanup (lightweight alternative to cache)
local HitboxRegistry = {}

-- Hitbox type configuration: shape, timing, requiresBasePart, requiresSize, requiresRadius
-- Note: duration now works for ALL types except Box/Ball (which are instant-only)
local HITBOX_TYPES = {
	Box = { shape = "Box", timing = "instant", requiresSize = true },
	Ball = { shape = "Ball", timing = "instant", requiresRadius = true },
	InPart = { shape = "InPart", timing = "instant", requiresBasePart = true },
	Magnitude = { shape = "Magnitude", timing = "instant", requiresRadius = true },
	Cylinder = { shape = "Cylinder", timing = "instant", requiresSize = true, requiresRadius = true },
	TimedBox = { shape = "Box", timing = "timed", requiresSize = true },
	TimedBall = { shape = "Ball", timing = "timed", requiresRadius = true },
	WeldedBox = {
		shape = "Box",
		timing = "welded",
		requiresBasePart = true,
		requiresSize = true,
	},
	WeldedBall = {
		shape = "Ball",
		timing = "welded",
		requiresBasePart = true,
		requiresRadius = true,
	},
}

--- Creates a lookup set from an array for O(1) checking.
-- @param array table Array of items to convert to a set
-- @return table|nil Lookup set with items as keys, or nil if array is empty/nil
local function createLookupSet(array)
	if not array or #array == 0 then
		return nil
	end
	local set = {}
	for _, item in ipairs(array) do
		set[item] = true
	end
	return set
end

--- Checks if a model or part is blacklisted using optimized lookup sets.
-- @param model Model The character model to check
-- @param part BasePart The part that was hit
-- @param ignoreCharSet table|nil Lookup set of ignored characters (O(1) check)
-- @param blacklistParts table|nil Array of blacklisted parts
-- @return boolean True if the model/part is blacklisted
local function isBlacklisted(model, part, ignoreCharSet, blacklistParts)
	-- Check character blacklist (O(1) lookup)
	if ignoreCharSet and ignoreCharSet[model] then
		return true
	end

	-- Check part blacklist (linear but necessary for IsDescendantOf check)
	if blacklistParts and #blacklistParts > 0 then
		for _, blacklistedPart in ipairs(blacklistParts) do
			if part == blacklistedPart or part:IsDescendantOf(blacklistedPart) then
				return true
			end
		end
	end

	return false
end

--- Checks if a model passes the dot product directional filter.
-- @param model Model The character model to check
-- @param filter table|nil Filter configuration with dotProduct, referenceVector, and sourcePosition
-- @return boolean True if the model passes the filter (or if filter is nil)
local function passesDotProductFilter(model, filter)
	if not filter then
		return true
	end

	local sourcePos = filter.sourcePosition
	if typeof(sourcePos) == "Instance" and sourcePos:IsA("BasePart") then
		sourcePos = sourcePos.Position
	end

	local targetPos = model.PrimaryPart and model.PrimaryPart.Position
	if not targetPos or not sourcePos then
		return true
	end

	local directionToTarget = (targetPos - sourcePos).Unit
	local dotProduct = directionToTarget:Dot(filter.referenceVector.Unit)

	return dotProduct >= filter.dotProduct
end

--- Applies velocity prediction to a CFrame for moving hitboxes.
-- @param cframe CFrame The base CFrame to apply prediction to
-- @param root BasePart The root part to get velocity from
-- @param velocityMultiplier number Multiplier for velocity prediction (default 6)
-- @return CFrame The CFrame with velocity prediction applied, or original if root is invalid/not moving
local function applyVelocityPrediction(cframe, root, velocityMultiplier)
	if not root or not root:IsA("BasePart") then
		return cframe
	end

	local velocity = root.AssemblyLinearVelocity
	if velocity.Magnitude < 1 then
		return cframe
	end -- Skip if barely moving

	local prediction = velocity / (velocityMultiplier or 6)
	return cframe * CFrame.new(prediction)
end

--- Extracts CFrame from various source types (BasePart, CFrame, Vector3).
-- @param source BasePart|CFrame|Vector3 The source to extract CFrame from
-- @return CFrame|nil The CFrame, or nil if source type is invalid
local function getCFrameFromSource(source)
	if typeof(source) == "Instance" then
		if source:IsA("BasePart") then
			return source.CFrame
		end
	elseif typeof(source) == "CFrame" then
		return source
	elseif typeof(source) == "Vector3" then
		return CFrame.new(source)
	end
	return nil
end

--- Extracts Position from various source types (BasePart, CFrame, Vector3).
-- @param source BasePart|CFrame|Vector3 The source to extract Position from
-- @return Vector3|nil The position, or nil if source type is invalid
local function getPositionFromSource(source)
	if typeof(source) == "Instance" then
		if source:IsA("BasePart") then
			return source.Position
		end
	elseif typeof(source) == "CFrame" then
		return source.Position
	elseif typeof(source) == "Vector3" then
		return source
	end
	return nil
end

--- Calculates proportional size and offset based on root part and proportional options.
-- @param root BasePart The root part to calculate proportions from
-- @param proportionalOpts table Proportional options with scaleMultiplier and offsetMultiplier
-- @return Vector3 The calculated size
-- @return CFrame The calculated offset CFrame
local function proportionalData(root, proportionalOpts)
	local scale = proportionalOpts.scaleMultiplier or Vector3.new(2.5, 1.8, 2.2)
	local offsetMult = proportionalOpts.offsetMultiplier or 1.5

	local rSize = root.Size
	local baseRadius = (rSize.X + rSize.Z) / 2

	local size = Vector3.new(baseRadius * scale.X, rSize.Y * scale.Y, baseRadius * scale.Z)

	local offsetDistance = -math.max(rSize.Z, rSize.X) * offsetMult
	local offsetCFrame = CFrame.new(0, 0, offsetDistance)

	return size, offsetCFrame
end

--- Gets the character model from a part by finding the ancestor Model with a Humanoid.
-- @param part BasePart The part to find the character from
-- @return Model|nil The character model, or nil if not found
local function getCharacterFromPart(part)
	if not part then
		return nil
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		return model
	end
	return nil
end

--- Creates a new HitboxClass instance.
-- @param HitboxType string The type of hitbox ("Box", "Ball", "InPart", "Magnitude", "Cylinder", "TimedBox", "TimedBall", "WeldedBox", "WeldedBall")
-- @param opts table Configuration options (see header documentation for all properties)
-- @return HitboxClass A new HitboxClass instance
function HitboxClass.new(HitboxType, opts)
	opts = opts or {}

	local self = setmetatable({}, HitboxClass)
	self.HitboxType = HitboxType or "Box"

	-- Enhanced opts with new features
	self.Opts = {
		root = opts.root,
		size = opts.size,
		duration = opts.duration,
		interval = opts.interval or 0.05,
		overlapParams = opts.overlapParams,
		debug = opts.debug,
		HitMode = opts.HitMode or "Weak",
		HitCooldown = opts.HitCooldown or 1,
		IgnoreCharacters = opts.IgnoreCharacters or {},
		proportional = opts.proportional,

		-- NEW ENHANCED FEATURES
		velocityPrediction = opts.velocityPrediction or false,
		velocityMultiplier = opts.velocityMultiplier or 6,
		dotProductFilter = opts.dotProductFilter, -- {dotProduct, referenceVector, sourcePosition}
		blacklistParts = opts.blacklistParts or {},
		hitboxId = opts.hitboxId,

		-- Lifecycle management: if lifecycleInstance is destroyed, hitbox is destroyed
		-- Defaults to root if not specified
		lifecycleInstance = opts.lifecycleInstance or opts.root,
	}

	self.OnHit = FastSignal.new()

	self.HitMode = self.Opts.HitMode
	self.HitCooldown = self.Opts.HitCooldown

	self._hitCache = {}
	self._running = false
	self._conn = nil
	self._lifecycleConnection = nil

	-- Cache typeConfig for fast access
	self._typeConfig = HITBOX_TYPES[self.HitboxType]

	-- Create lookup sets for fast blacklist checking
	self._ignoreCharSet = createLookupSet(self.Opts.IgnoreCharacters)

	-- Cache transform for instant/timed types (doesn't change)
	self._cachedTransform = nil
	self._transformCached = false

	-- Register hitbox by ID for cleanup
	if self.Opts.hitboxId then
		if not HitboxRegistry[self.Opts.hitboxId] then
			HitboxRegistry[self.Opts.hitboxId] = {}
		end
		table.insert(HitboxRegistry[self.Opts.hitboxId], self)
	end

	return self
end

--- Cleans expired entries from the cooldown cache (only for Cooldown mode).
-- Removes entries where the cooldown period has expired.
function HitboxClass:_cleanCooldownCache()
	-- Only clean if in Cooldown mode and cache exists
	local hitCache = self._hitCache
	if self.HitMode ~= "Cooldown" or not hitCache then
		return
	end

	-- Only clean if cache has entries (avoid unnecessary work)
	local cacheSize = 0
	for _ in pairs(hitCache) do
		cacheSize = cacheSize + 1
	end
	if cacheSize == 0 then
		return
	end

	-- Clean expired entries
	local now = tick()
	local cooldown = self.HitCooldown
	for model, lastHitTime in pairs(hitCache) do
		if now - lastHitTime >= cooldown then
			hitCache[model] = nil
		end
	end
end

--- Processes a hit for a character model and part, applying filters and HitMode logic.
-- @param model Model The character model that was hit
-- @param part BasePart The part that was hit
function HitboxClass:_processHit(model, part)
	if not model or not part or not self.OnHit then
		return
	end

	-- Enhanced blacklist checking (optimized with sets)
	if isBlacklisted(model, part, self._ignoreCharSet, self.Opts.blacklistParts) then
		return
	end

	-- Dot product filtering
	if not passesDotProductFilter(model, self.Opts.dotProductFilter) then
		return
	end

	-- Process based on HitMode (optimized with early returns)
	local hitCache = self._hitCache
	if self.HitMode == "Strong" then
		self.OnHit:Fire(model, part)
		return
	end

	if self.HitMode == "Weak" then
		if hitCache and hitCache[model] then
			return
		end
		if hitCache then
			hitCache[model] = true
		end
		self.OnHit:Fire(model, part)
		return
	end

	if self.HitMode == "Cooldown" then
		local now = tick()
		local lastHit = hitCache and hitCache[model]
		if lastHit and now - lastHit < self.HitCooldown then
			return
		end
		if hitCache then
			hitCache[model] = now
		end
		self.OnHit:Fire(model, part)
		return
	end
end

--- Gets the current transform (CFrame, Position, Size, Radius) based on timing type.
-- Caches transforms for instant/timed types to avoid recalculating.
-- @return table|nil Transform table with cframe, position, size, radius, or nil if invalid
function HitboxClass:_getCurrentTransform()
	local typeConfig = self._typeConfig
	if not typeConfig then
		return nil
	end

	-- Cache transform for instant/timed types (doesn't change)
	if typeConfig.timing ~= "welded" and self._transformCached then
		return self._cachedTransform
	end

	local root = self.Opts.root
	local proportional = self.Opts.proportional
	local useProportional = proportional ~= nil
	local queryCFrame, queryPos, querySize, queryRadius

	-- For welded types, update position from root each frame
	if typeConfig.timing == "welded" then
		if not (typeof(root) == "Instance" and root:IsA("BasePart")) then
			return nil
		end

		if useProportional then
			local localOffset
			querySize, localOffset = proportionalData(root, proportional)
			queryCFrame = root.CFrame * localOffset
			queryPos = queryCFrame.Position
			queryRadius = querySize.X / 2
		else
			queryCFrame = root.CFrame
			queryPos = root.Position
			querySize = self.Opts.size
			queryRadius = querySize and (querySize.X / 2) or nil
		end

		-- Apply velocity prediction for welded hitboxes
		if self.Opts.velocityPrediction and queryCFrame then
			queryCFrame = applyVelocityPrediction(queryCFrame, root, self.Opts.velocityMultiplier)
			queryPos = queryCFrame.Position
		end
	else
		-- For instant/timed types, get from source (may be static)
		if useProportional then
			if not (typeof(root) == "Instance" and root:IsA("BasePart")) then
				return nil
			end
			local localOffset
			querySize, localOffset = proportionalData(root, proportional)
			queryCFrame = root.CFrame * localOffset
			queryPos = queryCFrame.Position
			queryRadius = querySize.X / 2
		else
			queryCFrame = getCFrameFromSource(root)
			queryPos = getPositionFromSource(root)
			querySize = self.Opts.size
			queryRadius = querySize and (querySize.X / 2) or nil
		end

		-- Apply velocity prediction if enabled
		if self.Opts.velocityPrediction and queryCFrame then
			queryCFrame = applyVelocityPrediction(queryCFrame, root, self.Opts.velocityMultiplier)
			queryPos = queryCFrame.Position
		end
	end

	local transform = {
		cframe = queryCFrame,
		position = queryPos,
		size = querySize,
		radius = queryRadius,
	}

	-- Cache transform for instant/timed types
	if typeConfig.timing ~= "welded" then
		self._cachedTransform = transform
		self._transformCached = true
	end

	return transform
end

--- Executes the spatial query based on the hitbox shape type.
-- @param transform table Transform table with cframe, position, size, radius
-- @return {BasePart} Array of parts found in the query
function HitboxClass:_executeQuery(transform)
	if not transform then
		return {}
	end

	local typeConfig = self._typeConfig
	if not typeConfig then
		return {}
	end

	local shape = typeConfig.shape
	local overlapParams = self.Opts.overlapParams
	local debug = self.Opts.debug
	local root = self.Opts.root

	if shape == "Box" then
		if not transform.size then
			return {}
		end
		return SpatialHitbox.Box(transform.cframe, transform.size, overlapParams, debug)
	elseif shape == "Ball" then
		if not transform.radius then
			return {}
		end
		return SpatialHitbox.Ball(transform.position, transform.radius, overlapParams, debug)
	elseif shape == "InPart" then
		if not (typeof(root) == "Instance" and root:IsA("BasePart")) then
			return {}
		end
		return SpatialHitbox.InPart(root, overlapParams, debug)
	elseif shape == "Magnitude" then
		if not transform.radius then
			return {}
		end
		-- Get all parts in area first, then filter by exact distance
		local allParts = SpatialHitbox.Ball(transform.position, transform.radius, overlapParams, false)
		return SpatialHitbox.Magnitude(transform.position, allParts, transform.radius, debug)
	elseif shape == "Cylinder" then
		if not transform.radius or not transform.size then
			return {}
		end
		local height = typeof(transform.size) == "Vector3" and transform.size.Y or transform.size
		return SpatialHitbox.Cylinder(transform.cframe, transform.radius, height, overlapParams, debug)
	end

	return {}
end

--- Performs a spatial query and processes all hits found.
-- Validates requirements, executes query, and processes hits according to HitMode.
function HitboxClass:_queryAndProcess()
	if not self._running then
		return
	end

	local root = self.Opts.root
	if not root then
		return
	end

	-- Use cached typeConfig
	local typeConfig = self._typeConfig
	if not typeConfig then
		return
	end

	-- Validate requirements (early exit)
	if typeConfig.requiresBasePart then
		if not (typeof(root) == "Instance" and root:IsA("BasePart")) then
			return
		end
	end

	-- Get current transform (cached for instant/timed types)
	local transform = self:_getCurrentTransform()
	if not transform then
		return
	end

	-- Validate size/radius requirements (early exit)
	if (typeConfig.requiresSize and not transform.size) or (typeConfig.requiresRadius and not transform.radius) then
		return
	end

	-- Execute spatial query
	local parts = self:_executeQuery(transform)
	if #parts == 0 then
		return
	end

	-- Process hits (optimized)
	local hitMode = self.HitMode
	if hitMode == "Strong" then
		-- Strong mode: process all parts
		for i = 1, #parts do
			local model = getCharacterFromPart(parts[i])
			if model then
				self:_processHit(model, parts[i])
			end
		end
	else
		-- Weak/Cooldown mode: one hit per character
		local seenModels = {}
		for i = 1, #parts do
			local model = getCharacterFromPart(parts[i])
			if model and not seenModels[model] then
				seenModels[model] = true
				self:_processHit(model, parts[i])
			end
		end
	end

	-- Clean cooldown cache only if needed
	if hitMode == "Cooldown" then
		self:_cleanCooldownCache()
	end
end

--- Starts the hitbox detection.
-- For Box/Ball types: executes once and destroys immediately.
-- For other types: sets up lifecycle monitoring and heartbeat loop if duration/lifecycleInstance is provided.
function HitboxClass:Start()
	if self._running then
		return
	end

	local typeConfig = self._typeConfig
	if not typeConfig then
		return
	end

	self._running = true

	-- Check if this is Box or Ball (instant only, no duration/lifecycleInstance support)
	local isInstantOnly = (self.HitboxType == "Box" or self.HitboxType == "Ball")

	-- Instant types (Box/Ball) execute only once - ignore lifecycleInstance
	if isInstantOnly then
		self:_queryAndProcess()
		self:Destroy()
		return
	end

	-- Setup lifecycle instance monitoring (only for non-Box/Ball types)
	local lifecycleInstance = self.Opts.lifecycleInstance
	if lifecycleInstance and typeof(lifecycleInstance) == "Instance" then
		-- Monitor for destruction
		self._lifecycleConnection = lifecycleInstance.AncestryChanged:Connect(function()
			if not lifecycleInstance.Parent then
				-- Instance was destroyed or removed
				self:Destroy()
			end
		end)

		-- Also check if already destroyed
		if not lifecycleInstance.Parent then
			self:Destroy()
			return
		end
	end

	-- For all other types, duration is optional
	-- If no duration and no lifecycleInstance, run once
	local duration = self.Opts.duration
	if not duration or duration <= 0 then
		-- No duration specified - run once if no lifecycleInstance, otherwise run until lifecycleInstance is destroyed
		if not lifecycleInstance or typeof(lifecycleInstance) ~= "Instance" then
			self:_queryAndProcess()
			self:Destroy()
			return
		end
		-- Has lifecycleInstance - run continuously until it's destroyed
		duration = math.huge -- Infinite duration (lifecycleInstance will control destruction)
	end

	-- Optimized heartbeat loop (for timed/welded types or types with duration)
	local interval = self.Opts.interval
	local startTime = tick()
	local endTime = duration ~= math.huge and (startTime + duration) or math.huge
	local accumulatedTime = 0

	self._conn = RunService.Heartbeat:Connect(function(dt)
		if not self._running then
			if self._conn then
				self._conn:Disconnect()
				self._conn = nil
			end
			return
		end

		-- Check duration (only if not infinite)
		if endTime ~= math.huge and tick() >= endTime then
			self:Destroy()
			return
		end

		-- Check if lifecycleInstance still exists (check from opts to ensure we have latest reference)
		local currentLifecycle = self.Opts and self.Opts.lifecycleInstance
		if currentLifecycle and typeof(currentLifecycle) == "Instance" then
			if not currentLifecycle.Parent then
				self:Destroy()
				return
			end
		end

		-- Accumulate time for interval-based queries
		accumulatedTime = accumulatedTime + dt
		if accumulatedTime >= interval then
			accumulatedTime = 0
			self:_queryAndProcess()
		end
	end)
end

--- Destroys the hitbox and cleans up all connections and resources.
-- Disconnects heartbeat, lifecycle monitoring, clears cache, and removes from registry.
function HitboxClass:Destroy()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	if self._lifecycleConnection then
		self._lifecycleConnection:Disconnect()
		self._lifecycleConnection = nil
	end
	self._running = false
	self._hitCache = {}
	if self.OnHit then
		self.OnHit:DisconnectAll()
		self.OnHit = nil
	end

	-- Remove from registry
	if self.Opts and self.Opts.hitboxId then
		local registry = HitboxRegistry[self.Opts.hitboxId]
		if registry then
			for i, hitbox in ipairs(registry) do
				if hitbox == self then
					table.remove(registry, i)
					break
				end
			end
			-- Clean up empty registry entries
			if #registry == 0 then
				HitboxRegistry[self.Opts.hitboxId] = nil
			end
		end
	end

	self.Opts = nil
end

--- Static method: Destroys all hitboxes with a specific ID.
-- @param hitboxId string|number The ID of hitboxes to destroy
-- @return number The number of hitboxes destroyed
function HitboxClass.ClearHitboxesWithId(hitboxId)
	local hitboxes = HitboxRegistry[hitboxId]
	if not hitboxes then
		return 0
	end

	local count = #hitboxes
	for _, hitbox in ipairs(hitboxes) do
		pcall(function()
			hitbox:Destroy()
		end)
	end
	HitboxRegistry[hitboxId] = nil

	return count
end

--- Static method: Gets all active hitboxes with a specific ID.
-- @param hitboxId string|number The ID to search for
-- @return {HitboxClass} Array of hitbox instances with the given ID
function HitboxClass.GetHitboxesWithId(hitboxId)
	return HitboxRegistry[hitboxId] or {}
end

--- Static method: Gets the total count of all active hitboxes.
-- @return number Total number of active hitboxes across all IDs
function HitboxClass.GetActiveHitboxCount()
	local total = 0
	for _, hitboxes in pairs(HitboxRegistry) do
		total = total + #hitboxes
	end
	return total
end

--- Static method: Destroys all active hitboxes (emergency cleanup).
-- @return number The number of hitboxes destroyed
function HitboxClass.ClearAllHitboxes()
	local count = 0
	for hitboxId, hitboxes in pairs(HitboxRegistry) do
		for _, hitbox in ipairs(hitboxes) do
			pcall(function()
				hitbox:Destroy()
			end)
			count = count + 1
		end
	end
	HitboxRegistry = {}
	return count
end

return HitboxClass
