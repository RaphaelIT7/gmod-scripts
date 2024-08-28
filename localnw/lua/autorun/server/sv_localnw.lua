util.AddNetworkString("LocalNW_UpdateVar")
util.AddNetworkString("LocalNW_UpdateStringTable")

local DataTable = LocalNW.DataTable
local StringTable = LocalNW.StringTable
local StringTable_bits = StringTable.bits
local StringTable_norm = StringTable.norm
--[[
	Stringtable functions
]]
local GetIndexFromStringTable = LocalNW.GetIndexFromStringTable
local function AddToStringTable(key)
	if StringTable.rev[key] then return end

	StringTable.count = StringTable.count + 1

	local idx = table.insert(StringTable_norm, key)
	StringTable.rev[key] = idx
	StringTable.update = true

	if idx > StringTable.max then
		ErrorNoHaltWithStack("Stringtable is full!")
	end
end

local function SendStringTable(ply)
	net.Start("LocalNW_UpdateStringTable")
		net.WriteUInt(1, StringTable_bits)
		net.WriteUInt(StringTable.count, StringTable_bits)
		for k=1, StringTable.count do
			net.WriteString(StringTable_norm[k], StringTable_bits)
		end
	net.Send(ply)

	StringTable.players[ply] = {}
end

local function UpdateStringTable()
	if !StringTable.update then return end

	local Update = {}
	local StringTable_count = StringTable.count
	for ply, data in pairs(StringTable.players) do
		if #data == StringTable_count then continue end

		Update[ply] = data
	end

	for ply, data in pairs(Update) do
		local data_count = #data + 1
		net.Start("LocalNW_UpdateStringTable")
			net.WriteUInt(data_count, StringTable_bits)
			net.WriteUInt(StringTable_count, StringTable_bits)
			for k=data_count, StringTable_count do
				local key = StringTable_norm[k]
				net.WriteString(key, StringTable_bits)
				data[k] = key
			end
		net.Send(ply)
	end
end

--[[
	Connect / Disconnect stuff
]]
hook.Add("PlayerInitialSpawn", "LocalNW_SetupPlayer", function(ply)
	DataTable[ply] = {
		SnapshotData = {},
		Data = {},
		update = false,
	}

	SendStringTable(ply)
end)

hook.Add("PlayerDisconnected", "LocalNW_RemovePlayer", function(ply)
	DataTable[ply] = nil
	StringTable.players[ply] = nil
end)

--[[
	Think function.
	We update everything from here.
]]
local TypeID = LocalNW.TypeID
local TypeBits = LocalNW.TypeBits
local WriteType = LocalNW.WriteType
hook.Add("Think", "LocalNW_UpdateVars", function()
	local StringTable_bits = StringTable.bits
	local StringTable_count = StringTable.count

	UpdateStringTable() -- Before we send all Updates, we need to update the Stringtable

	for ply, dt in pairs(DataTable) do
		if !dt.update then continue end

		local Update = {}
		local Update_count = 0
		local SnapshotData = dt.SnapshotData
		for key, tbl in pairs(dt.Data) do
			local val = SnapshotData[key]
			if val and val.value == tbl.value then continue end

			Update[key] = tbl
			Update_count = Update_count+ 1
		end

		if Update_count == 0 then
			dt.update = false
			return
		end

		net.Start("LocalNW_UpdateVar")
			net.WriteUInt(Update_count, StringTable_bits)
			for k, v in pairs(Update) do
				net.WriteUInt(GetIndexFromStringTable(k), StringTable_bits)

				local type = v.type
				net.WriteUInt(TypeID[type], TypeBits)
				WriteType[type](v.value)

				SnapshotData[k] = v
			end
		net.Send(ply)

		dt.update = false
	end
end)

--[[
	Meta functions
]]
local meta = FindMetaTable("Player")
function meta:SetLocalNWString(key, value)
	local dt = DataTable[self]
	if !dt then return end
	local data = dt.Data

	data[key] = {
		type = "string",
		value = value,
	}
	dt.update = true
	AddToStringTable(key)
end

function meta:GetLocalNWString(key, fallback)
	fallback = fallback or ""

	local dt = DataTable[self]
	if !dt then return fallback end

	local data = dt.Data[key]
	if !data then return fallback end

	return data.value or fallback
end

function meta:SetLocalNWBool(key, value)
	local dt = DataTable[self]
	if !dt then return end
	local data = dt.Data

	data[key] = {
		type = "boolean",
		value = value,
	}
	dt.update = true
	AddToStringTable(key)
end

function meta:GetLocalNWBool(key, fallback)
	fallback = fallback or false

	local dt = DataTable[self]
	if !dt then return fallback end

	local data = dt.Data[key]
	if !data then return fallback end

	return data.value or fallback
end

function meta:SetLocalNWEntity(key, value)
	local dt = DataTable[self]
	if !dt then return end
	local data = dt.Data

	data[key] = {
		type = "entity",
		value = value,
	}
	dt.update = true
	AddToStringTable(key)
end

function meta:GetLocalNWEntity(key, fallback)
	fallback = fallback or false

	local dt = DataTable[self]
	if !dt then return fallback end

	local data = dt.Data[key]
	if !data then return fallback end

	return data.value or fallback
end

function meta:SetLocalNWVector(key, value)
	local dt = DataTable[self]
	if !dt then return end
	local data = dt.Data

	data[key] = {
		type = "vector",
		value = value,
	}
	dt.update = true
	AddToStringTable(key)
end

function meta:GetLocalNWVector(key, fallback)
	fallback = fallback or false

	local dt = DataTable[self]
	if !dt then return fallback end

	local data = dt.Data[key]
	if !data then return fallback end

	return data.value or fallback
end

function meta:SetLocalNWAngle(key, value)
	local dt = DataTable[self]
	if !dt then return end
	local data = dt.Data

	data[key] = {
		type = "angle",
		value = value,
	}
	dt.update = true
	AddToStringTable(key)
end

function meta:GetLocalNWAngle(key, fallback)
	fallback = fallback or false

	local dt = DataTable[self]
	if !dt then return fallback end

	local data = dt.Data[key]
	if !data then return fallback end

	return data.value or fallback
end

function meta:SetLocalNWFloat(key, value)
	local dt = DataTable[self]
	if !dt then return end
	local data = dt.Data

	data[key] = {
		type = "float",
		value = value,
	}
	dt.update = true
	AddToStringTable(key)
end

function meta:GetLocalNWFloat(key, fallback)
	fallback = fallback or false

	local dt = DataTable[self]
	if !dt then return fallback end

	local data = dt.Data[key]
	if !data then return fallback end

	return data.value or fallback
end

function meta:SetLocalNWInt(key, value)
	local dt = DataTable[self]
	if !dt then return end
	local data = dt.Data

	data[key] = {
		type = "int",
		value = value,
	}
	dt.update = true
	AddToStringTable(key)
end

function meta:GetLocalNWInt(key, fallback)
	fallback = fallback or false

	local dt = DataTable[self]
	if !dt then return fallback end

	local data = dt.Data[key]
	if !data then return fallback end

	return data.value or fallback
end