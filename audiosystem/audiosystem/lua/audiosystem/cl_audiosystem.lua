AudioSystem.Channels = AudioSystem.Channels or {} -- All IGModAudioChannel instances, use pairs to iterate as it will have holes.
AudioSystem.CreatingChannels = AudioSystem.CreatingChannels or {} -- Sounds that are currently being created.
AudioSystem.PrecacheSounds = AudioSystem.PrecacheSounds or {}
AudioSystem.BackgroundChannel = AudioSystem.BackgroundChannel or nil
AudioSystem.ChannelIDs = AudioSystem.ChannelIDs or 0 -- Incremental number to assign channel id's

-- So that we don't depend on the GameData table as this system is meant to also work as a standalone library.
AudioSystem.IsSinglePlayer = AudioSystem.IsSinglePlayer or game.SinglePlayer()
AudioSystem.LocalPlayer = AudioSystem.LocalPlayer or nil
AudioSystem.LocalEntIndex = AudioSystem.LocalEntIndex or -1

--[[local enable_backgroundmusic = CreateClientConVar("enable_backgroundmusic", "1", true, false)

function AudioSystem.ShouldPlayBackgroundMusic()
	if not enable_backgroundmusic:GetBool() then return false end -- Client wants to not hear any music.

	return GetGlobal2Bool("AudioSystem:ShouldPlayBackgroundMusic", false)
end]]

local ChannelStates = {
	OK = 1,
	DESTROYING = 2,
}

-- Strips away any spaces & adds the additional stuff.
local function AppendMode(mode, addition)
	return mode:Trim() .. " " .. addition
end

function AudioSystem.NukeChannels()
	for channel, _ in pairs(AudioSystem.Channels) do
		AudioSystem.DestroyChannel(channel, 1)
	end

	for _, precacheData in pairs(AudioSystem.PrecacheSounds) do
		precacheData.channel:__gc()
	end

	AudioSystem.CreatingChannels = {}
	AudioSystem.BackgroundChannel = nil
end

-- Removes any invalid channels in case stop sound was executed.
function AudioSystem.CheckChannels()
	for channel, channelData in pairs(AudioSystem.Channels) do
		if not IsValid(channel) then
			AudioSystem.Channels[channel] = nil
		end
	end
end

function AudioSystem.GetChannelID(channel)
	return AudioSystem.Channels[channel].ID
end

-- NOTE: The callback is not called if the channel wasn't created.
function AudioSystem.CreateChannel(soundFile, mode, callback, errorCallback)
	if not soundFile or soundFile == "" then return end

	local isURL = string.find(soundFile, "://", 1, true)
	soundFile = isURL and soundFile or AudioSystem.ToSound(soundFile)

	if not soundFile:find(".", 1, true) then -- It has no fileName?!? We shall deny this request.
		error("[AudioSystem] Tried to use a invalid sound file! (" .. soundFile .. ")")
		return
	end

	local soundFunc = isURL and sound.PlayURL or sound.PlayFile
	soundFunc(soundFile, mode, function(channel, errCode, errStr)
		if not IsValid(channel) then
			if not errorCallback then
				errorCallback(errCode, errStr)
			end

			error("[AudioSystem] Failed to create audio channel! (" .. errCode .. ", " .. errStr .. "," .. soundFile .. ")\n")
			return
		end

		AudioSystem.CheckChannels()
		AudioSystem.ChannelIDs = AudioSystem.ChannelIDs + 1
		local channelData = {
			deleteWhenFinished = false,  -- ToDo: Actually implement this logic
			ID = AudioSystem.ChannelIDs,
			State = ChannelStates.OK,
			isURL = isURL,
		}
		AudioSystem.Channels[channel] = channelData
		callback(channel, channelData)
	end)
end

function AudioSystem.SetChannelIdentifier(channel, identifier)
	AudioSystem.Channels[channel].identifier = identifier
end

