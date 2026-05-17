local module = {}
module.__index = module

function module.new(DefaultEmitCount:number?)
	local self = setmetatable({}, module)
	self.DefaultEmitCount = DefaultEmitCount or 0
	self.Particles = {}
	return self
end

function module:SetDefaultEmitCount(value:number?)
	self.DefaultEmitCount = value or 0
end

function module:GetParticlesFromInstance(instance:Instance)
	for _,v in pairs(instance:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			table.insert(self.Particles, v)
		end
	end
end

function module:AddParticles(particlesList:{ParticleEmitter})
	for _,v in pairs(particlesList) do
		if v:IsA("ParticleEmitter") then
			table.insert(self.Particles, v)
		end
	end	
end

function module:EmitParticles(emitCount:number?)
	emitCount = emitCount or self.DefaultEmitCount
	self.Particles = self.Particles or {}
	for _,p :ParticleEmitter in pairs(self.Particles) do
		p:Emit(p:GetAttribute("EmitCount") or emitCount)
	end
end

function module:ResetParticles()
	self.Particles = {}
end

function module:CleanupParticles()
	self.Particles = self.Particles or {}
	for _,p :ParticleEmitter in pairs(self.Particles) do
		p:Destroy()
	end
	self.Particles = {}
end

function module:Destroy()
	self:CleanupParticles()
	self = nil
	return nil
end

function module:EmitThenDestroy(DestroyDelay:number?)
	self:EmitParticles()
	task.wait(DestroyDelay or 0)
	self:CleanupParticles()
	self = nil
	return nil
end
