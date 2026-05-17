-- Font tag with color, size, face (from Richify and RichTextPlus)
return {
	Letterwise = false,
	Attributes = { "color", "size", "face" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Color = Attributes.color
		local Size = Attributes.size
		local Face = Attributes.face

		local Text = Label.Text
		local fontTag = "<font"

		if Color then
			-- Try to parse color (hex, name, or RGB)
			local hexColor = Color
			if not Color:match("^#%x+$") then
				-- If not hex, try as name or convert
				hexColor = Color -- Use directly, RichText will handle it
			end
			fontTag = fontTag .. ' color="' .. hexColor .. '"'
		end

		if Size then
			fontTag = fontTag .. ' size="' .. Size .. '"'
		end

		if Face then
			fontTag = fontTag .. ' face="' .. Face .. '"'
		end

		fontTag = fontTag .. ">"

		Label.RichText = true
		Label.Text = fontTag .. Text .. "</font>"

		return {}
	end,
}
