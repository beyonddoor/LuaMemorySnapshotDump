
local config = {
    searchFunction = false,
    searchThread = false,

    m_bAllMemoryRefFileAddTime = true,
    m_bSingleMemoryRefFileAddTime = true,
    m_bComparedMemoryRefFileAddTime = true,
    dumpUserDataOnly = true,
    dumpSorted = false,
}

-- Create a container to collect the mem ref info results.
local function CreateObjectReferenceInfoContainer()
	-- Create new container.
	---@class ObjectReferenceInfoContainer
	local cContainer = {}

	-- Contain [table/function] - [reference count] info.
	local cObjectReferenceCount = {}
	setmetatable(cObjectReferenceCount, {__mode = "k"})

	-- Contain [table/function] - [name] info.
	local cObjectAddressToName = {}
	setmetatable(cObjectAddressToName, {__mode = "k"})

	-- Set members.
	---@type table The container of [table/function] - [reference count] info.
	cContainer.m_cObjectReferenceCount = cObjectReferenceCount
	---@type table The container of [table/function] - [name] info.
	cContainer.m_cObjectAddressToName = cObjectAddressToName

	-- For stack info.
	---@type integer stack level
	cContainer.m_nStackLevel = -1
	---@type string stack info
	cContainer.m_strShortSrc = "None"
	---@type string stack info
	cContainer.m_nCurrentLine = -1

	return cContainer
end

