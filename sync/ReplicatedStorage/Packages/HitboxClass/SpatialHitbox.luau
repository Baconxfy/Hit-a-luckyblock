--[[
SpatialHitbox Module
Provides spatial query functions for hitbox detection using Roblox's spatial query APIs.

All functions support optional debug visualization and custom OverlapParams.
--]]

local SpatialHitbox = {}
local DEFAULT_FOLDER = workspace:FindFirstChild("LivingThings") or workspace

--- Ensures OverlapParams exist, creating default if not supplied.
-- @param supplied OverlapParams|nil Supplied OverlapParams or nil
-- @return OverlapParams Valid OverlapParams instance
local function ensureOverlapParams(supplied)
	if supplied then
		return supplied
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { DEFAULT_FOLDER }
	params.RespectCanCollide = false

	return params
end

--- Ensures RaycastParams exist, creating default if not supplied.
-- @param supplied RaycastParams|nil Supplied RaycastParams or nil
-- @return RaycastParams Valid RaycastParams instance
local function ensureRaycastParams(supplied)
	if supplied then
		return supplied
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { DEFAULT_FOLDER }
	params.RespectCanCollide = false

	return params
end

--- Creates an adorno instance for debug visualization.
-- @param parent Instance Parent instance for the adorno
-- @param class string Class name of the adorno (e.g., "BoxHandleAdornment")
-- @param props table Properties to set on the adorno
-- @return Instance The created adorno instance
local function createAdorno(parent, class, props)
	local adorno = Instance.new(class)
	for k, v in pairs(props) do
		adorno[k] = v
	end
	adorno.Parent = parent
	return adorno
end

--- Automatically destroys an adorno after a specified lifetime.
-- @param adorno Instance The adorno instance to destroy
-- @param lifetime number Lifetime in seconds (default 0.25)
local function autoDestroy(adorno, lifetime)
	task.delay(lifetime or 0.25, function()
		if adorno and adorno.Parent then
			adorno:Destroy()
		end
	end)
end

--- Extracts CFrame from various source types (BasePart, Attachment, CFrame, Vector3).
-- @param source BasePart|Attachment|CFrame|Vector3 The source to extract CFrame from
-- @return CFrame|nil The CFrame, or nil if source type is invalid
local function getCFrameFromSource(source)
	if typeof(source) == "Instance" then
		if source:IsA("BasePart") then
			return source.CFrame
		elseif source:IsA("Attachment") then
			return source.WorldCFrame
		end
	elseif typeof(source) == "CFrame" then
		return source
	elseif typeof(source) == "Vector3" then
		return CFrame.new(source)
	end
	return nil
end

--- Extracts Position from various source types (BasePart, Attachment, CFrame, Vector3).
-- @param source BasePart|Attachment|CFrame|Vector3 The source to extract Position from
-- @return Vector3|nil The position, or nil if source type is invalid
local function getPositionFromSource(source)
	if typeof(source) == "Instance" then
		if source:IsA("BasePart") then
			return source.Position
		elseif source:IsA("Attachment") then
			return source.WorldPosition
		end
	elseif typeof(source) == "CFrame" then
		return source.Position
	elseif typeof(source) == "Vector3" then
		return source
	end
	return nil
end

------------------------------------------------------------------
-- 1) INSTANT QUERIES
------------------------------------------------------------------

--- Performs a box-shaped spatial query.
-- @param cframe CFrame The center and orientation of the box
-- @param size Vector3 The size of the box
-- @param overlapParams OverlapParams|nil Custom overlap parameters (defaults to LivingThings folder)
-- @param debug boolean Whether to show debug visualization
-- @return {BasePart} Array of parts found within the box
function SpatialHitbox.Box(cframe, size, overlapParams, debug)
	if debug then
		local adorno = createAdorno(workspace, "BoxHandleAdornment", {
			CFrame = cframe,
			Size = size,
			Color3 = Color3.new(1, 0, 1),
			Transparency = 0.6,
			Adornee = workspace.Terrain,
			AlwaysOnTop = false,
			ZIndex = 10,
		})
		autoDestroy(adorno)
	end
	return workspace:GetPartBoundsInBox(cframe, size, ensureOverlapParams(overlapParams))
