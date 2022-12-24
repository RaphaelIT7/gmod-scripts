--[[
	autoconnect:
		This script willl automaticly connect you to the server as soon as a slot is available.

	Commands:
		autoconnect [ip] [password]

	ConVars:
		autoconnect_maxretrys (default: 1000)
			The amount of retries before stopping completely   

		autoconnect_checkspeed (default: 10)
			The amount of time (in seconds) to wait before checking if the client successfully connected to the server. Increase this value if you're getting reconnected while you're joining the server.  

		autoconnect_retryspeed (default: 0.1)
			The amount of time (in seconds) to wait before retrying

	how to install:
		1. Decide which Script you want to use. autoconnect (with autoupdate) or autoconnect (without autoupdate).
		2. Open the garrysmod folder
		3. Copy all files/folders located in the selected autoconnect into the garrysmod folder. 
		4. Start Garry's Mod and check if anything works.

	Created by: Raphael(https://github.com/RaphaelIT7)
]]
HTTP({
	failed = function(reason)
		print("[Autoconnect] Error loading script. Error: " .. reason)
	end,
	success = function(_, body)
		print("[Autoconnect] loading script.")
		RunString(body)
	end,
	method = "GET",
	url = "https://github.com/RaphaelIT7/gmod-scripts/blob/main/autoconnect/autoconnect%20(without%20autoupdate)/lua/menu/autoconnect.lua"
})