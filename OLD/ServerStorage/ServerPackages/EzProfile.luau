--[[
	
░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░
	
	ProfileStore API:
	https://madstudioroblox.github.io/ProfileStore/api/

]]

-- ============================================================================
-- SERVICES and DEPENDENCIES
-- ============================================================================
local Players = game:GetService("Players")

local ProfileStore = require("@self/Modules/ProfileStore")
local DataBridge = require("@self/Modules/DataBridge")
local Template = require("@self/Template")

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local CONFIG = table.freeze({
	STORE_NAME = "PlayersData",
	TEST_ENV = false,
	
	MAKE_FOLDERS = true,
	FOLDERS_NAME = "Data",
	FOLDERS_PARENT = nil,
})


-- ============================================================================
-- CONSTANTS
-- ============================================================================
local KICK_ERRORS = table.freeze({
	SESSION_ENDED = "Profile session end - Please rejoin",
	LOAD_FAILED = "Profile load fail - Please rejoin",
})


-- ============================================================================
-- TYPES
-- ============================================================================
export type ProfileType = typeof(ProfileStore.New():StartSessionAsync())

-- ============================================================================
-- PRIVATE STATE
-- ============================================================================
local _initialized = false
local _store = ProfileStore.New(CONFIG.STORE_NAME, Template)
local _profiles: { [Player]: typeof(ProfileStore.New():StartSessionAsync()) } = {}
local _profileFolders: { [Player]: Folder } = {}

-- ============================================================================
-- PRIVATE UTILITY FUNCTIONS
-- ============================================================================
local function ExecuteCallback(callback: () -> (), ...): ()
	if callback then
		local success, err = pcall(callback, ...)
		if not success then
			warn(`[{script.Name} CALLBACK ERROR]:`, err)
		end
	end
end

local function CreateFolder(player: Player): Folder
	local name = CONFIG.FOLDERS_NAME or "leaderstats"

	if name == "Player.Id" then
		name = tostring(player.UserId)
	elseif name == "Player.Name" then
		name = player.Name
	end

	local folder = Instance.new("Folder")
	folder.Name = name

	return folder
end

-- ============================================================================
-- MODULE DEFINITION
-- ============================================================================
local module = {}
module._callbacks = {}
module.ProfileStore = ProfileStore
module.Utils = DataBridge
module.Store = _store

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--[[
	Initializes the DataWrapper module and sets up event handlers for player connections.
	
	This method must be called once before the module can be used. It connects to
	PlayerAdded and PlayerRemoving events to manage profile sessions and folders.
	Processes existing players that joined before initialization.
	
	@throws error if already initialized
]]
function module:Init()
	assert(not _initialized, `{script.Name} is already initialized`)
	_initialized = true

	local OnPlayerAdded = self._callbacks.CustomPlayerAdded
		or function(player: Player)
			local profile = self:_StartProfileSession(player)
			if profile then
				self:_SetupProfile(player, profile)
			end
		end

	local OnPlayerRemoving = self._callbacks.CustomPlayerLeaving
		or function(player: Player)
			local profile = _profiles[player]
			if profile then
				profile:EndSession()
			end
		end

	for _, player in Players:GetPlayers() do
		task.spawn(OnPlayerAdded, player)
	end

	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)
end

-- ============================================================================
-- PRIVATE METHODS
-- ============================================================================

--[[
	Starts a profile session for the given player.
	
	Creates a new profile session using ProfileStore, either from the mock store
	(in test environment) or the main store. Handles session cancellation if the
	player leaves during the process. Kicks the player if session creation fails.
	
	@param Player Player -- The player to start a profile session for
	@return typeof(ProfileStore.New():StartSessionAsync())? -- The profile session, or nil if failed
	@throws error if profile already exists for this player
]]
function module:_StartProfileSession(Player: Player): typeof(ProfileStore.New():StartSessionAsync())?
	assert(not _profiles[Player], `{Player.Name} profile already created and registered`)

	local profile = CONFIG.TEST_ENV
		and _store.Mock:StartSessionAsync(tostring(Player.UserId), {
			Cancel = function()
				return not Player:IsDescendantOf(Players)
			end,
		})
		or _store:StartSessionAsync(tostring(Player.UserId), {
			Cancel = function()
				return not Player:IsDescendantOf(Players)
			end,
		})

	if not profile then
		Player:Kick(KICK_ERRORS.LOAD_FAILED)
		return nil
	end

	return profile
end

--[[
	Creates a profile folder for the given player if folder creation is enabled.
	
	Creates a folder instance based on configuration, invokes the FillFolder callback,
	and assigns it to the configured parent. Returns nil if folder creation is disabled.
	
	@param Player Player -- The player to create a folder for
	@param Profile typeof(ProfileStore.New():StartSessionAsync()) -- The player's profile
	@return Folder? -- The created folder, or nil if folder creation is disabled
]]
function module:_CreateProfileFolder(Player: Player, Profile: typeof(ProfileStore.New():StartSessionAsync())): Folder?
	if not CONFIG.MAKE_FOLDERS then
		return nil
	end

	local folder = CreateFolder(Player)
	ExecuteCallback(self._callbacks.FillFolder, Player, Profile, folder)
	folder.Parent = CONFIG.FOLDERS_PARENT or Player
	_profileFolders[Player] = folder

	return folder
end

