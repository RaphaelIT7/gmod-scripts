--[[
	How to install:
		1. Copy this file into the garrysmod/lua/menu folder
		2. Open the menu.lua located in the garrysmod/lua/menu folder.
		3. Add the following line to the menu.lua file:
			include( "autoconnect.lua" )
		4. Start Garry's Mod and enjoy using this script.

	Commands:
		autoconnect [ip] [password]

	Values (ConVars):
		autoconnect_maxretrys 1000
		autoconnect_checkspeed 10  amount of seconds to wait before checking inf you're successfully connected to the server.
		autoconnect_retryspeed 0.1 amount of seconds to wait before connecting to the server.
]]
local lastip = ""

local retrys = 0
local retrydelay = 0 -- additional retry delay if youre too fast for the server.
local maxretry = CreateClientConVar("autoconnect_maxretrys", "1000", true, false, "The amount of retries before stopping completely", 0, 2000000)
local checkspeed = CreateClientConVar("autoconnect_checkspeed", "10", true, false, "The amount of time (in seconds) to wait before checking if the client successfully connected to the server. Increase this value if you're getting reconnected while you're joining the server.", 0, 2000000)
local retryspeed = CreateClientConVar("autoconnect_retryspeed", "0.1", true, false, "The amount of time (in seconds) to wait before retrying", 0, 2000000)
function PingServer_Retry(address, bool)
	if retrys >= maxretry:GetInt() then
		print("[Autoconnect] Stopped joining the server because the retry limit has been reached. (can be changes with 'autoconnect_maxretrys " .. maxretry:GetFloat() + 50 .. "')")
		return
	end

	if bool then
		print("[Autoconnect] failed to connect to server. Retrying")
	end

	if input.IsKeyDown(KEY_ESCAPE) or input.WasKeyPressed(KEY_ESCAPE) then
		print("[Autoconnect] Retry canceled by user.")
		return
	end

	timer.Simple(math.Round(retryspeed:GetFloat(), 2) + retrydelay, function()
		serverlist.PingServer(address or lastip, PingServer_CallBack)
	end)
end

function PingServer_CallBack(ping, name, desc, map, players, maxplayers, botplayers, pass, lastplayed, address, gamemode, workshopid, isanon, version, localization, gmcategory)
	retrys = retrys + 1
	if !ping then
		print("[Autoconnect] Reached Ping limit or Server shutdown. Waiting 5 Seconds.")
		print("[Autoconnect] failed to connect to server. Slowing retry speed from " .. math.Round(retryspeed:GetFloat(), 2) + retrydelay .. " to " .. math.Round(retryspeed:GetFloat(), 2) + retrydelay + 0.1)
		retrydelay = retrydelay + 0.1
		timer.Simple(5, function()
			PingServer_Retry()
		end)
		return
	end

	if pass then
		print("[Autoconnect] failed to connect to server. Autoconnect doesn't work for server with passwords.")
		return
	end

	if players < maxplayers then
		JoinServer(address)
		timer.Simple(checkspeed:GetInt(), function()
			serverlist.PlayerList(address, function(players)
				local hostname = GetConVar("name"):GetString()
				for k, v in ipairs(players) do
					if v["name"] == hostname then
						lastip = address
						print("[Autoconnect] Successfully connected to server")
						return
					end
				end

				PingServer_Retry(address, true)
			end)
		end)
	else
		PingServer_Retry(address)
	end
end

concommand.Add("autoconnect", function(_, _, args)
	print(args[1], args[2], args[3], args[4])
	print(args[2] == ":", isnumber(args[3]))
	print(type(args[3]))
	if args[2] == ":" then
		args[1] = args[1] .. args[2] .. args[3]
		args[3] = nil
		args[2] = args[4]
	end
	ip = args[1] or lastip
	if !ip or ip == "" then return end

	print("[Autoconnect] You're going to be connected to the following server: " .. ip)
	print("[Autoconnect] Current retrys on fail: " .. maxretry:GetInt() .. " (can be changed with 'autoconnect_maxretrys " .. maxretry:GetInt() + 50 .. "')")
	print("")
	print("[Autoconnect] You can stop this script by holding ESC whiel its running.")
	serverlist.PingServer(ip, function(ping, name, desc, map, players, maxplayers, botplayers, pass)
		if !ping then
			print("[Autoconnect] failed to get server information. Is the entered IP correct? IP: " .. ip)
			return
		end

		print("Servername: " .. name)
		print("Serverdescription: " .. desc)
		print("Ping: " .. ping)
		print("Map: " .. map)
		print("Players: " .. players .. "/" .. maxplayers)
		print("")

		if pass then
			RunConsoleCommand("password", args[2])
			print("[Autoconnect] This script doesn't work for servers using a password.")
			return
		else
			print("[Autoconnect] Connecting in 5 Seconds")
		end

		retrys = 0
		retrydelay = 0

		timer.Simple(5, function()
			print("[Autoconnect] Connecting to server")
			lastip = ip
			serverlist.PingServer(ip, PingServer_CallBack)
		end)
	end)
end)

print("[Autoconnect] Successfully loaded.")
print("[Autoconnect] Created by: RaphaelIT7 (https://github.com/RaphaelIT7/gmod-scripts)")