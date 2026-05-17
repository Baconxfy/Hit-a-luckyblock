--!strict

--[[


░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

--[[
	- Lazy loading for optimal performance
	- Cyclic dependency protection
	- Eager loading for yielding modules
	- Full type safety
]]

-- 🔒 Type definitions for autocomplete
type GuiLibrary = {

	Button: typeof(require(script.Button)),
	Filter: typeof(require(script.Filter)),

}

-- 🧠 Cache table to store required modules
-- Prevents multiple requires and handles cyclic dependencies safely
local cache: { [string]: any } = {}

-- 📊 Optional: Track module load times for debugging
local DEBUG_MODE = false
local loadTimes: { [string]: number } = {}

-- 🧩 Proxy table for lazy-loading modules on first access
local Tbl = {} :: any
setmetatable(Tbl, {
	__index = function(_, key: string)
		if cache[key] == nil then
			local startTime = if DEBUG_MODE then os.clock() else 0

			local ms = script:FindFirstChild(key)
			assert(
				ms and ms:IsA("ModuleScript"),
				string.format("%s: '%s' module not found or is not a ModuleScript", script.Name, key)
			)

			-- Insert placeholder to break cyclic requires
			cache[key] = {}

			local ok, result = pcall(require, ms)
			if not ok then
				-- Clean up cache on error to allow retry
				cache[key] = nil
				error(string.format("Failed to load module '%s': %s", key, result), 2)
			end

			cache[key] = result

			-- Track load time in debug mode
			if DEBUG_MODE then
				local loadTime = os.clock() - startTime
				loadTimes[key] = loadTime
				if loadTime > 0.1 then
					warn(string.format("⚠️ Module '%s' took %.3f seconds to load", key, loadTime))
				end
			end
		end
		return cache[key]
	end,

	-- Prevent accidental modification
	__newindex = function(_, key: string, _)
		error(string.format("Cannot assign to module loader (attempted to set '%s')", key), 2)
	end,
})

-- ⚡ Eager-load modules known to yield at top-level
-- Also safe for cyclic dependencies
local eagerLoad = { }

for _, name in ipairs(eagerLoad) do
	local ms = script:FindFirstChild(name)
	if ms and ms:IsA("ModuleScript") then
		-- Insert placeholder then require
		cache[name] = {}
		local ok, result = pcall(require, ms)
		if ok then
			cache[name] = result
			if DEBUG_MODE then
				print(string.format("✅ Eager-loaded: %s", name))
			end
		else
			cache[name] = nil
			warn(string.format("⚠️ Failed to eager-load '%s': %s", name, result))
		end
	else
		warn(string.format("⚠️ Eager-load target '%s' not found or is not a ModuleScript", name))
	end
end

-- 📊 Debug utility: Print load statistics
if DEBUG_MODE then
	task.defer(function()
		task.wait(5) -- Wait for initial loading
		print("\n📊 Module Load Statistics:")
		local sortedModules = {}
		for name, time in pairs(loadTimes) do
			table.insert(sortedModules, { name = name, time = time })
		end
		table.sort(sortedModules, function(a, b)
			return a.time > b.time
		end)
		for _, data in ipairs(sortedModules) do
			print(string.format("  %s: %.3fs", data.name, data.time))
		end
	end)
end

-- ✅ Export the proxy table with explicit type
local module: GuiLibrary = Tbl
return module
