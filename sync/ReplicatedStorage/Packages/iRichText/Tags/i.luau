-- Italic tag (from Richify)
return {
	Letterwise = false,
	Attributes = {},
	Apply = function(Label: TextLabel, _: { [string]: string }): { RBXScriptConnection }
		Label.RichText = true
		Label.Text = "<i>" .. Label.Text .. "</i>"
		return {}
	end,
}