end

--- Performs a sphere-shaped spatial query (radius-based).
-- @param position Vector3 The center position of the sphere
-- @param radius number The radius of the sphere
-- @param overlapParams OverlapParams|nil Custom overlap parameters (defaults to LivingThings folder)
-- @param debug boolean Whether to show debug visualization
-- @return {BasePart} Array of parts found within the sphere
function SpatialHitbox.Radius(position, radius, overlapParams, debug)
	if debug then
		local adorno = createAdorno(workspace, "SphereHandleAdornment", {
			CFrame = CFrame.new(position),
			Radius = radius,
			Color3 = Color3.new(0, 1, 1),
			Transparency = 0.6,
			Adornee = workspace.Terrain,
			AlwaysOnTop = false,
			ZIndex = 10,
		})
		autoDestroy(adorno)
	end

	return workspace:GetPartBoundsInRadius(position, radius, ensureOverlapParams(overlapParams))
end

--- Alias for Radius - performs a sphere-shaped spatial query.
-- @see SpatialHitbox.Radius
SpatialHitbox.Ball = SpatialHitbox.Radius

--- Performs a spatial query using an actual BasePart for precise collision detection.
-- @param part BasePart The part to use for collision detection
-- @param overlapParams OverlapParams|nil Custom overlap parameters (defaults to LivingThings folder)
-- @param debug boolean Whether to show debug visualization
-- @return {BasePart} Array of parts found intersecting with the given part
function SpatialHitbox.InPart(part, overlapParams, debug)
	if not part or not part:IsA("BasePart") then
		warn("[SpatialHitbox.InPart] Invalid part provided")
		return {}
	end

	if debug then
		local adorno = createAdorno(workspace, "BoxHandleAdornment", {
			CFrame = part.CFrame,
			Size = part.Size,
			Color3 = Color3.new(0, 1, 0),
			Transparency = 0.6,
			Adornee = workspace.Terrain,
			AlwaysOnTop = false,
			ZIndex = 10,
		})
		autoDestroy(adorno)
	end

	return workspace:GetPartsInPart(part, ensureOverlapParams(overlapParams))
end

--- Filters parts by exact distance using magnitude calculation (more precise than Radius).
-- @param sourcePos Vector3|BasePart|CFrame The source position to measure distance from
-- @param targetParts {BasePart} Array of parts to filter by distance
-- @param maxDistance number Maximum distance allowed
-- @param debug boolean Whether to show debug visualization
-- @return {BasePart} Array of parts within the maximum distance
function SpatialHitbox.Magnitude(sourcePos, targetParts, maxDistance, debug)
	if typeof(sourcePos) == "Instance" and sourcePos:IsA("BasePart") then
		sourcePos = sourcePos.Position
	elseif typeof(sourcePos) == "CFrame" then
		sourcePos = sourcePos.Position
	end

	if debug then
		local adorno = createAdorno(workspace, "SphereHandleAdornment", {
			CFrame = CFrame.new(sourcePos),
			Radius = maxDistance,
			Color3 = Color3.new(1, 0.5, 0),
			Transparency = 0.7,
			Adornee = workspace.Terrain,
			AlwaysOnTop = false,
			ZIndex = 10,
		})
		autoDestroy(adorno)
	end

	local validParts = {}
	for _, part in ipairs(targetParts) do
		if part and part:IsA("BasePart") then
			local distance = (sourcePos - part.Position).Magnitude
			if distance <= maxDistance then
				table.insert(validParts, part)
			end
		end
	end

	return validParts
end

