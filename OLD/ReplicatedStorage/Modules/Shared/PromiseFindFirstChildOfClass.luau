x--[[

░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

--[[
	PromiseFindFirstChildOfClass - Optimized
	Client: Infinite wait | Server: Configurable timeout
]]

local RunService = game:GetService("RunService")
local IS_SERVER = RunService:IsServer()
local DEFAULT_TIMEOUT = 30

return function(parent: Instance?, className: string, timeout: number?): Instance?
	assert(parent, "Parent cannot be nil")
	assert(type(className) == "string" and className ~= "", "ClassName must be non-empty string")

	-- Immediate check
	local child = parent:FindFirstChildOfClass(className)
	if child then return child end

	-- Timeout configuration
	local maxTime = IS_SERVER and (timeout or DEFAULT_TIMEOUT) or math.huge
	local deadline = os.clock() + maxTime

	-- State variables
	local connection
	local result

	-- Event-driven listener
	connection = parent.ChildAdded:Connect(function(newChild)
		if newChild:IsA(className) then
			result = newChild
			connection:Disconnect()
		end
	end)

	-- Optimized wait loop
	repeat
		-- Periodic verification every frame
		child = parent:FindFirstChildOfClass(className)
		if child then
			result = child
			break
		end

		-- Timeout check (server only)
		if IS_SERVER and os.clock() >= deadline then
			warn(string.format(
				"PromiseFindFirstChildOfClass: '%s' not found in %s after %.1fs",
				className, parent:GetFullName(), maxTime
				))
			break
		end

		task.wait()
	until result

	-- Cleanup
	if connection.Connected then
		connection:Disconnect()
	end

	return result
end