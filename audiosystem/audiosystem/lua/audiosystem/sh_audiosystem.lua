AudioSystem = AudioSystem or {}
AudioSystem.RegisteredSounds = AudioSystem.RegisteredSounds or {}

--[[
	The Background music is networked & syncronized.
	Later there will be a helper function to do this with other sounds too.
	This whole audio system is meant to efficiently syncronize and play sounds for players
]]


-- Simple function. Adds sound/ to the given fileName to properly work with sound.PlayFile
function AudioSystem.ToSound(fileName)
	if fileName == "" then
		return nil
	end

	if fileName:StartsWith("sound/") then
		return fileName
	end
	
	return "sound/" .. fileName
end

function AudioSystem.ShouldPlayBackgroundMusic()
	return GetGlobal2Bool("AudioSystem:ShouldPlayBackgroundMusic", false)
end

function AudioSystem.EnableBackgroundMusic(forced)
	if forced then
		AudioSystem.ForcedDisable = false
	end

	if AudioSystem.ForcedDisable then return end
	SetGlobal2Bool("AudioSystem:ShouldPlayBackgroundMusic", true)
end

function AudioSystem.DisableBackgroundMusic(forced)
	SetGlobal2Bool("AudioSystem:ShouldPlayBackgroundMusic", false)
	AudioSystem.ForcedDisable = forced or false
end

function AudioSystem.SetBackgroundMusic(soundFile, volume)
	SetGlobal2String("AudioSystem:BackgroundMusic", soundFile)
	SetGlobal2Float("AudioSystem:BackgroundMusicVolume", volume or 1)
	SetGlobal2Int("AudioSystem:StartTimeBackgroundMusic", engine.TickCount()) -- Timestamp to syncronize the music for everyone

	if DisableSoundScapes then
		--DisableSoundScapes() -- disable sound scapes.
	end
end

function AudioSystem.GetBackgroundMusic(fallBack)
	return GetGlobal2String("AudioSystem:BackgroundMusic", fallBack or "")
end

function AudioSystem.SetBackgroundMusicVolume(volume)
	SetGlobal2Float("AudioSystem:BackgroundMusicVolume", volume or 1)
end

function AudioSystem.GetBackgroundMusicVolume(fallBack)
	return GetGlobal2Float("AudioSystem:BackgroundMusicVolume", fallBack or 1)
end

function AudioSystem.SetBackgroundMusicPlaybackRate(playbackrate)
	SetGlobal2Float("AudioSystem:BackgroundMusicPlaybackRate", playbackrate or 1)
end

function AudioSystem.GetBackgroundMusicPlaybackRate(fallBack)
	return GetGlobal2Float("AudioSystem:BackgroundMusicPlaybackRate", playbackrate or 1)
end

function AudioSystem.RegisterSound(registerName, soundTable)
	AudioSystem.RegisteredSounds[registerName] = soundTable
end

-- Creates a copy of the given table.
-- We don't care about any userdata since our soundTable should have none at all.
local function CopyTable(input, references)
	local output = {}
	references = references or {} -- to prevent loops
	if references[input] then
		print("CopyTable was called with looping references!")
		return output
	end
	references[input] = true

	for key, value in pairs(input) do
		if type(value) == "table" then
			output[key] = CopyTable(value, references)
		else
			output[key] = value
		end
	end

	return output
end

-- Returns a copy of the soundTable that can freely be modified and used, or returns nil if no sound was registered with the given name
function AudioSystem.GetRegisteredSound(registerName)
	local soundTable = AudioSystem.RegisteredSounds[registerName]
	if not soundTable then
		return nil -- There is no song registered with this name
	end

	return CopyTable(soundTable)
end

function AudioSystem.PrecacheSound(soundFile)
	-- ToDo
end

--[[
	Helper function calculating the tickcount for when you're using the startTick field on PlaySound.
	If given no baseTick it will result in it using the current tickcount.
	give it a baseTick of 0 to just get the calculation of the time as ticks.
	The input time should be a timepoint in the song like 10 for 10 seconds into the song.
]]
function AudioSystem.TimeToTick(time, baseTick)
	local tickTime = time > 0 and (time / engine.TickInterval()) or 0
	baseTick = baseTick or engine.TickCount()
	if baseTick == 0 then
		return tickTime
	end

	return baseTick - tickTime
end

-- Looks up a sound by name registered using sound.Add and select one of its sound files randomly
function AudioSystem.GetSoundFileFromSource(name)
	local info = sound.GetProperties(name)
	if not info then return end
	if not info.sound then return end

	local soundFile = nil
	if isstring(info.sound) then
		soundFile = info.sound
	end

	if istable(info.sound) then
		soundFile = info.sound[math.random(1, #info.sound)]
	end
	
	if soundFile then
		return (soundFile:StartsWith("(") or soundFile:StartsWith(")")) and soundFile:sub(2) or soundFile
	end
end

-- Server & client files are loaded at last
if SERVER then
	include("audiosystem/sv_audiosystem.lua")
	AddCSLuaFile("audiosystem/cl_audiosystem.lua")
	AddCSLuaFile()
else
	include("audiosystem/cl_audiosystem.lua")
end