function AudioSystem.GetChannelByIdentifier(identifier)
	for channel, channelData in pairs(AudioSystem.Channels) do
		if channelData.identifier == identifier and channelData.State == ChannelStates.OK then
			return channel
		end
	end

	return nil
end

-- Precaches a sound that can then be played using the given identifier
-- ToDo: Switch this function over to use PlaySound instead of implementing the logic itself again.
function AudioSystem.PrecacheSound(soundFile, mode, identifier, callback)
	local existingPrecacheData = AudioSystem.PrecacheSounds[identifier]
	if existingPrecacheData and IsValid(existingPrecacheData.channel) then
		existingPrecacheData.channel:__gc()
	end

	local precacheData = {
		mode = AppendMode(mode, "noplay"),
		soundFile = AudioSystem.ToSound(soundFile),
		channel = nil,
		creating = true, -- Were creating the channel.
	}
	AudioSystem.PrecacheSounds[identifier] = precacheData

	AudioSystem.CreateChannel(precacheData.soundFile, precacheData.mode, function(channel)
		precacheData.channel = channel
		precacheData.creating = false

		AudioSystem.SetChannelIdentifier(channel, identifier)
		if callback then
			callback(channel)
		end
	end)
end

-- Returns the given precached channel using the identifier, returns nil on failure. If given a callback, it will use that function which will be more reliable.
function AudioSystem.GetPrecachedChannel(identifier, callback, precacheData)
	local precacheData = AudioSystem.PrecacheSounds[identifier]
	if not precacheData then
		if precacheData then
			AudioSystem.PrecacheSound(precacheData.soundFile, precacheData.mode, identifier, function(channel)
				if callback then
					callback(channel)
				end
			end)
		end

		return
	end

	if not IsValid(precacheData.channel) then -- The channel got invalidated somehow, lets recreate it.
		precacheData.creating = true
		AudioSystem.CreateChannel(precacheData.soundFile, precacheData.mode, function(channel)
			precacheData.channel = channel
			precacheData.creating = false

			if callback then
				callback(channel)
			end
		end)

		return
	end

	if callback then
		callback(precacheData.channel)
	else
		return precacheData.channel
	end
end

function AudioSystem.PlayPrecachedChannel(identifier)
	AudioSystem.GetPrecachedChannel(identifier, function(channel)
		channel:Play()
	end)
end

-- This causes the channel to follow the entities position, BUT the channel WONT be removed if the entity is removed.
function AudioSystem.ParentChannelToEntity(channel, entity)
	local entityIndex = 0
	if isnumber(entity) then
		entityIndex = entity
		entity = nil
	else
		entityIndex = entity:EntIndex()
		if not IsValid(entity) then
			entity = nil
		end
	end

	local channelData = AudioSystem.Channels[channel]
	channelData.ent = entity
	channelData.entIndex = entityIndex
end

-- BUG: Bass doesn't seem to care about 3DFadeDistance and it seems like it never actually fades out for some weird reason. So we calculate and set the volume ourself.
local function CalculateFadeVolume(playerPos, channelPos, initialVolume, minDistance, maxDistance)
	local distance = channelPos:Distance(playerPos)

	if distance <= minDistance then
		return initialVolume
	elseif distance >= maxDistance then
		return 0
	else
		return initialVolume * (1 - ((distance - minDistance) / (maxDistance - minDistance)))
	end
end

-- Helper function to wrap around CalculateFadeVolume
local function CalculateChannelVolume(channel, targetVol)
	if channel:Is3D() then
		local channelData = AudioSystem.Channels[channel]
		if channelData then
			local soundData = channelData.soundData
			if soundData and soundData.minDistance and soundData.maxDistance then
				return CalculateFadeVolume(AudioSystem.LocalPlayer:GetPos(), channel:GetPos(), targetVol, soundData.minDistance, soundData.maxDistance)
			end
		end
	end

	return targetVol
end

