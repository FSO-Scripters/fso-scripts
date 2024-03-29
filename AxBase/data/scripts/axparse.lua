local axemParse = {}

function axemParse:Open(file, directory)	--Load a file into a table

	local gsub = string.gsub
	
	directory = directory or "data/config"

	local t = {}	--Table used to store the file, one line per table element
		
		if cf.fileExists(file,directory,true) then		--Check that the file exists		
			local thisFile = cf.openFile(file,"rb",directory)	--Open the file
			local i = 1 --Setting up the line number
			
			while true do
				local line = thisFile:read("*l") --Read a line

				if line == nil then break end --If we hit the end, break out
			
				if line ~= "" then
					line = gsub(line, "\\n","\n") --Replace instances with a literal \n with a real line break
					line = gsub(line, "\\t","\t") --Replace instances with a literal \t with a real tab
					t[i] = line
					i = i+1
				end
			
			end
			
			thisFile:close()	--Close the file
			ba.print("AXEMPARSE: LOAD SUCESSFUL!\n")
			return t		--Return the table
		else
			ba.print("AXEMPARSE: SOMETHING WENT HORRIBLY WRONG!\n")
			--ba.error("Problems loading file " .. file)
			return false	--If the file hasn't been loaded, return false
		end
	
end

function axemParse:ParseLine(line, xstr)

	if line then 
	
		local find, sub, lower, gsub = string.find, string.sub, string.lower, string.gsub

		local key, value

		--if find(line, "%%") == 1 then
		--	return nil, nil
		--end
		
		if find(line, "@") then
			local j = find(line, "@") --Find out where our special strings are
			local k = find(line, ":")
			
			key = sub(line,j+1,k-1)
			value = sub(line, k+1)
			
			value = gsub(value, "^%s*(.-)%s*$", "%1")

			if not xstr then
				ba.print("AXEMPARSE: Parsing line... " .. line .. "\nkey = '" .. tostring(key) .. "', value = '" .. tostring(value) .. "'\n")
			else
				if key == "XSTR" then ba.print("Found XSTR! Value is '" .. value .. "'\n") end
			end

			return key, value
			
		end
	
	end

end

function axemParse:ToTable(file) --Returns a table!!

	local f = axemParse:Open(file)	-- The raw data file, its a table but needs some refinement
	local fLength = #f
	local finalTable = {}			-- Our end table
	local index = 0
	
	local find, sub, lower = string.find, string.sub, string.lower
	
	ba.print("BEGINNING PARSE OF: " .. file .. "\n")

	for i=1, fLength do
	
		local line = f[i]
		local nextLine = f[i+1]
		
		local key, value = self:ParseLine(line)
		
		if key and lower(key) == "index" then
		
			if not value or value == "" then
				value = index + 1
			end
			
			local oldvalue = value
			
			index = tonumber(value)
						
			finalTable[index] = {}
			
		end
		
		if key and lower(key) ~= "index" and lower(key) ~= "xstr" then
							
			if lower(value) == "true" then
				value = true
			elseif lower(value) == "false" then
				value = false
			elseif type(value) == "number" then
				value = tonumber(value)
			elseif type(value) == "string" then
				local nextKey, nextValue = self:ParseLine(nextLine, true)
				if nextKey and nextValue and lower(nextKey) == "xstr" and type(nextValue) == "number" then
					value = ba.XSTR(value, nextValue)
				end
			end
			
			finalTable[index][key] = value
			
		end

	end
	
	return finalTable

end

function axemParse:TestWrite()

	local testData = {}
	
	testData[1] = {item="Hi", value="What's up?"}
	testData[2] = {item="NM", value="You?"}

	axemParse:Write(testData, "test.txt", "data/config")

end

function axemParse:Write(t, filename, path)

	local tt = {}

	local file = cf.openFile(filename, "w+", path)
	
	for i = 1, #t do
	
		tt = t[i]
		
		file:write("@Index: \n")
		
		for key,value in pairs(tt) do
			ba.print("Attempting to write to index " .. i .. ": " .. key .. ": " .. tostring(value) .. "\n")
			file:write("@" .. key .. ": " .. tostring(value) .. "\n")
		end
		
		file:write("\n")
	
	end
	
	file:close()

end

function axemParse:Validate(reference, input, expectedtypes, optional)

	if type(expectedtypes) == "string" then
		expectedtypes = { expectedtypes }
	end

	if not input and optional then
		return true
	else
		for i, v in ipairs(expectedtypes) do
			if type(input) == v then
				return true
			end
		end

		local s = expectedtypes[1]
		for i = 2, #expectedtypes do
			s = s .. ", " .. expectedtypes[i]
		end
		ba.warning("Invalid entry for " .. reference .. ", expected one of [" .. s .. "]")
	end

end

