--[[
	ToDo: Implemement ambient music system
]]

-- This table contains all tables that were played, this was done to support full updates properly later on. Currently Unused.
AudioSystem.Sounds = AudioSystem.Sounds or {}

-- Needed since WriteSoundField else wouldn't work.
-- ToDo: Why do we even use the EntIndex and not the Entity handle?
--	   Probably because the Entity handle might not get valid when we call Entity(index) before it was created?
local function WriteEntIndex(entity)
	net.WriteUInt(isnumber(entity) and entity or entity:EntIndex(), MAX_EDICT_BITS)
end

--[[
	Helper function to write fields even if they are nil values.
	We skip any fields that are nil to save some work & to allow it to use the proper fallback value clientside then.
]]
local function WriteSoundField(value, writeFunc, ...)
	local isNil = value == nil
	net.WriteBool(isNil)
	if not isNil then
		writeFunc(value, ...)
	end
end

util.AddNetworkString("audioSystem_AudioSystem_PlaySound")
function AudioSystem.PlaySound(soundData) -- see cl_audiosystem.lua for documentation of the table.
	if not istable(soundData) then
		error("PlaySound: didn't get the table that it wants!")
	end

	if not isstring(soundData.soundPath) then -- the only requirement that exists.
		error("PlaySound: Missing soundPath field!")
	end

	net.Start("audioSystem_AudioSystem_PlaySound")
		WriteSoundField(soundData.soundPath, net.WriteString)
		WriteSoundField(soundData.entity, WriteEntIndex)
		WriteSoundField(soundData.soundLevel, net.WriteUInt, 14)
		WriteSoundField(soundData.volume, net.WriteFloat)
		WriteSoundField(soundData.looping, net.WriteBool)
		WriteSoundField(soundData.fadeIn, net.WriteFloat)
		WriteSoundField(soundData.startTick, net.WriteUInt, 32)
		WriteSoundField(soundData.identifier, net.WriteString)
		WriteSoundField(soundData.minDistance, net.WriteUInt, 16)
		WriteSoundField(soundData.maxDistance, net.WriteUInt, 16)
		WriteSoundField(soundData.position, net.WriteVector)
		WriteSoundField(soundData.modes, net.WriteString)

	if not soundData.sendToEntity then -- serverside only, its networked only to the player its being played od
		net.Broadcast()
	else
		net.Send(soundData.sendToEntity)
	end

	--[[table.insert(AudioSystem.Sounds, {
		filePath = soundPath,
		level = soundLevel,
		ent = ent:EntIndex(),
		volume = vol,
		permanent = permanent,
		startTime = CurTime()
	})]]
end

util.AddNetworkString("audioSystem_AudioSystem_StopSound")
function AudioSystem.StopSound(identifier, fadeOut, entity, sendToEntity)
	fadeOut = fadeOut or 0

	local isValid = IsValid(entity)
	net.Start("audioSystem_AudioSystem_StopSound")
		net.WriteBool(identifier == nil) -- if given nil as a identifier we will stop all sounds.
		if identifier then
			net.WriteString(identifier)
		end
		net.WriteFloat(fadeOut)
		net.WriteBool(isValid)
		if isValid then
			net.WriteUInt(entity:EntIndex(), MAX_EDICT_BITS)
		end
	if not sendToEntity then
		net.Broadcast()
	else
		net.Send(sendToEntity)
	end
end

util.AddNetworkString("audioSystem_AudioSystem_FadeSound")
function AudioSystem.FadeSound(identifier, fadeTime, targetVolume) -- ToDo: Fix this function.
	net.Start("audioSystem_AudioSystem_FadeSound")
		net.WriteString(identifier)
		net.WriteFloat(fadeTime)
		net.WriteFloat(targetVolume)
	net.Broadcast()
end