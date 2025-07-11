require("debug") -- Add forward compatibility for Lua 5.2

function error(str)
    ba.error(str)
end

function warning(str)
    ba.warning(str)
end

function print(str)
    ba.print(str)
end

function println(str)
    if (str) then
        ba.print(str)
    end
    ba.print("\n")
end

function stackError(str, level)
    if (level == nil) then
        level = 2
    else
        level = level + 1
    end

    error(debug.traceback(tostring(str) .. "\n", level) .. "\n")
end

function warningf(str, ...)
    warning(string.format(str, ...))
end

function errorf(str, ...)
    error(string.format(str, ...))
end

function printf(str, ...)
    print(string.format(str, ...))
end

function stackErrorf(str, ...)
    stackError(string.format(str, ...), 2)
end

function string.starts(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

function string.ends(str, e)
    return (e == '') or (string.sub(str, -string.len(e)) == e)
end

-- Nukes execute_lua_file function for executing lua files somewhere in the cfile system
local chunck_cache = {}
function loadLuaFile(filename)
    if (chunck_cache[filename] and chunck_cache[filename][1]) then
        return chunck_cache[filename][1]
    else
        if (cf.fileExists(filename, "", true)) then
            --open the file
            local file = cf.openFile(filename, "r", "")
            local fstring = file:read("*a") --load it all into a string
            file:close()
            if (fstring and type(fstring) == "string") then
                --use the string as a code chunk and convert it to function
                local func, error = loadstring(fstring, filename)
                if (not func) then -- Compile error
                    return nil, string.format("Error while processing file %q. Errormessage:\n%s", filename, error)
                end
                chunck_cache[filename] = {}
                chunck_cache[filename][1] = func
                chunck_cache[filename][2] = false
                --maybe execute
                return func
            end
        else
            return nil, string.format("Couldn't find external lua file %q!", filename)
        end
    end
end

function execute_lua_file(filename, cacheonly)
    --dont reload chunks from file if they have already been loaded. because faster == badass
    if (type(chunck_cache[filename]) == "table" and type(chunck_cache[filename][1]) == "function") then
        if (not chunck_cache[filename][2] and not chunck_cache[filename][3]) then

            chunck_cache[filename][2] = true
            local success, ret = xpcall(chunck_cache[filename][1], function(err)
            -- Add an boolean to indicate that this function has caused an error
                chunck_cache[filename][3] = true

                return string.format("Error while executing external lua file %q:\n%s\n\n%s", filename, err, debug.traceback())
            end)

            return success, ret
        else
            return true
        end
    else
        local func, err = loadLuaFile(filename)

        if (func ~= nil) then
            if (cacheonly) then
                return true
            end

            chunck_cache[filename][2] = true
            local success, ret = xpcall(chunck_cache[filename][1], function(err)
            -- Add an boolean to indicate that this function has caused an error
                chunck_cache[filename][3] = true

                return string.format("Error while executing external lua file %q:\n%s\n\n%s", filename, err, debug.traceback())
            end)

            return success, ret
        else
            return false, err
        end
    end
end

function include(fileName)
    if (fileName == nil) then
        stackErrorf("Invalid argument for 'include'!")
    else
        if (not fileName:ends(".lua")) then
            fileName = fileName .. ".lua"
        end

        local success, ret = execute_lua_file(fileName)

        if (not success) then
            stackError(ret)
        else
            return ret
        end
    end
end

function hookVarsContain(name)
    for i = 1, #hv.Globals do
        if (hv.Globals[i] == name) then
            return true
        end
    end

    return false
end

-- Global table that can hold variables that should not be able to be changed
Globals = {}
Globals.values = {}

local mt = {}

function mt.__newindex(t, index, value)
    if (index == "values") then
        stackErrorf("Cannot set value to index %q. Index is forbidden!", tostring(index))
    elseif (rawget(t.values, index) ~= nil) then
        stackErrorf("Cannot set value to index %q. Index already used!", tostring(index))
    else
        rawset(t.values, index, value)
    end
end

function mt.__index(t, index)
    if (index == "values") then
        stackErrorf("Trying to access forbidden value %q!", index)
    else
        return rawget(t.values, index)
    end
end

setmetatable(Globals, mt)

-- InitialValues
Globals.nullVec = ba.createVector(0, 0, 0)
Globals.zeroVec = Globals.nullVec
if ba.isEngineVersionAtLeast(21,0,0) then
    Globals.identityOrient = ba.createOrientationFromVectors(ba.createVector(0, 0, 1), ba.createVector(0, 1, 0), ba.createVector(1, 0, 0))
end

-----------------------------------------------------------
-- Implementation of a module loader for the CFilesystem --
-----------------------------------------------------------
local function load(modulename)
    if (not modulename:ends(".lua")) then
        modulename = modulename .. ".lua"
    end

    local func, err = loadLuaFile(modulename)

    if (func) then
        return func
    else
        return "\n" .. err
    end
end

-- Install the loader so that it's called just before the normal Lua loader
table.insert(package.loaders, 2, load)