local function CollectObjectReferenceInMemory(strName, cObject, cDumpInfoContainer)
	if not cObject then
		return
	end

	if not strName then
		strName = ""
	end

	-- Check container.
	if (not cDumpInfoContainer) then
		cDumpInfoContainer = CreateObjectReferenceInfoContainer()
	end

	-- Check stack.
	if cDumpInfoContainer.m_nStackLevel > 0 then
		local cStackInfo = debug.getinfo(cDumpInfoContainer.m_nStackLevel, "Sl")
		if cStackInfo then
			cDumpInfoContainer.m_strShortSrc = cStackInfo.short_src
			cDumpInfoContainer.m_nCurrentLine = cStackInfo.currentline
		end

		cDumpInfoContainer.m_nStackLevel = -1
	end

	-- Get ref and name info.
	local cRefInfoContainer = cDumpInfoContainer.m_cObjectReferenceCount
	local cNameInfoContainer = cDumpInfoContainer.m_cObjectAddressToName
	
	local strType = type(cObject)
	if "table" == strType then
		-- Check table with class name.
		if rawget(cObject, "__cname") then
			if "string" == type(cObject.__cname) then
				strName = strName .. "[class:" .. cObject.__cname .. "]"
			end
		elseif rawget(cObject, "class") then
			if "string" == type(cObject.class) then
				strName = strName .. "[class:" .. cObject.class .. "]"
			end
		elseif rawget(cObject, "_className") then
			if "string" == type(cObject._className) then
				strName = strName .. "[class:" .. cObject._className .. "]"
			end
		end

		-- Check if table is _G.
		if cObject == _G then
			strName = strName .. "[_G]"
		end

		-- Get metatable.
		local bWeakK = false
		local bWeakV = false
		local cMt = getmetatable(cObject)
		if cMt then
			-- Check mode.
			local strMode = rawget(cMt, "__mode")
			if strMode then
				if "k" == strMode then
					bWeakK = true
				elseif "v" == strMode then
					bWeakV = true
				elseif "kv" == strMode then
					bWeakK = true
					bWeakV = true
				end
			end
		end

		-- Add reference and name.
		cRefInfoContainer[cObject] = (cRefInfoContainer[cObject] and (cRefInfoContainer[cObject] + 1)) or 1
		if cNameInfoContainer[cObject] then
			return
		end

		-- Set name.
		cNameInfoContainer[cObject] = strName

		-- Dump table key and value.
		for k, v in pairs(cObject) do
			-- Check key type.
			local strKeyType = type(k)
			if "table" == strKeyType then
				if not bWeakK then
					CollectObjectReferenceInMemory(strName .. ".[table:key.table]", k, cDumpInfoContainer)
				end

				if not bWeakV then
					CollectObjectReferenceInMemory(strName .. ".[table:value]", v, cDumpInfoContainer)
				end
			elseif "function" == strKeyType then
				if not bWeakK then
					CollectObjectReferenceInMemory(strName .. ".[table:key.function]", k, cDumpInfoContainer)
				end

				if not bWeakV then
					CollectObjectReferenceInMemory(strName .. ".[table:value]", v, cDumpInfoContainer)
				end
			elseif "thread" == strKeyType then
				if not bWeakK then
					CollectObjectReferenceInMemory(strName .. ".[table:key.thread]", k, cDumpInfoContainer)
				end

				if not bWeakV then
					CollectObjectReferenceInMemory(strName .. ".[table:value]", v, cDumpInfoContainer)
				end
			elseif "userdata" == strKeyType then
				if not bWeakK then
					CollectObjectReferenceInMemory(strName .. ".[table:key.userdata]", k, cDumpInfoContainer)
				end

				if not bWeakV then
					CollectObjectReferenceInMemory(strName .. ".[table:value]", v, cDumpInfoContainer)
				end
			else
				CollectObjectReferenceInMemory(strName .. "." .. k, v, cDumpInfoContainer)
			end
		end

		-- Dump metatable.
		if cMt then
			CollectObjectReferenceInMemory(strName ..".[metatable]", cMt, cDumpInfoContainer)
		end

	elseif "function" == strType then
        -- Write this info.
        cRefInfoContainer[cObject] = (cRefInfoContainer[cObject] and (cRefInfoContainer[cObject] + 1)) or 1
        if cNameInfoContainer[cObject] then
            return
        end

        -- 遍历function的upvalue表和env表
        -- Get function info.
        local cDInfo = debug.getinfo(cObject, "Su")

        -- Set name.
        cNameInfoContainer[cObject] = strName .. "[line:" .. tostring(cDInfo.linedefined) .. "@file:" .. cDInfo.short_src .. "]"

        if not config.searchFunction then
            return
        end

        -- Get upvalues.
        local nUpsNum = cDInfo.nups
        for i = 1, nUpsNum do
            local strUpName, cUpValue = debug.getupvalue(cObject, i)
            local strUpValueType = type(cUpValue)
            --print(strUpName, cUpValue)
            if "table" == strUpValueType then
                CollectObjectReferenceInMemory(strName .. ".[ups:table:" .. strUpName .. "]", cUpValue, cDumpInfoContainer)
            elseif "function" == strUpValueType then
                CollectObjectReferenceInMemory(strName .. ".[ups:function:" .. strUpName .. "]", cUpValue, cDumpInfoContainer)
            elseif "thread" == strUpValueType then
                CollectObjectReferenceInMemory(strName .. ".[ups:thread:" .. strUpName .. "]", cUpValue, cDumpInfoContainer)
            elseif "userdata" == strUpValueType then
                CollectObjectReferenceInMemory(strName .. ".[ups:userdata:" .. strUpName .. "]", cUpValue, cDumpInfoContainer)
            end
        end

        -- Dump environment table.
        local getfenv = debug.getfenv
        if getfenv then
            local cEnv = getfenv(cObject)
            if cEnv then
                CollectObjectReferenceInMemory(strName ..".[function:environment]", cEnv, cDumpInfoContainer)
            end
        end

	elseif "thread" == strType then
        -- Add reference and name.
        cRefInfoContainer[cObject] = (cRefInfoContainer[cObject] and (cRefInfoContainer[cObject] + 1)) or 1
        if cNameInfoContainer[cObject] then
            return
        end

        -- Set name.
        cNameInfoContainer[cObject] = strName

        if not config.searchThread then
            return
        end

        -- 遍历thread的metatable和env表
        -- Dump environment table.
        local getfenv = debug.getfenv
        if getfenv then
            local cEnv = getfenv(cObject)
            if cEnv then
                CollectObjectReferenceInMemory(strName ..".[thread:environment]", cEnv, cDumpInfoContainer)
            end
        end

        -- Dump metatable.
        local cMt = getmetatable(cObject)
        if cMt then
            CollectObjectReferenceInMemory(strName ..".[thread:metatable]", cMt, cDumpInfoContainer)
        end

	elseif "userdata" == strType then
		-- Add reference and name.
		cRefInfoContainer[cObject] = (cRefInfoContainer[cObject] and (cRefInfoContainer[cObject] + 1)) or 1
		if cNameInfoContainer[cObject] then
			return
		end

		-- Set name.
		cNameInfoContainer[cObject] = strName

		-- Dump environment table.
		local getfenv = debug.getfenv
		if getfenv then
			local cEnv = getfenv(cObject)
			if cEnv then
				CollectObjectReferenceInMemory(strName ..".[userdata:environment]", cEnv, cDumpInfoContainer)
			end
		end

		-- Dump metatable.
		local cMt = getmetatable(cObject)
		if cMt then
			CollectObjectReferenceInMemory(strName ..".[userdata:metatable]", cMt, cDumpInfoContainer)
		end

    elseif "string" == strType then
        -- 不统计string
        if false then
            -- Add reference and name.
            cRefInfoContainer[cObject] = (cRefInfoContainer[cObject] and (cRefInfoContainer[cObject] + 1)) or 1
            if cNameInfoContainer[cObject] then
                return
            end

            -- Set name.
            cNameInfoContainer[cObject] = strName .. "[" .. strType .. "]"
        end
	else
        -- 不统计基础类型
		-- For "number" and "boolean". (If you want to dump them, uncomment the followed lines.)

		-- -- Add reference and name.
		-- cRefInfoContainer[cObject] = (cRefInfoContainer[cObject] and (cRefInfoContainer[cObject] + 1)) or 1
		-- if cNameInfoContainer[cObject] then
		-- 	return
		-- end

		-- -- Set name.
		-- cNameInfoContainer[cObject] = strName .. "[" .. strType .. ":" .. tostring(cObject) .. "]"
	end
