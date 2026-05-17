-- ComponentManager
-- Auto-initialises all ModuleScript components inside a given folder.

local ComponentManager = {}

function ComponentManager.InitFolderComponents(folder: Folder)
	for _, child in ipairs(folder:GetDescendants()) do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok then
				if type(result) == "function" then
					result()
				elseif type(result) == "table" and type(result.Init) == "function" then
					result:Init()
				end
			else
				warn("[ComponentManager] Failed to require", child:GetFullName(), "-", result)
			end
		end
	end
end

return ComponentManager