--- Performs a cylinder-shaped spatial query.
-- @param baseCFrame CFrame The base CFrame of the cylinder
-- @param radius number The radius of the cylinder
-- @param height number The height of the cylinder
-- @param overlapParams OverlapParams|nil Custom overlap parameters (defaults to LivingThings folder)
-- @param debug boolean Whether to show debug visualization
-- @return {BasePart} Array of parts found within the cylinder
function SpatialHitbox.Cylinder(baseCFrame, radius, height, overlapParams, debug)
	local tempPart = Instance.new("Part")
	tempPart.Shape = Enum.PartType.Cylinder
	tempPart.Anchored = true
	tempPart.CanCollide = false
	tempPart.Transparency = 1
	tempPart.Size = Vector3.new(radius * 2, height, radius * 2)
	tempPart.CFrame = baseCFrame * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	tempPart.Parent = workspace

	local params = ensureOverlapParams(overlapParams)
	local parts = tempPart:GetTouchingParts()

	local filteredParts = {}
	for _, part in ipairs(parts) do
		if params.FilterType == Enum.RaycastFilterType.Include then
			local include = false
			for _, inst in ipairs(params.FilterDescendantsInstances) do
				if part:IsDescendantOf(inst) then
					include = true
					break
				end
			end
			if not include then
				continue
			end
		elseif params.FilterType == Enum.RaycastFilterType.Exclude then
			local exclude = false
			for _, inst in ipairs(params.FilterDescendantsInstances) do
				if part:IsDescendantOf(inst) then
					exclude = true
					break
				end
			end
			if exclude then
				continue
			end
		end
		if params.RespectCanCollide and not part.CanCollide then
			continue
		end
		table.insert(filteredParts, part)
	end

	if debug then
		local adorno = createAdorno(workspace, "CylinderHandleAdornment", {
			CFrame = tempPart.CFrame,
			Radius = radius,
			Height = height,
			Color3 = Color3.new(1, 1, 0),
			Transparency = 0.6,
			Adornee = workspace.Terrain,
			AlwaysOnTop = false,
			ZIndex = 10,
		})
		autoDestroy(adorno)
	end

	tempPart:Destroy()

	return filteredParts
end

--- Performs a raycast query.
-- @param origin Vector3 The origin point of the ray
-- @param direction Vector3 The direction vector of the ray
-- @param rayParams RaycastParams|nil Custom raycast parameters (defaults to LivingThings folder)
-- @param debug boolean Whether to show debug visualization
-- @return RaycastResult|nil The raycast result, or nil if nothing was hit
function SpatialHitbox.Raycast(origin, direction, rayParams, debug)
	local params = ensureRaycastParams(rayParams)
	local result = workspace:Raycast(origin, direction, params)

	if debug then
		local adorno = createAdorno(workspace, "LineHandleAdornment", {
			CFrame = CFrame.new(origin, origin + direction),
			Length = direction.Magnitude,
			Thickness = 2,
			Color3 = result and Color3.new(0, 1, 0) or Color3.new(1, 0, 0),
			Adornee = workspace.Terrain,
			AlwaysOnTop = true,
			ZIndex = 10,
		})
		autoDestroy(adorno, 1)
	end

	return result
end

------------------------------------------------------------------
-- 2) TIMED QUERIES
------------------------------------------------------------------

--- Internal helper: Executes a query function repeatedly over a duration.
-- @param queryFunc function Function that returns an array of parts
-- @param duration number Duration in seconds
-- @param interval number Interval between queries in seconds
-- @param debugAdorn Instance|nil Debug adorno to update
-- @param overlapParams OverlapParams|nil Overlap parameters
-- @return table Dictionary of parts found (parts as keys)
local function timedQuery(queryFunc, duration, interval, debugAdorn, overlapParams)
	local results = {}
	local endTime = os.clock() + duration
	interval = interval or 0.1

	if debugAdorn then
		debugAdorn.Parent = workspace.Terrain
	end

	while os.clock() < endTime do
		for _, part in ipairs(queryFunc()) do
			results[part] = true
		end
		task.wait(interval)
	end

	if debugAdorn then
		debugAdorn:Destroy()
	end

	return results
