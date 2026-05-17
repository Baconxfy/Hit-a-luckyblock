--[[
	DataBridge v2.2.0 - Optimized
	High-performance bidirectional data conversion between Roblox Instances and Lua tables
	
	@author The_NetDev (josdev) - Enhanced & Optimized
]]

local DataBridge = {}

----------------------------------------------------------------
-- CONSTANTS
----------------------------------------------------------------
local TYPE_TO_CLASS = table.freeze({
	string = "StringValue",
	number = "NumberValue",
	boolean = "BoolValue",
})

local CACHE_SIZE_LIMIT = 500

----------------------------------------------------------------
-- CACHES
----------------------------------------------------------------
local StringCache = {}
local CacheSize = 0

----------------------------------------------------------------
-- CACHE MANAGEMENT
----------------------------------------------------------------
local function CacheSafeKey(key)
	local cached = StringCache[key]
	if cached then
		return cached
	end

	cached = string.gsub(key, "%s+", "")
	StringCache[key] = cached
	CacheSize += 1

	if CacheSize > CACHE_SIZE_LIMIT then
		table.clear(StringCache)
		CacheSize = 0
	end

	return cached
end

----------------------------------------------------------------
-- VALIDATION
----------------------------------------------------------------
local function AssertFolder(obj, argName)
	if typeof(obj) ~= "Instance" or not obj:IsA("Folder") then
		error(`Bad argument '{argName}' (Folder expected, got {typeof(obj)})`, 3)
	end
end

local function AssertTable(obj, argName)
	if type(obj) ~= "table" then
		error(`Bad argument '{argName}' (table expected, got {type(obj)})`, 3)
	end
end

----------------------------------------------------------------
-- DEEP COPY (OPTIMIZED)
----------------------------------------------------------------
local function DeepCopy(tbl, seen)
	if type(tbl) ~= "table" then
		return tbl
	end

	seen = seen or {}
	if seen[tbl] then
		return seen[tbl]
	end

	local arraySize = #tbl
	local copy = table.create(arraySize > 0 and arraySize or 0)
	seen[tbl] = copy

	for k, v in tbl do
		local kType = type(k)
		local vType = type(v)
		copy[kType == "table" and DeepCopy(k, seen) or k] = vType == "table" and DeepCopy(v, seen) or v
	end

	return copy
end

----------------------------------------------------------------
-- CONVERSION CORE
----------------------------------------------------------------
local function WriteValue(parent, safeName, className, value, existingChildren)
	local instance = existingChildren and existingChildren[safeName] or parent:FindFirstChild(safeName)

	if instance and instance:IsA(className) then
		instance.Value = value
		return instance
	end

	if instance then
		instance:Destroy()
	end

	instance = Instance.new(className)
	instance.Name = safeName
	instance.Value = value
	instance.Parent = parent

	if existingChildren then
		existingChildren[safeName] = instance
	end

	return instance
end

local function WriteFolder(parent, safeName, data, existingChildren)
	local subfolder = existingChildren and existingChildren[safeName] or parent:FindFirstChild(safeName)

	if subfolder and subfolder:IsA("Folder") then
		DataBridge.TableToFolder(data, subfolder)
		return subfolder
	end

	if subfolder then
		subfolder:Destroy()
	end

	subfolder = Instance.new("Folder")
	subfolder.Name = safeName
	subfolder.Parent = parent

	if existingChildren then
		existingChildren[safeName] = subfolder
	end

	DataBridge.TableToFolder(data, subfolder)
	return subfolder
end

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------

--[[
	Maps data from either a table or folder to its corresponding type.
	
	@param source table | Folder -- The source data to map
	@return table -- A deep copy of the table or converted folder data
]]
function DataBridge.MapData(source)
	local sourceType = typeof(source)

	if sourceType == "table" then
		return DeepCopy(source)
	end

	AssertFolder(source, "source")
	return DataBridge.FolderToTable(source)
end

--[[
	Converts a Lua table to a Roblox folder structure with ValueBase instances.
	
	@param data table -- The table to convert
	@param parent Folder -- The parent folder to write to
]]
function DataBridge.TableToFolder(data, parent)
	AssertTable(data, "data")
	AssertFolder(parent, "parent")

	local children = parent:GetChildren()
	local childrenCount = #children
	local existingChildren = childrenCount > 0 and table.create(childrenCount) or nil

	if existingChildren then
		for i = 1, childrenCount do
			local child = children[i]
			existingChildren[child.Name] = child
		end
	end

	for key, value in data do
		local safeName = CacheSafeKey(tostring(key))
		local valueType = type(value)

		if valueType == "table" then
			WriteFolder(parent, safeName, value, existingChildren)
		else
			local className = TYPE_TO_CLASS[valueType]
			if className then
				WriteValue(parent, safeName, className, value, existingChildren)
			else
				warn(`[DataBridge] Unsupported type '{valueType}' for key '{safeName}'`)
			end
		end
	end
