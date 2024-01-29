local function ReadVector(file)
	return Vector(file:ReadFloat(), file:ReadFloat(), file:ReadFloat())
end

local function ReadString(file)
	local str = {}
	for k=1, 255 do
		local byte = file:Read(1)
		if string.byte(byte) == 0 then break end

		table.insert(str, byte)
	end

	return table.concat(str, "")
end

--[[
	This function will return a table with this structure:
	Based off: https://developer.valvesoftware.com/wiki/MDL_(Source)

	model = {
		header = { Contains all studiohdr_t values }
		secondaryheader = { Contains all studiohdr2_t values } << Can be nil 
		texturedirs = { Contains all Material directories }
		textures = { Contains all Materials & mstudiotexture_t values }
	}

	Example using ("models/player/gman_high.mdl"):
	model {
		header = {
			[Way too much stuff]
		},
		secondaryheader = {
			["flMaxEyeDeflection"] = 0
			["illumpositionattachmentindex"] = 0
			["linearbone_index"] = 469088
			["srcbonetransform_count"] = 0
			["srcbonetransform_index"] = 469496
			["unknown"]: { Contains nothing important }
		},
		texturedirs = {
			[1]	= "models\Gman\",
			[2]	= "models\humans\male\"
		},
		textures = {
			[1] = {
				["client_material"]	=	0
				["flags"]	=	0
				["material"]	=	263211828
				["name"]	=	gman_facehirez << Your Material name
				["name_offset"]	=	14286
				["unused"]	=	0
				["unused2"] { Contains nothing }
			}
		}
	}
]]
function ReadModel(path)
	local mdl = file.Open(path, "rb", "GAME")
	if !mdl then
		error("Failed to read Model!") -- Comment this out if you don't want any errors
		return
	end

	local model = {
		header = {
			id = mdl:Read(4),
			version = mdl:ReadLong(),
			checksum = mdl:ReadLong(),
			name = mdl:Read(64),

			dataLength = mdl:ReadLong(),

	        eyeposition = ReadVector(mdl),
	        illumposition = ReadVector(mdl),
	        hull_min = ReadVector(mdl),
	        hull_max = ReadVector(mdl),
	        view_bbmin = ReadVector(mdl),
	        view_bbmax = ReadVector(mdl),

	        flags = mdl:ReadLong(),
	        
	        bone_count = mdl:ReadLong(),
	        bone_offset = mdl:ReadLong(),

	        bonecontroller_count = mdl:ReadLong(),
	        bonecontroller_offset = mdl:ReadLong(),

	        hitbox_count = mdl:ReadLong(),
	        hitbox_offset = mdl:ReadLong(),

	        localanim_count = mdl:ReadLong(),
	        localanim_offset = mdl:ReadLong(),

	        localseq_count = mdl:ReadLong(),
	        localseq_offset = mdl:ReadLong(),

	        activitylistversion = mdl:ReadLong(),
	        eventsindexed = mdl:ReadLong(),

	        texture_count = mdl:ReadLong(),
	        texture_offset = mdl:ReadLong(),

	        texturedir_count = mdl:ReadLong(),
	        texturedir_offset = mdl:ReadLong(),

	        skinreference_count = mdl:ReadLong(),
	        skinrfamily_count = mdl:ReadLong(),
	        skinreference_index = mdl:ReadLong(),

	        bodypart_count = mdl:ReadLong(),
	        bodypart_offset = mdl:ReadLong(),

	        attachment_count = mdl:ReadLong(),
	        attachment_offset = mdl:ReadLong(),

	        localnode_count = mdl:ReadLong(),
	        localnode_index = mdl:ReadLong(),
	        localnode_name_index = mdl:ReadLong(),

	        flexdesc_count = mdl:ReadLong(),
	        flexdesc_index = mdl:ReadLong(),

	        flexcontroller_count = mdl:ReadLong(),
	        flexcontroller_index = mdl:ReadLong(),

	        flexrules_count = mdl:ReadLong(),
	        flexrules_index = mdl:ReadLong(),

	        ikchain_count = mdl:ReadLong(),
	        ikchain_index = mdl:ReadLong(),

	        mouths_count = mdl:ReadLong(),
	        mouths_index = mdl:ReadLong(),

	        localposeparam_count = mdl:ReadLong(),
	        localposeparam_index = mdl:ReadLong(),

	        surfaceprop_index = mdl:ReadLong(),

	        keyvalue_index = mdl:ReadLong(),
	        keyvalue_count = mdl:ReadLong(),

	        iklock_count = mdl:ReadLong(),
	        iklock_index = mdl:ReadLong(),

	        mass = mdl:ReadFloat(),

	        contents = mdl:ReadLong(),

	        includemodel_count = mdl:ReadLong(),
	        includemodel_index = mdl:ReadLong(),

	        virtualModel = mdl:ReadLong(),

	        animblocks_name_index = mdl:ReadLong(),
	        animblocks_count = mdl:ReadLong(),
	        animblocks_index = mdl:ReadLong(),

	        animblockModel = mdl:ReadLong(),

	        bonetablename_index = mdl:ReadLong(),

	        vertex_base = mdl:ReadLong(),
	        offset_base = mdl:ReadLong(),

	        directionaldotproduct = mdl:ReadByte(),

	        rootLod = mdl:ReadByte(),

	        numAllowedRootLods = mdl:ReadByte(),

	        unused0 = mdl:ReadByte(),
	        unused1 = mdl:ReadLong(),

	        flexcontrollerui_count = mdl:ReadLong(),
	        flexcontrollerui_index = mdl:ReadLong(),

	        vertAnimFixedPointScale = mdl:ReadFloat(),

	        unused2 = mdl:ReadLong(),

	        studiohdr2index = mdl:ReadLong(),

	        unused3 = mdl:ReadLong(),
		}
	}

	if model.header.studiohdr2index > 0 then
    	mdl:Seek(model.header.studiohdr2index)
    	model.secondaryheader = { -- studiohdr2_t struct
    		srcbonetransform_count = mdl:ReadLong(),
    		srcbonetransform_index = mdl:ReadLong(),

    		illumpositionattachmentindex = mdl:ReadLong(),

    		flMaxEyeDeflection = mdl:ReadFloat(),

    		linearbone_index = mdl:ReadLong(),
    		unknown = {},
    	}

    	for i = 1, 64 do
		    model.secondaryheader.unknown[i] = mdl:ReadLong()
		end
    end

   	if model.header.texturedir_count > 0 then
    	mdl:Seek(model.header.texturedir_offset)
    	model.texturedirs = {}

    	local dirs = {}
    	for k=1, model.header.texturedir_count do
    		dirs[k] = mdl:ReadLong()
    	end

    	for k, offset in pairs(dirs) do
    		mdl:Seek(offset)

    		model.texturedirs[k] = ReadString(mdl)
    	end
    end

    if model.header.texture_count > 0 then
    	mdl:Seek(model.header.texture_offset)
    	model.textures = {}

    	for k=1, model.header.texture_count do
    		local mstudiotexture_t = {}
		    mstudiotexture_t.name_offset = mdl:ReadLong()
		    mstudiotexture_t.flags = mdl:ReadLong()
		    mstudiotexture_t.used = mdl:ReadLong()
		    mstudiotexture_t.unused = mdl:ReadLong()
		    mstudiotexture_t.material = mdl:ReadLong()
		    mstudiotexture_t.client_material = mdl:ReadLong()

		    mstudiotexture_t.unused2 = {}
		    for i = 1, 10 do
		        mstudiotexture_t.unused2[i] = mdl:ReadLong()
		    end

		    if mstudiotexture_t.name_offset > 0 then
		    	local offset = mdl:Tell()
		        mdl:Seek(offset - 64 + mstudiotexture_t.name_offset)
		        mstudiotexture_t.name = ReadString(mdl)
		        mdl:Seek(offset)
		    end

		    table.insert(model.textures, mstudiotexture_t)
    	end
    end

	return model
end

PrintTable(ReadModel("models/player/gman_high.mdl"))