-- Fades out and destroys the channel.
function AudioSystem.DestroyChannel(channel, fadeOutTime)
	if IsValid(channel) and channel:GetState() == GMOD_CHANNEL_PLAYING and fadeOutTime and fadeOutTime ~= 0 then
		local vol = channel:GetVolume()
		if vol > 0 then
			local id = AudioSystem.GetChannelID(channel)
			timer.Remove("AudioSystem:FadeToAudioChannel" .. id) -- Remove any fadeIn timer that might exist
			local timerName = "AudioSystem:ShutdownAudioChannel" .. id
			local updateFreq = 0.05
			local volumeDecrement = vol / math.ceil(fadeOutTime / updateFreq)
			local channelData = AudioSystem.Channels[channel]
			channelData.State = ChannelStates.DESTROYING
			timer.Create(timerName, updateFreq, 0, function() -- Let the sound fade away
				if !IsValid(channel) or vol <= 0 then
					timer.Remove(timerName)
					channelData.volume = nil
					channel:Stop()
					channel:__gc()
					AudioSystem.CheckChannels()
					AudioSystem.Channels[channel] = nil
					return
				end

				vol = vol - volumeDecrement
				local channelVolume = CalculateChannelVolume(channel, vol)
				if channelVolume == 0 then
					vol = 0 -- makes deletions faster if the channel is already out of range.
				end

				channelData.volume = vol
				channel:SetVolume(channelVolume)
			end)

			return
		end
	end

	AudioSystem.CheckChannels()
	AudioSystem.Channels[channel] = nil
	if IsValid(channel) then
		channel:__gc()
	end
end

-- ToDo: Check if we even need this function anymore or if we fixed it unknowingly that it could become nan somehow.
function AudioSystem.EnsureValidVolume(volume)
	if volume == volume then -- if its not nan, we can say its safe
		return volume
	end

	return 0 -- math.Clamp(volume, -10, 10) -- We return 0 as else if it would clamp to 10 it could errape the client.
end

-- Fades the channel's volume to the target volume.
function AudioSystem.FadeTo(channel, fadeTime, targetVol)
	targetVol = targetVol or 1
	fadeTime = fadeTime or 1

	local vol = AudioSystem.EnsureValidVolume(channel:GetVolume())
	local lowerVol = targetVol < vol
	local id = AudioSystem.GetChannelID(channel)
	local timerName = "AudioSystem:FadeToAudioChannel" .. id
	local updateFreq = 0.05
	local volumeIncrement = math.abs(targetVol - vol) / math.ceil(fadeTime / updateFreq)
	local channelData = AudioSystem.Channels[channel]
	timer.Create(timerName, updateFreq, 0, function() -- Let the sound fade away
		local reachedTarget = false
		if lowerVol then
			reachedTarget = targetVol >= vol
		else
			reachedTarget = vol >= targetVol
		end

		if !IsValid(channel) or reachedTarget then
			channelData.volume = nil
			timer.Remove(timerName)
			return
		end

		if lowerVol then
			vol = vol - volumeIncrement
		else
			vol = vol + volumeIncrement
		end

		local channelVolume = CalculateChannelVolume(channel, vol)
		channelData.volume = channelVolume
		channel:SetVolume(AudioSystem.EnsureValidVolume(channelVolume))
	end)
end

function AudioSystem.StopBackgroundMusic()
	AudioSystem.DestroyChannel(AudioSystem.BackgroundChannel, 1)
	AudioSystem.BackgroundChannel = nil
end

-- Returns the calculated time a channel is supposed to be at, it accounts for looping sounds
function AudioSystem.CalculateTime(channel, tickCount)
	local calculateTime = (engine.TickCount() - tickCount) * engine.TickInterval()
	local fileLength = channel:GetLength()

	return calculateTime - (fileLength * math.floor(calculateTime / fileLength))
end

-- Returns the current background music time syncronized with all players.
function AudioSystem.GetBackgroundMusicTime()
	return AudioSystem.CalculateTime(AudioSystem.BackgroundChannel, GetGlobal2Int("AudioSystem:StartTimeBackgroundMusic"))
end

