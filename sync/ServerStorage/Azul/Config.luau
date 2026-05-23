return {
	-- TCP port the daemon should be listening on (defaults to 8080 in the CLI config).
	port = 8080,

	-- Emit extra debug logs from the Studio plugin/daemon handshake.
	debugMode = true,

	-- When the daemon connects, delete files in the sync directory that are
	-- not mapped to any instances. Keeps the local mirror clean between sessions.
	deleteOrphansOnConnect = true,

	-- One or more push mappings: each maps a local folder into a DataModel path.
	pushMappings = {


		-- Push mapping; map "src/Server" folder to "ServerScriptService.Server":
		{
			source = "src/ServerScriptService",
			destination = { "ServerScriptService"},
			-- Keep existing children that aren't in this snapshot.
			destructive = false,
		},
		{
			source = "src/ReplicatedStorage",
			destination = { "ReplicatedStorage"},
			destructive = false,
		},
		
	
		
		
	},
}