function axemParse:ReadJSON(file, path)

	ba.print("Beginning JSON Parse for " .. file .. "\n")
	
	local json = require ("dkjson")
	local t = nil
	
	if path == nil then
		path = "data/config"
		ba.print("No path specified, assuming data/config...\n")
	else
		ba.print("Custom path specified, using " .. path .. "\n")
	end
	
	if cf.fileExists(file,path,true) then
	
		--[[
		
		--Localization Support
		
		local language = ba.getCurrentLanguageExtension()
		
		if language ~= "" then
			ba.print("Attempting to find localized config file... ")
			
			local newfile = file .. "-" .. language
			
			ba.print("searching for " .. newfile .. "... ")
			
			if cf.fileExists(newfile,path,true) then
				ba.print("SUCCESS!\n")
				file = newfile
			else
				ba.print("couldn't find!\n")
			end
		end
		
		]]--
	
		ba.print(file .. " exists, decoding...")
	
		local thisFile = cf.openFile(file,"rb",path)
		local contents = thisFile:read("*a")
		
		t = json.decode(contents)
		
		ba.print(" success!\n")
		
		thisFile:close()
	else
		ba.print("File " .. file .. " does not exist! Here be dragons!\n")
		t = {}
	end
	
	return t

end

function axemParse:WriteJSON(t, filename, path)

	ba.print("Beginning JSON Write for " .. filename .. "\n")

	local json = require ("dkjson")
	
	if path == nil then
		path = "data/config"
		ba.print("No path specified, assuming data/config...\n")
	else
		ba.print("Custom path specified, using " .. path .. "\n")
	end
	
	local file = cf.openFile(filename, "w+", path)
	
	file:write(json.encode(t))
	
	ba.print("Write complete, closing file.\n")
	
	file:close()

end

function SDX(key, value, sexp, campaignonly, suffix) --Save Data for purposes of eXchanging between campaigns

	if mn.isInCampaign() then
	
		local t = {}
		
		suffix = suffix or "-sdx"

		--generate SDX file name
		local filename = ba.getCurrentPlayer():getName() .. suffix .. ".sav"
		
		--load sdx data file if available, if not create it
		t = axemParse:ReadJSON(filename)
		
		--should we grab the value from a sexp variable instead?
		if sexp then
			if mn.SEXPVariables[value]:isValid() then
				value = mn.SEXPVariables[value].Value
			else
				value = nil
			end
		end
		
		if not value then
			value = "NULL"
		end
		
		--add data to table
		ba.print("SDX WRITE: Key: " .. key .. " = " .. value .. ", to file " .. filename .. "\n")
		t[key] = value
		
		--export as json file
		axemParse:WriteJSON(t, filename)
		
	end

end

function axSaveData(key, value, suffix)

	SDX(key, value, false, nil, suffix)

end

function LDX(key, suffix, variable) -- Load Data for purposes of eXchanging between campaigns

	local t = {}
	
	suffix = suffix or "-sdx"

	--generate SDX file name
	local filename = ba.getCurrentPlayer():getName() .. suffix .. ".sav"
	
	ba.print(filename .. "\n")
	
	--load sdx data file if available, if not return
	t = axemParse:ReadJSON(filename)
	
	if not variable then
	
		if not t then
			return 0
		end
		
		return t[key] or 0
		
	else
	
		if not t then
			variable.Value = ""
		else
			if t[key] then
				variable.Value = t[key]
			else
				variable.Value = ""
			end
		end
		
	end

end

function axLoadDataInt(key, suffix)

	LDX(key, suffix, nil)

end

function axLoadDataStr(key, variable, suffix)

	LDX(key, suffix, variable)

end

function CDX(campaignonly, suffix) -- Clears saved data

	if mn.isInCampaign() then

		suffix = suffix or "-sdx"

		local filename = ba.getCurrentPlayer():getName() .. suffix .. ".sav"
		
		if cf.fileExists(filename,"data/config", true) then
			deleteFile(filename, "data/config")
		end
		
	end
		
end


if mn.LuaSEXPs ~= nil then --backwards-compatibility guard
	mn.LuaSEXPs["lua-save-data-integer"].Action = axSaveData

	mn.LuaSEXPs["lua-save-data-string"].Action = axSaveData

    mn.LuaSEXPs["lua-get-data-integer"].Action = axLoadDataInt

    mn.LuaSEXPs["lua-get-data-string"].Action = axLoadDataStr

    mn.LuaSEXPs["lua-clear-saved-data"].Action = CDX
end

function trim(str)
	return str:find'^%s*$' and '' or str:match'^%s*(.*%S)'
end

function removeComments(line)
	local cut = line:find(";") -- there's gotta be something more robust than that hack job
	if (cut == nil) then
		return line
	else
		return line:sub(0, cut - 1)
	end
end

function extractLeft(attribute)
	local line = attribute
	local cut = string.find(line, ":")
	if (cut == nil) then
		return trim(line)
	else
		return trim(string.sub(line, 2, cut - 1))
	end
end

function extractRight(attribute)
	local line = attribute
	local cut = string.find(line, ":")
	if (cut == nil) then
		return trim(line)
	else
		return trim(string.sub(line, cut + 1))
	end
end

return axemParse