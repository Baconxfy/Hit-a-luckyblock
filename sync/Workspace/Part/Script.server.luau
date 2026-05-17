local particles  = {}
for _,v in pairs(workspace.Partsasdasd:GetDescendants()) do
	if v:IsA("ParticleEmitter") then
		table.insert(particles, v)
	end
end
for _,v :ParticleEmitter in pairs(particles) do
	v:Emit(v:GetAttribute("EmitCount") or 0)
end