local lastCreation = 0 -- Doesn't need autorefresh so were fine.
function AudioSystem.PlayBackgroundMusic(fileName)
	if not AudioSystem.ShouldPlayBackgroundMusic() then return end
	if fileName == "" then
		fileName = nil
	end

	local backgroundMusic = AudioSystem.ToSound(fileName or AudioSystem.GetBackgroundMusic())
	if IsValid(AudioSystem.BackgroundChannel) then
		if AudioSystem.BackgroundChannel:GetFileName() == backgroundMusic then return end

		AudioSystem.StopBackgroundMusic()
	end

	if not backgroundMusic then return end

	-- Delay creations so that it won't try to create a channel while it already tried and is waiting for the callback.
	if (lastCreation + 5) > CurTime() then return end
	lastCreation = CurTime()

	AudioSystem.CreateChannel(backgroundMusic, "mono noplay", function(channel)
		AudioSystem.BackgroundChannel = channel

		channel:SetVolume(0)
		channel:Play()
		channel:EnableLooping(true)
		AudioSystem.BackgroundChannel:SetTime(AudioSystem.GetBackgroundMusicTime())
		AudioSystem.FadeTo(channel, 5, AudioSystem.GetBackgroundMusicVolume())
	end)
end

-- This is a NW2 Proxy function.
local function OnBackgroundMusicChange(ent, name, old, new)
	AudioSystem.PlayBackgroundMusic(new)
end

-- This is a NW2 Proxy function.
local function OnBackgroundMusicStateChange(ent, name, old, new)
	if not new then
		if IsValid(AudioSystem.BackgroundChannel) then
			AudioSystem.StopBackgroundMusic()
		end
	else
		AudioSystem.PlayBackgroundMusic()
	end
end

-- Did you know? This was one too >:3
local function OnBackgroundMusicVolumeChange(ent, name, old, new)
	if IsValid(AudioSystem.BackgroundChannel) then
		AudioSystem.FadeTo(AudioSystem.BackgroundChannel, 5, new)
	end
end

function AudioSystem.Init()
	local world = game.GetWorld()

	AudioSystem.LocalPlayer = LocalPlayer()
	AudioSystem.LocalEntIndex = AudioSystem.LocalPlayer:EntIndex()

	--[[
		Setting up the proxies in case the background music changes.
		then we manually call the var proxy because the NW2Vars at this point were already networked so our proxy won't catch the initial value.
	]]
	world:SetNW2VarProxy("AudioSystem:BackgroundMusic", OnBackgroundMusicChange)
	OnBackgroundMusicChange(world, "AudioSystem:BackgroundMusic", nil, AudioSystem.GetBackgroundMusic())

	world:SetNW2VarProxy("AudioSystem:ShouldPlayBackgroundMusic", OnBackgroundMusicStateChange)
	OnBackgroundMusicStateChange(world, "AudioSystem:ShouldPlayBackgroundMusic", nil, AudioSystem.ShouldPlayBackgroundMusic())

	world:SetNW2VarProxy("AudioSystem:BackgroundMusicVolume", OnBackgroundMusicVolumeChange)
	OnBackgroundMusicVolumeChange(world, "AudioSystem:BackgroundMusicVolume", nil, AudioSystem.GetBackgroundMusicVolume())
end

hook.Add("InitPostEntity", "AudioSystem:AudioSystem", AudioSystem.Init)
if game.GetWorld() ~= NULL then -- Autorefresh time
	AudioSystem.Init()
end

local function UpdateBackgroundMusic()
	if not AudioSystem.ShouldPlayBackgroundMusic() then return end

	if not IsValid(AudioSystem.BackgroundChannel) then
		AudioSystem.PlayBackgroundMusic()
	else
		if AudioSystem.BackgroundChannel:GetState() ~= GMOD_CHANNEL_PLAYING then -- Fk stopsound
			AudioSystem.BackgroundChannel:Play()
		end

		local backgroundMusicTime = AudioSystem.GetBackgroundMusicTime()
		if not math.IsNearlyEqual(AudioSystem.BackgroundChannel:GetTime(), backgroundMusicTime, 1) and not AudioSystem.IsSinglePlayer then -- Allow a tolerance of 1 second difference, if were in single player we don't care.
			AudioSystem.BackgroundChannel:SetTime(backgroundMusicTime)
		end
	end
