--< Workspace Variable
local Plots = workspace:WaitForChild("Plots")

--< Constants
local EXTRA_FLOORS_NAME = {"Floor2", "Floor3"}
local SLOTS_NAME = {"Slot1","Slot2","Slot3","Slot4","Slot5","Slot6","Slot7","Slot8","Slot9","Slot10"}

-- Convert to set for O(1) lookup instead of table.find O(n)
local SLOTS_SET = {}
for _, slotName in ipairs(SLOTS_NAME) do
	SLOTS_SET[slotName] = true
end

--< Types
type VisualInstance = BasePart | Texture | Decal

type SlotData = {
	Instances: {VisualInstance},
	OriginalTransparency: {[VisualInstance]: number},
	OriginalCanCollide: {[BasePart]: boolean},
}

type FloorData = {
	Extra: SlotData,
	[string]: SlotData, -- Slot1..Slot10
}

type PlotData = {
	[string]: FloorData, -- Floor2, Floor3
}

--< Helpers
local function createSlotData(): SlotData
	return {
		Instances = {},
		OriginalTransparency = {},
		OriginalCanCollide = {},
	}
end

-- Captures a single instance into the slot data if it's a visual instance
local function captureInstance(inst: Instance, slotData: SlotData)
	if inst:IsA("BasePart") then
		table.insert(slotData.Instances, inst)
		slotData.OriginalTransparency[inst] = inst.Transparency
		slotData.OriginalCanCollide[inst] = inst.CanCollide
	elseif inst:IsA("Texture") or inst:IsA("Decal") then
		table.insert(slotData.Instances, inst)
		slotData.OriginalTransparency[inst] = inst.Transparency
	end
end

-- Captures the container itself AND all of its descendants
local function collectVisuals(container: Instance, slotData: SlotData)
	captureInstance(container, slotData)
	for _, v in ipairs(container:GetDescendants()) do
		captureInstance(v, slotData)
	end
end

local function setSlotVisible(slotData: SlotData, visible: boolean)
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

--< Build Dictionary
local PlotsDictionary: {[Model]: PlotData} = {}

for _, plot in ipairs(Plots:GetChildren()) do
	if not plot:IsA("Model") then continue end

	PlotsDictionary[plot] = {}

	for _, floorName in ipairs(EXTRA_FLOORS_NAME) do
		local floor = plot:FindFirstChild(floorName)
		if not floor then continue end

		local floorData: FloorData = {
			Extra = createSlotData(),
		}
		PlotsDictionary[plot][floorName] = floorData

		-- If the floor itself is a visual instance, treat it as Extra
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

--< Public Functions

local function HideAll(PlotModel: Model)
	local plotData = PlotsDictionary[PlotModel]
	if not plotData then
		warn("[PlotVisibility] Plot not found in dictionary:", PlotModel)
		return
	end

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
	if not plotData then
		warn("[PlotVisibility] Plot not found:", PlotModel)
		return
	end

	local floorData = plotData[FloorName]
	if not floorData then
		warn("[PlotVisibility] Floor not found:", FloorName)
		return
	end

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
	if not plotData then
		warn("[PlotVisibility] Plot not found:", PlotModel)
		return
	end

	local floorData = plotData[FloorName]
	if not floorData then
		warn("[PlotVisibility] Floor not found:", FloorName)
		return
	end

	-- Extra (walls, ceiling, etc.) is always visible when showing a slot from this floor
	setSlotVisible(floorData.Extra, true)

	local slotData = floorData[SlotName]
	if not slotData then
		warn("[PlotVisibility] Slot not found:", SlotName)
		return
	end

	setSlotVisible(slotData, true)
end

return {
	PlotsDictionary = PlotsDictionary,
	HideAll = HideAll,
	ShowFloor = ShowFloor,
	ShowSlot = ShowSlot,
}