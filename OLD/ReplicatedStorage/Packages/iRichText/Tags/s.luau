-- Strikethrough tag (from Richify)
return {
	Letterwise = false,
	Attributes = {},
	Apply = function(Label: TextLabel, _: { [string]: string }): { RBXScriptConnection }
		Label.RichText = true
		Label.Text = "<s>" .. Label.Text .. "</s>"
		return {}
	end,
}