end

--- Performs repeated box queries over a duration (position remains fixed).
-- @param source BasePart|CFrame|Vector3 Source for the box position/orientation
-- @param size Vector3 The size of the box
-- @param duration number Duration in seconds
-- @param interval number Interval between queries in seconds (default 0.1)
-- @param overlapParams OverlapParams|nil Custom overlap parameters
-- @param debug boolean Whether to show debug visualization
-- @return table Dictionary of parts found (parts as keys)
function SpatialHitbox.BoxTimed(source, size, duration, interval, overlapParams, debug)
	local adorno
	local cf = getCFrameFromSource(source)
	if not cf then
		warn("[SpatialHitbox.BoxTimed] Invalid source")
		return {}
	end

	if debug then
		adorno = createAdorno(nil, "BoxHandleAdornment", {
			Size = size,
			Color3 = Color3.new(1, 0, 1),
			Transparency = 0.6,
			AlwaysOnTop = false,
			ZIndex = 9,
		})
	end

	return timedQuery(function()
		if adorno then
			adorno.CFrame = cf
		end
		return workspace:GetPartBoundsInBox(cf, size, ensureOverlapParams(overlapParams))
	end, duration, interval or 0.1, adorno, overlapParams)
end

--- Performs repeated sphere queries over a duration (position remains fixed).
-- @param source BasePart|CFrame|Vector3 Source for the sphere position
-- @param radius number The radius of the sphere
-- @param duration number Duration in seconds
-- @param interval number Interval between queries in seconds (default 0.1)
-- @param overlapParams OverlapParams|nil Custom overlap parameters
-- @param debug boolean Whether to show debug visualization
-- @return table Dictionary of parts found (parts as keys)
function SpatialHitbox.RadiusTimed(source, radius, duration, interval, overlapParams, debug)
	local adorno
	local pos = getPositionFromSource(source)
	if not pos then
		warn("[SpatialHitbox.RadiusTimed] Invalid source")
		return {}
	end

	if debug then
		adorno = createAdorno(nil, "SphereHandleAdornment", {
			Radius = radius,
			Color3 = Color3.new(0, 1, 1),
			Transparency = 0.6,
			AlwaysOnTop = false,
			ZIndex = 9,
		})
	end

	return timedQuery(function()
		if adorno then
			adorno.CFrame = CFrame.new(pos)
		end
		return workspace:GetPartBoundsInRadius(pos, radius, ensureOverlapParams(overlapParams))
	end, duration, interval or 0.1, adorno, overlapParams)
end

--- Performs repeated box queries over a duration (position follows source).
-- @param source BasePart|CFrame|Vector3 Source for the box position/orientation (updated each query)
-- @param size Vector3 The size of the box
-- @param duration number Duration in seconds
-- @param interval number Interval between queries in seconds (default 0.05)
-- @param overlapParams OverlapParams|nil Custom overlap parameters
-- @param debug boolean Whether to show debug visualization
-- @return table Dictionary of parts found (parts as keys)
function SpatialHitbox.WeldedBoxTimed(source, size, duration, interval, overlapParams, debug)
	local adorno
	local cf = getCFrameFromSource(source)
	if not cf then
		warn("[SpatialHitbox.WeldedBoxTimed] Invalid source")
		return {}
	end

	if debug then
		adorno = createAdorno(nil, "BoxHandleAdornment", {
			Size = size,
			Color3 = Color3.new(1, 0.5, 0),
			Transparency = 0.6,
			AlwaysOnTop = false,
			ZIndex = 9,
		})
	end

	return timedQuery(function()
		if adorno then
			adorno.CFrame = cf
		end
		return workspace:GetPartBoundsInBox(cf, size, ensureOverlapParams(overlapParams))
	end, duration, interval or 0.05, adorno, overlapParams)
end

