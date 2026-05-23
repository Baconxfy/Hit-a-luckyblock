local Plots = workspace:WaitForChild("Plots")

local EXTRA_FLOORS_NAME = {"Floor2", "Floor3"}
local SLOTS_NAME = {"Slot1","Slot2","Slot3","Slot4","Slot5","Slot6","Slot7","Slot8","Slot9","Slot10"}

local SLOTS_SET = {}
for _, slotName in ipairs(SLOTS_NAME) do
	SLOTS_SET[slotName] = true
end

local function createSlotData()
	return {
		Instances = {},
		OriginalTransparency = {},
		OriginalCanCollide = {},
	}
end

local function captureInstance(inst: Instance, slotData)
	if inst:IsA("BasePart") then
		table.insert(slotData.Instances, inst)
		slotData.OriginalTransparency[inst] = inst.Transparency
		slotData.OriginalCanCollide[inst] = inst.CanCollide
	elseif inst:IsA("Texture") or inst:IsA("Decal") then
		table.insert(slotData.Instances, inst)
		slotData.OriginalTransparency[inst] = inst.Transparency
	end
end

local function collectVisuals(container: Instance, slotData)
	captureInstance(container, slotData)
	for _, v in ipairs(container:GetDescendants()) do
		captureInstance(v, slotData)
	end
end

local function setSlotVisible(slotData, visible: boolean)
	if visible then
		for _, inst in ipairs(slotData.Instances) do
			inst.Transparency = slotData.OriginalTransparency[inst]
			if inst:IsA("BasePart") then
				inst.CanCollide = slotData.OriginalCanCollide[inst]
			end
		end
	else
		for _, inst in ipairs(slotData.Instances) do
			inst.Transparency = 1
			if inst:IsA("BasePart") then
				inst.CanCollide = false
			end
		end
	end
end

local PlotsDictionary = {}

for _, plot in ipairs(Plots:GetChildren()) do
	if not plot:IsA("Model") then continue end

	PlotsDictionary[plot] = {}

	for _, floorName in ipairs(EXTRA_FLOORS_NAME) do
		local floor = plot:FindFirstChild(floorName)
		if not floor then continue end

		local floorData = {
			Extra = createSlotData(),
		}
		PlotsDictionary[plot][floorName] = floorData

		captureInstance(floor, floorData.Extra)

		for _, item in ipairs(floor:GetChildren()) do
			if SLOTS_SET[item.Name] then
				local slotData = createSlotData()
				floorData[item.Name] = slotData
				collectVisuals(item, slotData)
			else
				collectVisuals(item, floorData.Extra)
			end
		end
	end
end

local function HideAll(PlotModel: Model)
	local plotData = PlotsDictionary[PlotModel]
	if not plotData then return end

	for _, floorData in pairs(plotData) do
		setSlotVisible(floorData.Extra, false)
		for slotName in pairs(SLOTS_SET) do
			local slotData = floorData[slotName]
			if slotData then
				setSlotVisible(slotData, false)
			end
		end
	end
end

local function ShowFloor(PlotModel: Model, FloorName: string)
	local plotData = PlotsDictionary[PlotModel]
	if not plotData then return end

	local floorData = plotData[FloorName]
	if not floorData then return end

	setSlotVisible(floorData.Extra, true)
	for slotName in pairs(SLOTS_SET) do
		local slotData = floorData[slotName]
		if slotData then
			setSlotVisible(slotData, true)
		end
	end
end

local function ShowSlot(PlotModel: Model, FloorName: string, SlotName: string)
	local plotData = PlotsDictionary[PlotModel]
	if not plotData then return end

	local floorData = plotData[FloorName]
	if not floorData then return end

	setSlotVisible(floorData.Extra, true)

	local slotData = floorData[SlotName]
	if not slotData then return end

	setSlotVisible(slotData, true)
end

return {
	PlotsDictionary = PlotsDictionary,
	HideAll = HideAll,
	ShowFloor = ShowFloor,
	ShowSlot = ShowSlot,
}
