
local config = {
	--< configs goes here

	
}


for _,v :ModuleScript in pairs(script:GetChildren()) do
	config[v.Name] = require(v)
end

return config