end

local function UpdateChannelPosition(channel, channelData, localPlyPos)
	if not channelData.entIndex then return end

	local ent = channelData.ent or Entity(channelData.entIndex)
	if not IsValid(ent) then return end

	channelData.ent = ent -- In case for some reason the entity didn't exist yet, could happen on full updates?
	local newPos = ent:EyePos()
	if newPos == ent:GetPos() then -- I don't like that we call GetPos for this again :/
		newPos = ent:WorldSpaceCenter() -- If possible, use the EyePos, but if the EyePos matches the Entity's position, we use the WorldSpaceCenter as a better position.
	end

	channel:SetPos(newPos)

	local soundData = channelData.soundData
	if soundData and soundData.minDistance and soundData.maxDistance then
		local volume = CalculateFadeVolume(localPlyPos or AudioSystem.LocalPlayer:GetPos(), newPos, channelData.volume or soundData.volume, soundData.minDistance, soundData.maxDistance)
		channel:SetVolume(volume)
		--print("3D", channel, channelData.ID, volume)
	end
end

local function UpdateChannelPositions()
	local localPlyPos = AudioSystem.LocalPlayer:GetPos()
	for channel, channelData in pairs(AudioSystem.Channels) do
		--[[
			Why don't we remove the channel if the parent is gone?
			Because on full updates, the parent might disappear and then reappear.
		]]
		UpdateChannelPosition(channel, channelData, localPlyPos)
	end
end

function AudioSystem.Think()
	UpdateBackgroundMusic()
	UpdateChannelPositions()
end

--[[
	NOTE: We use PreRender as using Think would be after the audiosystem already played the next audio chunks.
	This would cause the audio of parented channels to lag behind and if a sound is playing on the local player, it sounds awful.
	Related Issue: https://github.com/Facepunch/garrysmod-issues/issues/6361
]]
hook.Add("PreRender", "AudioSystem:AudioSystem", AudioSystem.Think)