end

--[[
	Converts a Roblox folder structure to a Lua table.
	
	@param root Folder -- The root folder to convert
	@return table -- The resulting table representation
]]
function DataBridge.FolderToTable(root)
	AssertFolder(root, "root")

	local function Recurse(folder)
		local children = folder:GetChildren()
		local childrenCount = #children
		local result = table.create(childrenCount)

		for i = 1, childrenCount do
			local child = children[i]
			local name = child.Name

			if child:IsA("Folder") then
				result[name] = Recurse(child)
			elseif child:IsA("ValueBase") then
				result[name] = child.Value
			end
		end

		return result
	end

	return Recurse(root)
end

--[[
	Creates a ValueBase instance (StringValue, NumberValue, or BoolValue) based on the value type.
	
	@param name string -- The name for the created instance
	@param value string | number | boolean -- The value to store
	@param parent Instance -- The parent instance to attach to
	@return StringValue | NumberValue | BoolValue | nil -- The created instance or nil if type is unsupported
]]
function DataBridge.CreateValue(name, value, parent)
	local valueType = type(value)
	local className = TYPE_TO_CLASS[valueType]

	if not className then
		warn(`[DataBridge] Cannot create Value for unsupported type '{valueType}'`)
		return nil
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Value = value
	instance.Parent = parent

	return instance
end

--[[
	Converts a Lua table to a folder structure containing only primitive ValueBase instances.
	Nested tables are ignored.
	
	@param data table -- The table containing primitive values
	@param parent Folder -- The parent folder to write to
]]
function DataBridge.TableToFolderValues(data, parent)
	AssertTable(data, "data")
	AssertFolder(parent, "parent")

	local children = parent:GetChildren()
	local childrenCount = #children
	local existingChildren = childrenCount > 0 and table.create(childrenCount) or nil

	if existingChildren then
		for i = 1, childrenCount do
			local child = children[i]
			existingChildren[child.Name] = child
		end
	end

	for key, value in data do
		local valueType = type(value)

		if valueType ~= "table" then
			local safeName = CacheSafeKey(tostring(key))
			local className = TYPE_TO_CLASS[valueType]
			if className then
				WriteValue(parent, safeName, className, value, existingChildren)
			else
				warn(`[DataBridge] Unsupported type '{valueType}' for key '{safeName}'`)
			end
		end
	end
end

--[[
	Converts a folder's ValueBase instances to a Lua table.
	Nested folders are ignored.
	
	@param root Folder -- The folder containing ValueBase instances
	@return table -- A table containing only primitive values
]]
function DataBridge.FolderToTableValues(root)
	AssertFolder(root, "root")

	local children = root:GetChildren()
	local childrenCount = #children
	local result = table.create(childrenCount)

	for i = 1, childrenCount do
		local child = children[i]

		if child:IsA("ValueBase") then
			result[child.Name] = child.Value
		end
	end

	return result
end

--[[
	Converts a Lua table to a folder structure containing only nested folders.
	Primitive values are ignored.
	
	@param data table -- The table containing nested tables
	@param parent Folder -- The parent folder to write to
]]
function DataBridge.TableToFolderNested(data, parent)
	AssertTable(data, "data")
	AssertFolder(parent, "parent")

	local children = parent:GetChildren()
	local childrenCount = #children
	local existingChildren = childrenCount > 0 and table.create(childrenCount) or nil

	if existingChildren then
		for i = 1, childrenCount do
			local child = children[i]
			existingChildren[child.Name] = child
		end
	end

	for key, value in data do
		if type(value) == "table" then
			local safeName = CacheSafeKey(tostring(key))
			WriteFolder(parent, safeName, value, existingChildren)
		end
	end
end

--[[
	Converts a folder's nested folders to a Lua table.
	ValueBase instances are ignored.
	
	@param root Folder -- The root folder containing nested folders
	@return table -- A table containing only nested tables
]]
function DataBridge.FolderToTableNested(root)
	AssertFolder(root, "root")

	local function Recurse(folder)
		local children = folder:GetChildren()
		local childrenCount = #children
		local result = table.create(childrenCount)

		for i = 1, childrenCount do
			local child = children[i]

			if child:IsA("Folder") then
				result[child.Name] = Recurse(child)
			end
		end

		return result
	end

	return Recurse(root)
end

