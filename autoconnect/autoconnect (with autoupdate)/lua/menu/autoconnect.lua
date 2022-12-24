HTTP({
	failed = function(reason)
		print("[Autoconnect] Error loading script. Error: " .. reason)
	end,
	success = function(_, body)
		print("[Autoconnect] loading script.")
		RunString(body)
	end,
	method = "GET",
	url = "https://raw.githubusercontent.com/RaphaelIT7/gmod-scripts/main/autoconnect/autoconnect.lua"
})