if SERVER then
	SetGlobal2Bool("IsDedicated", game.IsDedicated())
else
	game.OldIsDedicated = game.IsDedicated
	function game.IsDedicated()
		return GetGlobal2Bool("IsDedicated")
	end
end