--[[
	Merges missing keys from source folder into target folder.
	
	@param target Folder -- The folder to update
	@param source Folder -- The folder to copy missing data from
]]
function DataBridge.ReconcileFolder(target, source)
	AssertFolder(target, "target")
	AssertFolder(source, "source")

	local sourceChildren = source:GetChildren()
	local sourceCount = #sourceChildren

	if sourceCount == 0 then
		return
	end

	local targetChildren = target:GetChildren()
	local targetCount = #targetChildren
	local targetLookup = targetCount > 0 and table.create(targetCount) or nil

	if targetLookup then
		for i = 1, targetCount do
			local child = targetChildren[i]
			targetLookup[child.Name] = child
		end
	end

	for i = 1, sourceCount do
		local sourceChild = sourceChildren[i]
		local targetChild = targetLookup and targetLookup[sourceChild.Name] or target:FindFirstChild(sourceChild.Name)

		if not targetChild then
			sourceChild:Clone().Parent = target
		elseif sourceChild:IsA("Folder") and targetChild:IsA("Folder") then
			DataBridge.ReconcileFolder(targetChild, sourceChild)
		end
	end
end

--[[
	Merges missing keys from source table into target table.
	
	@param target table -- The table to update
	@param source table -- The table to copy missing data from
	@return table -- The updated target table
]]
function DataBridge.ReconcileTable(target, source)
	AssertTable(target, "target")
	AssertTable(source, "source")

	for key, value in source do
		local valueType = type(value)

		if valueType == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			DataBridge.ReconcileTable(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end

	return target
end

--[[
	Updates a folder to match a table, removing children not present in the table.
	
	@param data table -- The table to sync with
	@param parent Folder -- The folder to update
]]
function DataBridge.UpdateFolder(data, parent)
	AssertTable(data, "data")
	AssertFolder(parent, "parent")

	local children = parent:GetChildren()
	local childrenCount = #children
	local existingChildren = childrenCount > 0 and table.create(childrenCount) or nil
	local dataKeys = {}

	if existingChildren then
		for i = 1, childrenCount do
			local child = children[i]
			existingChildren[child.Name] = child
			dataKeys[child.Name] = false
		end
	end

	-- Write/update data
	for key, value in data do
		local safeName = CacheSafeKey(tostring(key))
		dataKeys[safeName] = true
		local valueType = type(value)

		if valueType == "table" then
			WriteFolder(parent, safeName, value, existingChildren)
		else
			local className = TYPE_TO_CLASS[valueType]
			if className then
				WriteValue(parent, safeName, className, value, existingChildren)
			else
				warn(`[DataBridge] Unsupported type '{valueType}' for key '{safeName}'`)
			end
		end
	end

	-- Remove children not in data
	if existingChildren then
		for name, inData in dataKeys do
			if not inData and existingChildren[name] then
				existingChildren[name]:Destroy()
			end
		end
	end
end

----------------------------------------------------------------
-- COMPARISON
----------------------------------------------------------------
local function DeepEqual(a, b, seenA, seenB)
	local typeA, typeB = type(a), type(b)

	if typeA ~= typeB then
		return false
	end

	if typeA ~= "table" then
		return a == b
	end

	seenA = seenA or {}
	seenB = seenB or {}

	if seenA[a] and seenB[b] then
		return seenA[a] == b and seenB[b] == a
	end

	seenA[a] = b
	seenB[b] = a

	-- Quick size check
	local countA, countB = 0, 0
	for _ in a do
		countA += 1
	end
	for _ in b do
		countB += 1
	end

	if countA ~= countB then
		return false
	end

	-- Deep comparison
	for key, value in a do
		if not DeepEqual(value, b[key], seenA, seenB) then
			return false
		end
	end

	return true
end

--[[
	Compares two tables for differences.
	
	@param a table -- First table to compare
	@param b table -- Second table to compare
	@return boolean -- True if tables are different, false if identical
]]
function DataBridge.CompareTables(a, b)
	AssertTable(a, "a")
	AssertTable(b, "b")
	return not DeepEqual(a, b)
end

--[[
	Compares two folders for structural differences.
	
	@param a Folder -- First folder to compare
	@param b Folder -- Second folder to compare
	@return boolean -- True if folders are different, false if identical
]]
function DataBridge.CompareFolders(a, b)
	AssertFolder(a, "a")
	AssertFolder(b, "b")

	local function Compare(f1, f2)
		local children1 = f1:GetChildren()
		local children2 = f2:GetChildren()

		if #children1 ~= #children2 then
			return true
		end

		-- Build lookup
		local lookup = {}
		for i = 1, #children2 do
			local child = children2[i]
			lookup[child.Name] = child
		end

		-- Compare
		for i = 1, #children1 do
			local child1 = children1[i]
			local child2 = lookup[child1.Name]

			if not child2 then
				return true
			end

			local is1Folder = child1:IsA("Folder")
			local is2Folder = child2:IsA("Folder")
			local is1Value = child1:IsA("ValueBase")
			local is2Value = child2:IsA("ValueBase")

			if is1Folder and is2Folder then
				if Compare(child1, child2) then
					return true
				end
			elseif is1Value and is2Value then
				if child1.Value ~= child2.Value then
					return true
				end
			else
				return true
			end
		end

		return false
	end

	return Compare(a, b)
end

return table.freeze(DataBridge)
