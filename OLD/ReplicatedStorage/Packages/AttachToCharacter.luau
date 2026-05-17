--[[ 🎉 Dev(s)
	The_NetDev (josdev)
]]

return function(
	
	Character:Model, 
	ModelsContainer:Instance, 
	BeforeAttach:(Character:Model, ModelsContainer:Instance)->(), 
	AfterAttach:(Character:Model, ModelsContainer:Instance, AllParts:{BasePart})->()
	
)

	ModelsContainer = ModelsContainer:Clone()
	local AllParts = {}
	
	if BeforeAttach then
		BeforeAttach(Character, ModelsContainer)
	end
	
	for _,model in pairs(ModelsContainer:GetChildren()) do
		
		if model:IsA("Model") then

			local attach = model.PrimaryPart
			local charAttach = Character[attach.Name]

			for _, v in pairs(model:GetChildren()) do
				if v:IsA("BasePart") and v ~= attach then
					local offset	= attach.CFrame:ToObjectSpace(v.CFrame)
					v.CFrame		= charAttach.CFrame * offset

					local weld	= Instance.new("Weld")
					weld.Part0		= charAttach
					weld.Part1		= v
					weld.C0			= offset
					weld.Parent		= v

					v.Anchored		= false
					v.CanCollide	= false
					v.Massless		= true
					table.insert(AllParts, v)
				end
				
			end
			
			attach:Destroy()
			
		else
			
			model:Destroy()
			
		end
		
	end
	
	ModelsContainer.Parent = Character
	
	if AfterAttach then
		AfterAttach(Character, ModelsContainer, AllParts)
	end
	
	return {
		Character = Character,
		ModelsContainer = ModelsContainer,
		AllParts = AllParts
	}
	
end
