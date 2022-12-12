--[[
	This script solves the CurTime's lack of precision

	https://github.com/Facepunch/garrysmod-issues/issues/2502
]]
if SERVER then
	hook.Add("Think", "Engine_TickCount", function()
		SetGlobal2Int("engine_tickcount", engine.TickCount())
	end)

	function CurTime()
		return engine.TickCount() / math.floor(1 / engine.TickInterval())
	end
else
	engine.OldTickCount = engine.TickCount
	function engine.TickCount()
		return GetGlobal2Int("engine_tickcount", 0)
	end

	OldCurTime = CurTime
	function CurTime()
		return engine.TickCount() / math.floor(1 / engine.TickInterval())
	end
end