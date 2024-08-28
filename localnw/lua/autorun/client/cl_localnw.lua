local StringTable = LocalNW.StringTable
local StringTable_bits = StringTable.bits
net.Receive("LocalNW_UpdateStringTable", function()
	local start = net.ReadUInt(StringTable_bits)
	local to = net.ReadUInt(StringTable_bits)
	for k=start, to do
		local key = net.ReadString()
		StringTable.norm[k] = key
		StringTable.rev[key] = k
	end
	StringTable.count = to
end)

local IDType = LocalNW.IDType
local ReadType = LocalNW.ReadType
local TypeBits = LocalNW.TypeBits
local DataTable = LocalNW.DataTable
local GetStringFromIndexTable = LocalNW.GetStringFromIndexTable
net.Receive("LocalNW_UpdateVar", function()
	local count = net.ReadUInt(StringTable_bits)
	for k=1, count do
		local key = GetStringFromIndexTable(net.ReadUInt(StringTable_bits))
		local type = IDType[net.ReadUInt(TypeBits)]
		DataTable[key] = {
			type = type,
			value = ReadType[type]()
		}

		hook.Run("LocalNWUpdateVar", key)
	end
end)

--[[
	Meta functions
	ToDo: Add type checks?
]]
local meta = FindMetaTable("Player")
function meta:GetLocalNWString(key, fallback)
	fallback = fallback or ""

	local data = DataTable[key]
	if !data then return fallback end

	return data.value or fallback
end

function meta:GetLocalNWBool(key, fallback)
	fallback = fallback or false

	local data = DataTable[key]
	if !data then return fallback end

	return data.value or fallback
end

function meta:GetLocalNWEntity(key, fallback)
	fallback = fallback or NULL

	local data = DataTable[key]
	if !data then return fallback end

	return data.value or fallback
end

local vec = Vector(0, 0, 0)
function meta:GetLocalNWVector(key, fallback)
	fallback = fallback or vec

	local data = DataTable[key]
	if !data then return fallback end

	return data.value or fallback
end

local ang = Angle(0, 0, 0)
function meta:GetLocalNWAngle(key, fallback)
	fallback = fallback or ang

	local data = DataTable[key]
	if !data then return fallback end

	return data.value or fallback
end

function meta:GetLocalNWFloat(key, fallback)
	fallback = fallback or 0

	local data = DataTable[key]
	if !data then return fallback end

	return data.value or fallback
end

function meta:GetLocalNWInt(key, fallback)
	fallback = fallback or 0

	local data = DataTable[key]
	if !data then return fallback end

	return data.value or fallback
end