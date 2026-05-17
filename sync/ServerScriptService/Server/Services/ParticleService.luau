local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local ParticleService = Framework:CreateService("ParticleService")

function ParticleService:Start()
	local partsFolder = workspace:WaitForChild("Partsasdasd", 5)
	if not partsFolder then return end

	local particles = {}
	for _, v in ipairs(partsFolder:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			table.insert(particles, v)
		end
	end
	
	for _, v in ipairs(particles) do
		local emitCount = v:GetAttribute("EmitCount") or 0
		if emitCount > 0 then
			v:Emit(emitCount)
		end
	end
end

return ParticleService