--[[
	The soundData table contains all values to create and configure a channel.
	Required fields:
		string soundPath - the sound path for the sound to play.

	Optional fields:
		number soundLevel - used to calculate a distance for when the sound fades and cannot be heard from.
		string identifier - The identifier of the sound, if nil it will use the soundPath field as the identifier
		number startTick - The tick in which the sound was started, this value is used to syncronize the sound for all players. Defaults to the current tick
		Entity entity - The entity the channel should follow, defaults to the world entity.
		number volume - The volume of the sound, defaults to 1
		boolean looping - If the sound should be looped or not, defaults to false
		function callback - the callback function that is called when the channel was created. The channel is given to the callback as the first argument
		number minDistance - The minimum distance for the sound to start fading
		number maxDistance - The maximum distance after which the sound cannot be heard anymore.
		Vector position - A position to play the sound from, be aware that if a entity is set it will override this position!
		string modes - Any additional modes to pass to AudioSystem.CreateChannel
		boolean noplay - Won't automatically play the sound

	Notes:
		When the entity is set to the world, the sound is played as mono and NOT 3d!
]]
function AudioSystem.PlaySound(soundData)
	soundData.identifier = soundData.identifier or soundData.soundPath
	soundData.startTick = soundData.startTick or engine.TickCount()
	--soundData.entity = soundData.entity or game.GetWorld()
	soundData.volume = soundData.volume or 1
	soundData.looping = soundData.looping or false
	soundData.modes = soundData.modes or ""

	AudioSystem.StopSound(soundData.identifier, 0.5)

	local entIndex = 0
	if isnumber(soundData.entity) then
		entIndex = soundData.entity
	elseif IsValid(soundData.entity) then
		entIndex = soundData.entity:EntIndex()
	end

	local existingCreationData = AudioSystem.CreatingChannels[soundData.identifier]
	local isAlreadyInCreation = existingCreationData ~= nil
	if existingCreationData and (existingCreationData.creationTimeout or 0) < CurTime() then
		isAlreadyInCreation = false
	end

	AudioSystem.CreatingChannels[soundData.identifier] = soundData
	soundData.creationTimeout = CurTime() + 5 -- if the sound for some reason wasn't created after 5 seconds, we will think it timed out.
	
	-- Required to prevent a race conditions where multiple channels could have been created with the same identifier.
	-- BUG: Look at this later again for a special case: What if soundData.soundPath is different in the second call done and it uses the same identifier?
	if isAlreadyInCreation then
		soundData.identifier = existingCreationData.identifier
		soundData.soundPath = existingCreationData.soundPath
		return
	end

	local useMono = entIndex <= 0 and not soundData.position and not soundData.forceMono
	AudioSystem.CreateChannel(soundData.soundPath, AppendMode(AppendMode(useMono and "mono" or "3d", soundData.modes), "noplay"), function(channel, channelData)
		local soundData = AudioSystem.CreatingChannels[soundData.identifier] or soundData -- Update in case it was updated in the few frames we had originally made our call.
		if soundData.DESTROYCHANNEL then
			channel:SetVolume(0)
			AudioSystem.DestroyChannel(channel)
			AudioSystem.CreatingChannels[soundData.identifier] = nil
			channel:__gc()
			return
		end

		if soundData.fadeIn and soundData.fadeIn ~= 0 then
			channel:SetVolume(0)
			channelData.volume = 0
		else
			channel:SetVolume(soundData.volume)
		end

		channel:EnableLooping(soundData.looping)
		channel:SetTime(AudioSystem.CalculateTime(channel, soundData.startTick))

		if soundData.identifier then
			AudioSystem.SetChannelIdentifier(channel, soundData.identifier)
		end

		if soundData.fadeIn and soundData.fadeIn ~= 0 then
			AudioSystem.FadeTo(channel, soundData.fadeIn, soundData.volume)
		end

		if entIndex ~= 0 then
			AudioSystem.ParentChannelToEntity(channel, entIndex)
		end

		if soundData.position then
			channel:SetPos(soundData.position)
		end

		if soundData.soundLevel and soundData.soundLevel ~= 0 then
			channel:Set3DFadeDistance(soundData.soundLevel ^ 1.25, soundData.soundLevel ^ 1.5)
			soundData.minDistance = soundData.soundLevel ^ 1.25
			soundData.maxDistance = soundData.soundLevel ^ 1.5
		end

		if soundData.minDistance and soundData.maxDistance then
			channel:Set3DFadeDistance(soundData.minDistance, soundData.maxDistance)
		end

		channelData.soundData = soundData -- Save the data that was used to create this channel.
		UpdateChannelPosition(channel, channelData) -- Update the channel position so that when we play it, there won't be a audio bug for 1 frame where it would play from the world origin.

		if not soundData.noplay then -- We call Play only here since some settings might change how it can be heard.
			channel:Play()
		end

		AudioSystem.CreatingChannels[soundData.identifier] = nil
		if soundData.callback then
			soundData.callback(channel)
		end
	end, function(errCode, errStr)
		AudioSystem.CreatingChannels[soundData.identifier] = nil -- Error happened, just clear it out from creation.
	end)
end

-- Returns all channels that were parented to the given entity.
function AudioSystem.GetEntityChannels(entity)
	local entIndex = -1
	if isnumber(entity) then
		entIndex = entity
	elseif isentity(entity) and IsValid(entity) then
		entIndex = entity:EntIndex()
	end

	if entIndex == -1 then
		error("Invalid entity was given to us. It must be a Entity or a Entity Index!")
		return
	end

	local results = {}
	for channel, entTbl in pairs(AudioSystem.Channels) do
		if entTbl.entIndex ~= entIndex then continue end
		
		table.insert(results, channel)
	end

	return results
