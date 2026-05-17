-- Shake animation (from zserxue_richtext)
local RunService = game:GetService("RunService")

return {
	Letterwise = true,
	Attributes = { "xmag", "ymag", "speed" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Connections = {}
		local xmag = tonumber(Attributes.xmag) or 3
		local ymag = tonumber(Attributes.ymag) or 3
		local speed = tonumber(Attributes.speed) or 10

		local initialPosition = Label.Position
		local frame = 0

		table.insert(
			Connections,
			RunService.Heartbeat:Connect(function()
				frame = frame + 1
				local xOffset = (math.random() * 2 - 1) * xmag
				local yOffset = (math.random() * 2 - 1) * ymag

				Label.Position = initialPosition + UDim2.new(0, xOffset, 0, yOffset)
			end)
		)

		return Connections
	end,
}
