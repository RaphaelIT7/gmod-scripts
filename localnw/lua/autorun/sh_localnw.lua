LocalNW = LocalNW or {}
LocalNW.DataTable = LocalNW.DataTable or {}
LocalNW.StringTable = LocalNW.StringTable or {
	norm = {},
	rev = {},
	players = {},
	update = false,
	count = 0,
	bits = 16
}
LocalNW.StringTable.max = 2^LocalNW.StringTable.bits
LocalNW.TypeBits = 3 -- 0-7
LocalNW.TypeID = {
	["string"] = 1,
	["boolean"] = 2,
	["entity"] = 3,
	["vector"] = 4,
	["angle"] = 5,
	["float"] = 6,
	["int"] = 7,
}
LocalNW.IDType = {
	"string",
	"boolean",
	"entity",
	"vector",
	"angle",
	"float",
	"int",
}
LocalNW.WriteType = {
	["string"] = net.WriteString,
	["boolean"] = net.WriteBool,
	["entity"] = net.WriteEntity,
	["vector"] = net.WriteVector,
	["angle"] = net.WriteAngle,
	["float"] = net.WriteFloat,
	["int"] = function(int) net.WriteInt(int, 32) end,
}
LocalNW.ReadType = {
	["string"] = net.ReadString,
	["boolean"] = net.ReadBool,
	["entity"] = net.ReadEntity,
	["vector"] = net.ReadVector,
	["angle"] = net.ReadAngle,
	["float"] = net.ReadFloat,
	["int"] = function() return net.ReadInt(32) end,
}

--[[
	Shared Stringtable function
]]
local StringTable = LocalNW.StringTable
function LocalNW.GetStringFromIndexTable(idx)
	return StringTable.norm[idx]
end

function LocalNW.GetIndexFromStringTable(key)
	return StringTable.rev[key]
end