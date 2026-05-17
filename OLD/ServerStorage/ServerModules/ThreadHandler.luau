--[[


░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

--[[
	ThreadHandler Module (Server-Side)

	Manages scheduling and execution of recurring callbacks at specified intervals
	via RunService.Heartbeat (optimized for server-side logic).

	Features:
	• Add: delayed first execution
	• AddImmediate: immediate first execution
	• Pause/Resume: per-loop control
	• PauseAll/ResumeAll: global control
	• Remove: returns duration and callback
	• Edit: modify existing loop
--]]

-- Get the RunService to listen to the Heartbeat event (best for server-side)
local RunService = game:GetService("RunService")

-- ThreadHandler table
local ThreadHandler = {}

-- Table to store all scheduled loops
ThreadHandler.Loops = {}

-- Global pause flag
ThreadHandler._pausedAll = false

-- Internal heartbeat handler called each frame
-- @param dt: delta time since last frame (seconds)
function ThreadHandler:_heartbeat(dt)
	if self._pausedAll then
		return
	end

	local t = os.clock() -- Use os.clock() for consistent timing
	local i = 1
	-- Iterate through active loops; manual index to allow removal
	while i <= #self.Loops do
		local loopData = self.Loops[i]

		-- Skip if loop is paused or doesn't exist
		if loopData and not loopData._paused then
			-- If the interval has elapsed since last run
			-- For negative timestamps (AddImmediate), skip first frame if already executed
			local shouldExecute = false
			if loopData.t < 0 then
				-- Negative timestamp means AddImmediate
				if not loopData._immediateExecuted then
					-- First frame - execute and update
					shouldExecute = true
					loopData.t = t -- Update to current time
					loopData._immediateExecuted = nil -- Clear flag
				else
					-- Already executed immediately, just update timestamp
					loopData.t = t
					loopData._immediateExecuted = nil -- Clear flag
				end
			elseif t - loopData.t > loopData.i then
				-- Normal case: interval has elapsed
				shouldExecute = true
				loopData.t = t -- Update last run timestamp
			end

			if shouldExecute then
				-- Invoke the callback with current time and delta
				local success, err = pcall(loopData.c, t, dt, i)
				if not success then
					warn(string.format("[ThreadHandler] Loop %d error: %s\n%s", i, err, debug.traceback()))
				end
			end
		end

		-- Move to next loop
		i = i + 1
	end
end

-- Connect the Heartbeat event to our handler (optimized for server-side)
RunService.Heartbeat:Connect(function(dt)
	ThreadHandler:_heartbeat(dt)
end)

--[[
	Adds a new repeating loop with delayed first execution
	@param interval: number (seconds) between callbacks
	@param callback: function to execute each interval
	@return index: position in the Loops array (use for removal)
]]
function ThreadHandler:Add(interval:number, callback:()->()) :number
	if not callback then
		return
	end
	if not interval then
		return
	end

	local loopData = {
		t = 0, -- last execution timestamp (0 means wait for first interval)
		i = interval, -- interval duration
		c = callback, -- callback function
		_paused = false, -- pause state
	}

	table.insert(self.Loops, loopData)
	return #self.Loops
end

--[[
	Adds a new repeating loop with immediate first execution
	@param interval: number (seconds) between callbacks
	@param callback: function to execute each interval
	@return index: position in the Loops array (use for removal)
]]
function ThreadHandler:AddImmediate(interval:number, callback:()->()) :number
	if not callback then
		return
	end
	if not interval then
		return
	end

	-- Use a negative timestamp as a flag for immediate execution
	-- The _stepped handler will detect this and execute on first frame
	-- We set t to a very negative value so it executes on first Stepped frame
	local loopData = {
		t = -math.huge, -- very negative value flags this as AddImmediate
		i = interval, -- interval duration
		c = callback, -- callback function
		_paused = false, -- pause state
		_immediateExecuted = false, -- flag to prevent double execution
	}

	table.insert(self.Loops, loopData)
	local index = #self.Loops

	-- Execute immediately after loop is registered
	loopData._immediateExecuted = true
	task.spawn(function()
		local success, err = pcall(callback, 0, 0, index)
		if not success then
			warn(string.format("[ThreadHandler] Loop %d (immediate) error: %s\n%s", index, err, debug.traceback()))
		end
	end)

	return index
end

--[[
	Pause a specific loop
	@param index: position returned by Add/AddImmediate
	@return success: boolean indicating if pause was applied
]]
function ThreadHandler:Pause(index:number) :boolean
	if not index then
		return false
	end
	local loopData = self.Loops[index]
	if not loopData then
		return false
	end

	if not loopData._paused then
		loopData._paused = true
		return true
	end
	return false
end

--[[
	Resume a paused loop
	@param index: position returned by Add/AddImmediate
	@return success: boolean indicating if resume was applied
]]
function ThreadHandler:Resume(index:number) :boolean
	if not index then
		return false
	end
	local loopData = self.Loops[index]
	if not loopData then
		return false
	end

	if loopData._paused then
		loopData._paused = false
		-- Reset timestamp to current time minus interval so it executes after interval
		loopData.t = 0
		return true
	end
	return false
end

--[[
	Pause all loops globally
]]
function ThreadHandler:PauseAll()
	self._pausedAll = true
end

--[[
	Resume all loops globally
]]
function ThreadHandler:ResumeAll()
	self._pausedAll = false
end

--[[
	Edits an existing loop's interval and/or callback
	@param index: position returned by Add
	@param interval: (optional) new interval in seconds
	@param callback: (optional) new callback function
	@return success: boolean indicating if edit was applied
]]
function ThreadHandler:Edit(index:number, interval:number?, callback:()->()?)
	if not index then
		return
	end
	local loopData = self.Loops[index]
	if not loopData then
		return
	end

	-- Update interval if provided
	if interval then
		loopData.i = interval
	end
	-- Update callback if provided
	if callback then
		loopData.c = callback
	end

	self.Loops[index] = loopData

	return true
end

--[[
	Removes a previously added loop
	@param index: position returned by Add/AddImmediate
	@return interval, callback: the removed loop's interval and callback, or nil if invalid index
]]
function ThreadHandler:Remove(index:number)
	if not index then
		return nil, nil
	end
	local removedData = table.remove(self.Loops, index)
	if removedData then
		return removedData.i, removedData.c
	end
	return nil, nil
end

-- Return the ThreadHandler interface
return ThreadHandler