--- Performs repeated sphere queries over a duration (position follows source).
-- @param source BasePart|CFrame|Vector3 Source for the sphere position (updated each query)
-- @param radius number The radius of the sphere
-- @param duration number Duration in seconds
-- @param interval number Interval between queries in seconds (default 0.1)
-- @param overlapParams OverlapParams|nil Custom overlap parameters
-- @param debug boolean Whether to show debug visualization
-- @return table Dictionary of parts found (parts as keys)
function SpatialHitbox.WeldedRadiusTimed(source, radius, duration, interval, overlapParams, debug)
	local adorno
	local pos = getPositionFromSource(source)
	if not pos then
		warn("[SpatialHitbox.WeldedRadiusTimed] Invalid source")
		return {}
	end

	if debug then
		adorno = createAdorno(nil, "SphereHandleAdornment", {
			Radius = radius,
			Color3 = Color3.new(0, 1, 1),
			Transparency = 0.6,
			AlwaysOnTop = false,
			ZIndex = 9,
		})
	end

	return timedQuery(function()
		if adorno then
			adorno.CFrame = CFrame.new(pos)
		end
		return workspace:GetPartBoundsInRadius(pos, radius, ensureOverlapParams(overlapParams))
	end, duration, interval or 0.1, adorno, overlapParams)
end

--- Alias for WeldedRadiusTimed - performs repeated sphere queries over duration (position follows source).
-- @see SpatialHitbox.WeldedRadiusTimed
SpatialHitbox.WeldedBallTimed = SpatialHitbox.WeldedRadiusTimed

--- Performs repeated cylinder queries over a duration (position follows source).
-- @param source BasePart|CFrame|Vector3 Source for the cylinder position/orientation (updated each query)
-- @param radius number The radius of the cylinder
-- @param height number The height of the cylinder
-- @param duration number Duration in seconds
-- @param interval number Interval between queries in seconds (default 0.05)
-- @param overlapParams OverlapParams|nil Custom overlap parameters
-- @param debug boolean Whether to show debug visualization
-- @return table Dictionary of parts found (parts as keys)
function SpatialHitbox.WeldedCylinderTimed(source, radius, height, duration, interval, overlapParams, debug)
	local adorno
	local cf = getCFrameFromSource(source)
	if not cf then
		warn("[SpatialHitbox.WeldedCylinderTimed] Invalid source")
		return {}
	end

	if debug then
		adorno = createAdorno(nil, "CylinderHandleAdornment", {
			Radius = radius,
			Height = height,
			Color3 = Color3.new(1, 1, 0),
			Transparency = 0.6,
			AlwaysOnTop = false,
			ZIndex = 9,
		})
	end

	return timedQuery(function()
		if adorno then
			adorno.CFrame = cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		end

		local tempPart = Instance.new("Part")
		tempPart.Shape = Enum.PartType.Cylinder
		tempPart.Anchored = true
		tempPart.CanCollide = false
		tempPart.Transparency = 1
		tempPart.Size = Vector3.new(radius * 2, height, radius * 2)
		tempPart.CFrame = cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		tempPart.Parent = workspace

		local params = ensureOverlapParams(overlapParams)
		local parts = tempPart:GetTouchingParts()

		local filteredParts = {}
		for _, part in ipairs(parts) do
			if params.FilterType == Enum.RaycastFilterType.Include then
				local include = false
				for _, inst in ipairs(params.FilterDescendantsInstances) do
					if part:IsDescendantOf(inst) then
						include = true
						break
					end
				end
				if not include then
					continue
				end
			elseif params.FilterType == Enum.RaycastFilterType.Exclude then
				local exclude = false
				for _, inst in ipairs(params.FilterDescendantsInstances) do
					if part:IsDescendantOf(inst) then
						exclude = true
						break
					end
				end
				if exclude then
					continue
				end
			end
			if params.RespectCanCollide and not part.CanCollide then
				continue
			end
			table.insert(filteredParts, part)
		end

		tempPart:Destroy()
		return filteredParts
	end, duration, interval or 0.05, adorno, overlapParams)
end

return SpatialHitbox
