local rig = script.Parent
local controller = rig:FindFirstChildOfClass("AnimationController")
local animator = controller and controller:FindFirstChildOfClass("Animator")
local anim = rig:FindFirstChild("Animation")
if animator and anim then
	local track = animator:LoadAnimation(anim)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play()
end