end

--[[
	Stops the sound by the given identifier.
	If given no identifier and no entity, it will stop all sounds globally.
	If given no identifier and a entity, it will stop all sounds from the entity.
]]
function AudioSystem.StopSound(identifier, fadeOut, entIndex)
	fadeOut = fadeOut or 1

	if not identifier then -- No identifier? then we want to stop all sounds.
		if not entIndex then -- No entitiy? Then we want to stop all sounds globally.
			for channel, _ in pairs(AudioSystem.Channels) do
				if channel == AudioSystem.BackgroundChannel then continue end
				AudioSystem.DestroyChannel(channel, fadeOut)
			end
		else -- We got a valid entity, then we only stop all sounds from that entity.
			for _, channel in ipairs(AudioSystem.GetEntityChannels(entIndex)) do
				AudioSystem.DestroyChannel(channel, fadeOut)
			end
		end

		return
	end

	local creationSounData = AudioSystem.CreatingChannels[identifier]
	if creationSounData then -- The channel wasn't created yet, so we cannot stop it. Instead we'll set a flag.
		creationSounData.DESTROYCHANNEL = true
		return
	end

	local channel = AudioSystem.GetChannelByIdentifier(identifier)
	if not channel then return end

	AudioSystem.DestroyChannel(channel, fadeOut)
end

--[[
	Helper function to read fields even if they are nil values.
	Serverside we network a bool and then the value, the bool is true if the field was nil.
]]
local function ReadSoundField(readFunc, ...)
	local isNil = net.ReadBool(isNil)
	if not isNil then
		return readFunc(...)
	end

	return nil
end

net.Receive("AudioSystem_PlaySound", function()
	local soundData = {
		soundPath = ReadSoundField(net.ReadString),
		entity = ReadSoundField(net.ReadUInt, MAX_EDICT_BITS),
		soundLevel = ReadSoundField(net.ReadUInt, 14),
		volume = ReadSoundField(net.ReadFloat),
		looping = ReadSoundField(net.ReadBool),
		fadeIn = ReadSoundField(net.ReadFloat),
		tickCount = ReadSoundField(net.ReadUInt, 32),
		identifier = ReadSoundField(net.ReadString),
		minDistance = ReadSoundField(net.ReadUInt, 16),
		maxDistance = ReadSoundField(net.ReadUInt, 16),
		modes = ReadSoundField(net.ReadString),
		pan = ReadSoundField(net.ReadFloat),
		playbackRate = ReadSoundField(net.ReadFloat),
	}

	-- NOTE: We intentionally do this only for sounds played by the server since they won't possibly move the channel independantly.
	-- While clientside, the channel could be moved after PlaySound was called so if we forced it into mono we could break things.
	if soundData.entity ~= nil and soundData.entity == AudioSystem.LocalEntIndex then
		soundData.forceMono = true -- We are playing the sound on the local player, so we switch it to mono for hopefully better quality & for no 3D audio bugs since the audio source is exacty at the ear position.
	end

	AudioSystem.PlaySound(soundData)
end)

net.Receive("AudioSystem_StopSound", function()
	local stopAllSounds = net.ReadBool()
	local identifier = nil
	if not stopAllSounds then
		identifier = net.ReadString()
	end

	local fadeOut = net.ReadFloat()
	local entIndex = nil
	if net.ReadBool() then
		entIndex = net.ReadUInt(MAX_EDICT_BITS)
	end

	AudioSystem.StopSound(identifier, fadeOut, entIndex)
end)

net.Receive("AudioSystem_FadeSound", function() -- ToDo: Fix this function
	local identifier = net.ReadString()
	local fadeTime = net.ReadFloat()
	local targetVolume = net.ReadFloat()

	local channel = AudioSystem.GetChannelByIdentifier(identifier)
	if not channel then return end

	AudioSystem.FadeTo(channel, fadeTime, targetVolume)
end)