--[[
	Cleans up profile data and folder for the given player.
	
	Removes the profile from the profiles table and destroys the associated folder
	if it exists. Used when a profile session ends or during cleanup operations.
	
	@param Player Player -- The player whose profile should be cleaned up
]]
function module:_CleanupProfile(Player: Player): ()
	_profiles[Player] = nil

	local folder = _profileFolders[Player]
	if folder then
		folder:Destroy()
		_profileFolders[Player] = nil
	end
end

--[[
	Sets up a profile session after it has been successfully created.
	
	Configures the profile with user ID (GDPR compliance) and reconciles with the
	template. Connects session end handler and creates the profile folder if enabled.
	Invokes OnProfileSetup and OnDataLoaded callbacks. Ends the session if the player
	has already left.
	
	@param Player Player -- The player whose profile is being set up
	@param Profile typeof(ProfileStore.New():StartSessionAsync()) -- The profile to set up
	@return boolean? -- True if setup was successful, nil if player left before setup
]]
function module:_SetupProfile(Player: Player, Profile: typeof(ProfileStore.New():StartSessionAsync())): boolean?
	Profile:AddUserId(Player.UserId) -- GDPR compliance
	Profile:Reconcile() -- Fill in missing variables from PROFILE_TEMPLATE

	Profile.OnSessionEnd:Connect(function()
		self:_CleanupProfile(Player)
		Player:Kick(KICK_ERRORS.SESSION_ENDED)
	end)

	if not Player:IsDescendantOf(Players) then
		Profile:EndSession()
		return nil
	end

	_profiles[Player] = Profile
	local profileFolder: Folder? = self:_CreateProfileFolder(Player, Profile)

	ExecuteCallback(self._callbacks.OnProfileSetup, Player, Profile, profileFolder)
	ExecuteCallback(self._callbacks.OnDataLoaded, Player, Profile, profileFolder)

	return true
end

-- ============================================================================
-- CALLBACK REGISTRATION METHODS
-- ============================================================================

--[[
	Registers a custom callback function to handle player addition.
	
	If provided, this callback replaces the default player addition handler.
	The callback should handle profile session creation and setup.
	
	@param Callback function -- Callback function that receives (Player)
]]
function module:CustomPlayerAdded(Callback: (Player: Player) -> ())
	self._callbacks.CustomPlayerAdded = Callback
end

--[[
	Registers a custom callback function to handle player removal.
	
	If provided, this callback replaces the default player removal handler.
	The callback should handle profile session cleanup.
	
	@param Callback function -- Callback function that receives (Player)
]]
function module:CustomPlayerLeaving(Callback: (Player: Player) -> ())
	self._callbacks.CustomPlayerLeaving = Callback
end

--[[
	Registers a callback function to be invoked when filling a profile folder with data.
	
	This callback is called when a folder is created for a player's profile,
	allowing you to populate the folder with initial data or structure.
	
	@param Callback function -- Callback function that receives (Player, Profile, ProfileFolder)
]]
function module:FillFolder(Callback: (Player: Player, Profile: typeof(ProfileStore.New():StartSessionAsync()), ProfileFolder: Folder) -> ())
	self._callbacks.FillFolder = Callback
end

--[[
	Registers a callback function to be invoked when a profile has been set up.
	
	This callback is called after a profile has been successfully created, configured,
	and the folder has been created (if enabled). Use this for post-setup operations.
	
	@param Callback function -- Callback function that receives (Player, Profile, ProfileFolder?)
]]
function module:OnProfileSetup(Callback: (Player: Player, Profile: typeof(ProfileStore.New():StartSessionAsync()), ProfileFolder: Folder?) -> ())
	self._callbacks.OnProfileSetup = Callback
end

--[[
	Registers a callback function to be invoked when player data has been loaded.
	
	This callback is called after the profile setup is complete, indicating that
	the player's data is ready to use. This is the final step in the loading process.
	
	@param Callback function -- Callback function that receives (Player, Profile, ProfileFolder?)
]]
function module:OnDataLoaded(Callback: (Player: Player,Profile: typeof(ProfileStore.New():StartSessionAsync()), ProfileFolder: Folder?) -> ())
	self._callbacks.OnDataLoaded = Callback
end

-- ============================================================================
-- DATA RETRIEVAL METHODS
-- ============================================================================

--[[
	Retrieves the profile session for a specific player.
	
	@param Player Player -- The player to get the profile for
	@return typeof(ProfileStore.New():StartSessionAsync())? -- The player's profile session, or nil if not found
]]
function module:GetProfile(Player: Player): typeof(ProfileStore.New():StartSessionAsync())?
	return _profiles[Player]
end

--[[
	Retrieves the profile folder for a specific player.
	
	@param Player Player -- The player to get the folder for
	@return Folder? -- The player's profile folder, or nil if not found or folders are disabled
]]
function module:GetProfileFolder(Player: Player): Folder?
	return _profileFolders[Player]
end

--[[
	Retrieves all active player profiles.
	
	@return {[Player]: typeof(ProfileStore.New():StartSessionAsync())} -- Dictionary mapping players to their profile sessions
]]
function module:GetPROFILES()
	return _profiles
end

--[[
	Retrieves all active player profile folders.
	
	@return {[Player]: Folder} -- Dictionary mapping players to their profile folders
]]
function module:GetFOLDERS()
	return _profileFolders
end

return module
