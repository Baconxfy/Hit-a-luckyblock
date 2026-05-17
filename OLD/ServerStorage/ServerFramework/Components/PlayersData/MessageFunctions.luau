local ServerStorage = game:GetService("ServerStorage")
local EzProfile = require(ServerStorage.ServerPackages.EzProfile)

local module = {}

module["Test2"] = function(...)
	print("Test Message Function, Params:", ...)
end

return module
