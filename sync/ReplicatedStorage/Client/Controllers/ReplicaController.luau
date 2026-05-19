local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local ReplicaController = Framework:CreateController("ReplicaController")

local function copyPath(path)
	if type(path) == "string" then
		return { path }
	end

	local out = {}
	for i, value in ipairs(path or {}) do
		out[i] = value
	end

	return out
end

local function getPath(root, path)
	local current = root

	for _, key in ipairs(path) do
		if type(current) ~= "table" then
			return nil
		end

		current = current[key]
	end

	return current
end

local function sameValue(a, b)
	if a == b then
		return true
	end

	local okA, encodedA = pcall(function()
		return HttpService:JSONEncode(a)
	end)

	local okB, encodedB = pcall(function()
		return HttpService:JSONEncode(b)
	end)

	return okA and okB and encodedA == encodedB
end

function ReplicaController:Initialize()
	self.DataService = Framework:GetService("DataService")
	self._data = nil
	self._watchers = {}

	self._replica = {
		OnSet = function(_, path, callback)
			return self:_watch(path, callback)
		end,
	}
end

function ReplicaController:Start()
	self:_refresh()

	task.spawn(function()
		while true do
			task.wait(1)
			self:_refresh()
		end
	end)

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
		local services = remotes and remotes:WaitForChild("Services", 30)
		local dataService = services and services:WaitForChild("DataService", 30)
		local events = dataService and dataService:WaitForChild("Events", 30)
		local event = events and events:WaitForChild("DataChanged", 30)

		if event and event:IsA("RemoteEvent") then
			event.OnClientEvent:Connect(function(newData)
				self:_applyData(newData)
			end)
		end
	end)
end

function ReplicaController:GetPlayerData()
	if not self._data then
		self:_refresh()
	end

	return self._data
end

function ReplicaController:GetReplica()
	return self._replica
end

function ReplicaController:_refresh()
	local ok, data = pcall(function()
		return self.DataService:GetData()
	end)

	if ok and data then
		self:_applyData(data)
	end
end

function ReplicaController:_applyData(newData)
	local oldData = self._data
	self._data = newData or {}

	for _, watcher in ipairs(self._watchers) do
		local oldValue = getPath(oldData, watcher.Path)
		local newValue = getPath(self._data, watcher.Path)

		if not sameValue(oldValue, newValue) then
			task.spawn(watcher.Callback, newValue, oldValue)
		end
	end
end

function ReplicaController:_watch(path, callback)
	local watcher = {
		Path = copyPath(path),
		Callback = callback,
	}

	table.insert(self._watchers, watcher)

	return {
		Disconnect = function()
			local index = table.find(self._watchers, watcher)
			if index then
				table.remove(self._watchers, index)
			end
		end,
	}
end

return ReplicaController