end

local function DumpContainer(container)
    local cRefInfoContainer = container.m_cObjectReferenceCount
	local cNameInfoContainer = container.m_cObjectAddressToName

    for k,v in pairs(cRefInfoContainer) do
        print(k, type(k), cNameInfoContainer[k], v)
    end

    print('')
end


-- Get the format string of date time.
local function FormatDateTimeNow()
	local cDateTime = os.date("*t")
	local strDateTime = string.format("%04d%02d%02d-%02d%02d%02d", tostring(cDateTime.year), tostring(cDateTime.month), tostring(cDateTime.day),
		tostring(cDateTime.hour), tostring(cDateTime.min), tostring(cDateTime.sec))
	return strDateTime
end

-- Get the string result without overrided __tostring.
local function GetOriginalToStringResult(cObject)
	if not cObject then
		return ""
	end

	local cMt = getmetatable(cObject)
	if not cMt then
		return tostring(cObject)
	end

	-- Check tostring override.
	local strName = ""
	local cToString = rawget(cMt, "__tostring")
	if cToString then
		rawset(cMt, "__tostring", nil)
		strName = tostring(cObject)
		rawset(cMt, "__tostring", cToString)
	else
		strName = tostring(cObject)
	end

	return strName
end


local function DumpContainerToFile(strSavePath, strExtraFileName, nMaxRescords, strRootObjectName, cRootObject, cDumpInfoResultsBase, cDumpInfoResults)
	-- Check results.
	if not cDumpInfoResults then
		return
	end

	-- Get time format string.
	local strDateTime = FormatDateTimeNow()


	-- Collect memory info.
	local cRefInfoBase = (cDumpInfoResultsBase and cDumpInfoResultsBase.m_cObjectReferenceCount) or nil
	local cNameInfoBase = (cDumpInfoResultsBase and cDumpInfoResultsBase.m_cObjectAddressToName) or nil
	local cRefInfo = cDumpInfoResults.m_cObjectReferenceCount
	local cNameInfo = cDumpInfoResults.m_cObjectAddressToName
	
	-- Create a cache result to sort by ref count.
	local cRes = {}
	local nIdx = 0
	for k in pairs(cRefInfo) do
		nIdx = nIdx + 1
		cRes[nIdx] = k
	end

    if config.dumpSorted then
        -- Sort result.
        table.sort(cRes, function (l, r)
            return cRefInfo[l] > cRefInfo[r]
        end)
    end

	-- Save result to file.
	local bOutputFile = strSavePath and (string.len(strSavePath) > 0)
	local cOutputHandle = nil
	local cOutputEntry = print

	if bOutputFile then
		-- Check save path affix.
		local strAffix = string.sub(strSavePath, -1)
		if ("/" ~= strAffix) and ("\\" ~= strAffix) then
			strSavePath = strSavePath .. "/"
		end

        local config = config
		-- Combine file name.
		local strFileName = strSavePath .. "LuaMemRefInfo-All"
		if (not strExtraFileName) or (0 == string.len(strExtraFileName)) then
            if cDumpInfoResultsBase then
                if config.m_bComparedMemoryRefFileAddTime then
                    strFileName = strFileName .. "-[" .. strDateTime .. "].txt"
                else
                    strFileName = strFileName .. ".txt"
                end
            else
                if config.m_bAllMemoryRefFileAddTime then
                    strFileName = strFileName .. "-[" .. strDateTime .. "].txt"
                else
                    strFileName = strFileName .. ".txt"
                end
            end
		else
            if cDumpInfoResultsBase then
                if config.m_bComparedMemoryRefFileAddTime then
                    strFileName = strFileName .. "-[" .. strDateTime .. "]-[" .. strExtraFileName .. "].txt"
                else
                    strFileName = strFileName .. "-[" .. strExtraFileName .. "].txt"
                end
            else
                if config.m_bAllMemoryRefFileAddTime then
                    strFileName = strFileName .. "-[" .. strDateTime .. "]-[" .. strExtraFileName .. "].txt"
                else
                    strFileName = strFileName .. "-[" .. strExtraFileName .. "].txt"
                end
            end
		end

		local cFile = assert(io.open(strFileName, "w"))
		cOutputHandle = cFile
		cOutputEntry = cFile.write
	end

	local cOutputer = function (strContent)
		if cOutputHandle then
			cOutputEntry(cOutputHandle, strContent)
		else
			cOutputEntry(strContent)
		end
	end

	-- Write table header.
	if cDumpInfoResultsBase then
		cOutputer("--------------------------------------------------------\n")
		cOutputer("-- This is compared memory information.\n")

		cOutputer("--------------------------------------------------------\n")
		cOutputer("-- Collect base memory reference at line:" .. tostring(cDumpInfoResultsBase.m_nCurrentLine) .. "@file:" .. cDumpInfoResultsBase.m_strShortSrc .. "\n")
		cOutputer("-- Collect compared memory reference at line:" .. tostring(cDumpInfoResults.m_nCurrentLine) .. "@file:" .. cDumpInfoResults.m_strShortSrc .. "\n")
	else
		cOutputer("--------------------------------------------------------\n")
		cOutputer("-- Collect memory reference at line:" .. tostring(cDumpInfoResults.m_nCurrentLine) .. "@file:" .. cDumpInfoResults.m_strShortSrc .. "\n")
	end

	cOutputer("--------------------------------------------------------\n")
	cOutputer("-- [Table/Function/String Address/Name]\t[Reference Path]\t[Reference Count]\n")
	cOutputer("--------------------------------------------------------\n")

	if strRootObjectName and cRootObject then
        if "string" == type(cRootObject) then
            cOutputer("-- From Root Object: \"" .. tostring(cRootObject) .. "\" (" .. strRootObjectName .. ")\n")
        else
            cOutputer("-- From Root Object: " .. GetOriginalToStringResult(cRootObject) .. " (" .. strRootObjectName .. ")\n")
        end
	end

	-- Save each info.
	for i, v in ipairs(cRes) do
        local objType = type(v)
        if config.dumpUserDataOnly and "userdata" == objType then
            if (not cDumpInfoResultsBase) or (not cRefInfoBase[v]) then
                if (nMaxRescords > 0) then
                    if (i <= nMaxRescords) then
                        if "string" == objType then
                            local strOrgString = tostring(v)
                            local nPattenBegin, nPattenEnd = string.find(strOrgString, "string: \".*\"")
                            if ((not cDumpInfoResultsBase) and ((nil == nPattenBegin) or (nil == nPattenEnd))) then
                                local strRepString = string.gsub(strOrgString, "([\n\r])", "\\n")
                                cOutputer("string: \"" .. strRepString .. "\"\t" .. cNameInfo[v] .. "\t" .. tostring(cRefInfo[v]) .. "\n")
                            else
                                cOutputer(tostring(v) .. "\t" .. cNameInfo[v] .. "\t" .. tostring(cRefInfo[v]) .. "\n")
                            end
                        else
                            cOutputer(GetOriginalToStringResult(v) .. "\t" .. cNameInfo[v] .. "\t" .. tostring(cRefInfo[v]) .. "\n")
                        end
                    end
                else
                    if "string" == objType then
                        local strOrgString = tostring(v)
                        local nPattenBegin, nPattenEnd = string.find(strOrgString, "string: \".*\"")
                        if ((not cDumpInfoResultsBase) and ((nil == nPattenBegin) or (nil == nPattenEnd))) then
                            local strRepString = string.gsub(strOrgString, "([\n\r])", "\\n")
                            cOutputer("string: \"" .. strRepString .. "\"\t" .. cNameInfo[v] .. "\t" .. tostring(cRefInfo[v]) .. "\n")
                        else
                            cOutputer(tostring(v) .. "\t" .. cNameInfo[v] .. "\t" .. tostring(cRefInfo[v]) .. "\n")
                        end
                    else
                        cOutputer(GetOriginalToStringResult(v) .. "\t" .. cNameInfo[v] .. "\t" .. tostring(cRefInfo[v]) .. "\n")
                    end
                end
            end
        end
	end

	if bOutputFile then
		io.close(cOutputHandle)
        cOutputHandle = nil
	end
