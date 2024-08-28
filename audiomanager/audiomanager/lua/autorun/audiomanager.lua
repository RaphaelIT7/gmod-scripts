AudioManager = {}
AudioManager.TYPE_MONO = 1
AudioManager.TYPE_STERIO = 2
AudioManager.Readers = {
	["wav"] = function(file, headeronly)
		local header = {
			chunk_id = file:Read(4),
			chunk_size = file:ReadLong(),
			desc = file:Read(4),
			fmt = file:Read(4),
			section_chunk = file:ReadLong(),
			format_type = file:ReadShort(),
			type = file:ReadShort(), -- Mono = 1, Sterio = 2
			samples = file:ReadLong(),
			bytes_sec = file:ReadLong(),
			block_align = file:ReadShort(),
			bits_per_sample = file:ReadShort(),
			data_desc = file:Read(4),
			data_chunk_size = file:ReadLong(),
		}

		local struct = {
			type = header.type,
			bitsPerSample = header.bits_per_sample,
			sampleRate = header.samples,
			length = header.chunk_size / header.samples,
			header = header,
			sampleData = {},
		}

		if !headeronly then
			local audioData = file:Read(header.chunk_size)
			local sampleData = {}
			local audioData_length = #audioData
			local numChannels = header.type
			local bytesPerSample = header.bits_per_sample / 8
			local maxSampleValue = 2 ^ (header.bits_per_sample - 1) - 1
			for channel = 1, numChannels do
				local channel_tbl = {}
				sampleData[channel] = channel_tbl
			    
				local startIndex = (channel - 1) * bytesPerSample + 1
				for i = startIndex, audioData_length, numChannels * bytesPerSample do
					local sampleValue = 0
					local sampleBytes = {audioData:byte(i, i + bytesPerSample - 1)}

					for j = #sampleBytes, 1, -1 do
						sampleValue = sampleValue * 256 + sampleBytes[j]
					end

					if sampleValue > maxSampleValue then
						sampleValue = sampleValue - 2 ^ header.bits_per_sample
					end

					channel_tbl[#channel_tbl + 1] = sampleValue / maxSampleValue
				end
			end

			struct.sampleData = sampleData
		end

		return struct
	end,
	/*["ogg"] = function(file, headeronly)
		local header = {
			magicNumber = file:Read(4),
			version = file:ReadByte(),
			headerType = file:ReadByte(),
			granulePosition = file:ReadUInt64(),
			bitstreamSerial = file:ReadLong(),
			pageNumber = file:ReadLong(),
			checksum = file:ReadULong(),
			page_segments = file:ReadByte(),
			segments = {},
			vorbis = {}
		}

		local segment_tbl = header.segments
		for k=1, header.page_segments do
			segment_tbl[k] = file:ReadByte()
		end

		if header.headerType == 2 then
			local vorbis = header.vorbis
			vorbis.packetType = file:ReadByte()


		end

		local struct = {
			type = 0,
			bitsPerSample = 0,
			sampleRate = 0,
			length = 0,
			header = header,
			sampleData = {},
		}

		return struct
	end,*/
	/*["mp3"] = function(file, headeronly)
		local header = {
			id3tag = {},
		}

		if file:Read(3) == "ID3" then // Supports ID3v2
			local id3 = header.id3tag
			id3.version = file:ReadByte()
			id3.revision = file:ReadByte()
			id3.flags = file:ReadByte()

			for k=1, 4 do // ToDo: Do this better someday
				id3.size = file:ReadByte()
			end

			if bit.band(id3.flags, 0x40) ~= 0 then
				local extendedHeaderSize = file:ReadULong() + 4
				local extendedHeaderData = file:Read(extendedHeaderSize - 4)
				id3.extendedHeader = extendedHeaderData
			end

			local function readFrame(file)
				local frame = {}
				frame.id = file:Read(4)
				frame.size = file:ReadULong()
				frame.flags = file:ReadShort()
				frame.data = file:Read(frame.size)

				return frame
			end

			local frames = {}
			local bytesRead = 0
			while bytesRead < id3.size do
				local frame = readFrame(file)
				if frame.id == "" then
					break
				end
				table.insert(frames, frame)
				bytesRead = bytesRead + frame.size + 10
			end

			id3.frames = frames

			if bit.band(id3.flags, 0x10) ~= 0 then
				local footerIdentifier = file:Read(3)
				if footerIdentifier == "3DI" then
					id3.footerVersion = file:ReadShort()
					id3.footerFlags = file:ReadByte()
					id3.footerSize = file:ReadULong()
				end
				file:Seek(file:Tell() - 3)
			end

			file:Seek(0)
			file:Seek(10 + id3.size)
		else
			file:Seek(0)
		end

		local syncWord = file:ReadUShort()
		print(syncWord, file:Tell())

		return header
	end,*/
}

AudioManager.Writers = {
	["wav"] = function(file, data)
		local sampleData = data.sampleData
		local bitsPerSample = data.bitsPerSample
		local sampleRate = data.sampleRate
		local numSamples = #sampleData[1]
		local dataSize = numSamples * #sampleData * bitsPerSample / 8

		file:Write("RIFF")
		file:WriteLong(dataSize + 36)
		file:Write("WAVE")

		file:Write("fmt ")
		file:WriteLong(16)
		file:WriteShort(1)
		file:WriteShort(#sampleData)
		file:WriteLong(sampleRate)
		file:WriteLong(sampleRate * #sampleData * bitsPerSample / 8)
		file:WriteShort(#sampleData * bitsPerSample / 8)
		file:WriteShort(bitsPerSample)

		file:Write("data")
		file:WriteLong(dataSize)

		for i = 1, numSamples do
			for channel=1, #sampleData do
				local sample = sampleData[channel][i]
				if !sample then continue end

				if bitsPerSample == 8 then
					sample = math.floor(sample * 127 + 128)
				elseif bitsPerSample == 16 then
					sample = math.floor(sample * 32767)
				end

				if sample > 32767 then
					sample = 32767
				elseif sample < -32768 then
					sample = -32768
				end

				file:WriteShort(sample)
			end
		end
	end,
}

function AudioManager.LoadFile(filePath, gamePath, type)
	local ffile = file.Open(filePath, "rb", gamePath or "GAME")

	if !ffile then
		return nil
	end

	local Manager = AudioManager.Readers[type]
	if !Manager then
		error(type .. " is not supported for AudioManager.LoadFile!")
	end

	local tbl = Manager(ffile)

	ffile:Close()

	return tbl
end

function AudioManager.LoadFileHeader(filePath, gamePath, type)
	local ffile = file.Open(filePath, "rb", gamePath or "GAME")

	if !ffile then
		return nil
	end

	local Manager = AudioManager.Readers[type]
	if !Manager then
		error(type .. " is not supported for AudioManager.LoadFileHeader!")
	end

	local tbl = Manager(ffile, true)

	ffile:Close()

	return tbl
end

function AudioManager.SaveFile(filePath, data, type)
	local ffile = file.Open(filePath, "wb", "DATA")

	if !ffile then
		return nil
	end

	local Manager = AudioManager.Writers[type]
	if !Manager then
		error(type .. " is not supported for AudioManager.SaveFile!")
	end

	local tbl = Manager(ffile, data)

	ffile:Close()

	return tbl
end

function AudioManager.ChangeSpeed(audioData, targetSpeed)
	local sampleRate = audioData.sampleRate
	AudioManager.ConvertTo(audioData, audioData.sampleRate / targetSpeed)
	audioData.sampleRate = sampleRate
end

function AudioManager.ConvertTo(audioData, targetSampleRate)
	local sampleRateRatio = audioData.sampleRate / targetSampleRate
	if sampleRateRatio == 1 then return end

	if sampleRateRatio > 1 then
		local sampleData = audioData.sampleData
		local newSampleData = {}
		for k=1, #sampleData do
			local channelData = sampleData[k]
			local newChannelData = {}
			newSampleData[k] = newChannelData
			for i=1, #channelData - 1, sampleRateRatio do
				local newIndex = math.floor(i)
				table.insert(newChannelData, channelData[newIndex])
			end
		end
		audioData.sampleData = newSampleData
		audioData.sampleRate = targetSampleRate
	else
		local upsamplingFactor = (targetSampleRate / audioData.sampleRate) - 1
		local sampleData = audioData.sampleData
		local newSampleData = {}
		for k=1, #sampleData do
			local channelData = sampleData[k]
			local newChannelData = {}
			newSampleData[k] = newChannelData

			local nextsample = 0
			for i = 1, #channelData do
				table.insert(newChannelData, channelData[i])
				if (i + 1) > #channelData then continue end
				
				nextsample = nextsample + upsamplingFactor
				while nextsample > 1 do
					nextsample = nextsample - 1
					local interpolatedSample = channelData[i] + (channelData[i + 1] - channelData[i]) * nextsample
					table.insert(newChannelData, interpolatedSample)
				end
			end
		end
		audioData.sampleData = newSampleData
		audioData.sampleRate = targetSampleRate
	end
end

local supported_sampleRates = {
	[44100] = true,
	[22050] = true,
	[11025] = true,
}
function AudioManager.CanBePlayed(audioData)
	return supported_sampleRates[audioData.sampleRate] or false
end

function AudioManager.GenerateSound(name, audioData, forceMode, forceLength)
	forceMode = forceMode or data.type
	forceLength = forceLength or audioData.length

	if !AudioManager.CanBePlayed(audioData) then
		error("Samplerate is not supported! Call AudioManager.ConvertTo") 
	end

	if #audioData.sampleData == 0 then
		error("Theres no Sample Data!")
	end

	local ids = {}
	if forceMode == AudioManager.TYPE_STERIO then
		for k, datatable in pairs(audioData.sampleData) do
			local function data( t )
		    	return datatable[t]
			end

			sound.Generate(name .. "_" .. k, audioData.sampleRate, forceLength, data )
			ids[name .. "_" .. k] = true
		end
	elseif forceMode == AudioManager.TYPE_MONO then
		local datatable = audioData.sampleData[1]
		local function data( t )
		    return datatable[t]
		end

		sound.Generate(name, audioData.sampleRate, forceLength, data )
		ids[name] = true
	end

	return ids
end