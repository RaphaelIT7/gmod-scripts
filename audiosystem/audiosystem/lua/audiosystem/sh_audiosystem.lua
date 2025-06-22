AudioSystem = AudioSystem or {}

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

function AudioSystem.EnableBackgroundMusic()
	SetGlobal2Bool("AudioSystem:ShouldPlayBackgroundMusic", true)
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

function AudioSystem.SetBackgroundMusicVolume(volume)
	SetGlobal2Float("AudioSystem:BackgroundMusicVolume", volume or 1)
end

function AudioSystem.GetBackgroundMusic(fallBack)
	return GetGlobal2String("AudioSystem:BackgroundMusic", fallBack or "")
end

function AudioSystem.GetBackgroundMusicVolume(fallBack)
	return GetGlobal2Float("AudioSystem:BackgroundMusicVolume", fallBack or 1)
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

-- Server & client files are loaded at last
if SERVER then
	include("audiosystem/sv_audiosystem.lua")
	AddCSLuaFile("audiosystem/cl_audiosystem.lua")
	AddCSLuaFile()
else
	include("audiosystem/cl_audiosystem.lua")
end