end

local function DumpMemorySnapshot(strSavePath, strExtraFileName, nMaxRescords, strRootObjectName, cRootObject)
	-- Get time format string.
	local strDateTime = FormatDateTimeNow()

	-- Check root object.
	if cRootObject then
		if (not strRootObjectName) or (0 == string.len(strRootObjectName)) then
			strRootObjectName = tostring(cRootObject)
		end
	else
		cRootObject = debug.getregistry()
		strRootObjectName = "registry"
	end

	-- Create container.
	local cDumpInfoContainer = CreateObjectReferenceInfoContainer()
	local cStackInfo = debug.getinfo(2, "Sl")
	if cStackInfo then
		cDumpInfoContainer.m_strShortSrc = cStackInfo.short_src
		cDumpInfoContainer.m_nCurrentLine = cStackInfo.currentline
	end

	-- Collect memory info.
	CollectObjectReferenceInMemory(strRootObjectName, cRootObject, cDumpInfoContainer)
	
	-- Dump the result.
	DumpContainerToFile(strSavePath, strExtraFileName, nMaxRescords, strRootObjectName, cRootObject, nil, cDumpInfoContainer)
end

local exporter = {}
exporter.CollectObjectReferenceInMemory = CollectObjectReferenceInMemory
exporter.CreateObjectReferenceInfoContainer = CreateObjectReferenceInfoContainer
exporter.DumpContainer = DumpContainer
exporter.DumpContainerToFile = DumpContainerToFile
exporter.DumpMemorySnapshot = DumpMemorySnapshot
exporter.config = config
return exporter

