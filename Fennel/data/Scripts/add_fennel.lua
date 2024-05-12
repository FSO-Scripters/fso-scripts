--FSO's API provides a utf8 object... as a userdata
--  that bloes up the fennel library, so we hide it and put a
--  table of wrappers around the api functions in it's place
_G._utf8 = _G.utf8
_G.utf8 = {}
_G.utf8.sub = function(...) return _utf8.sub(...) end
_G.utf8.len = function(...) return _utf8.len(...) end

local fennel = require("fennel")

--when true, txt files containing the compiled fennel will be
--  written into the final directory in the mod load order, typically
--  appdata.
fennel_emit_debug_lua = true

local fso_fennel_searcher = function(env)
    return function(module_name)
        local path=module_name:gsub("%./*", "") .. ".fnl"
        if cf.fileExists(path) then
            return function(...)
                local file = cf.openFile(path,"r","data/scripts")
                local code = file:read("*a")
                file:close();
                local opts = {}
                opts["compiler-env"]=env
                opts["env"]=env
                opts["unfriendly"]=true
                opts["filename"]=path
               if(fennel_emit_debug_lua) then 
                    local l_code = fennel.compileString(code,opts)
                    local lfile = cf.openFile(module_name..".txt","w+","data")
                    lfile:write(l_code)
                    lfile:flush()
                    lfile:close()
                end
                ba.print("fennel searcher compiled " .. path .. "\n")
                return fennel.eval(code,opts, ...)
            end, path
        end
    end
end

table.insert(package.loaders or package.searchers, fso_fennel_searcher(_e))
--This doesn't seem to actually work, so I'm commenting it out.
--table.insert(fennel["macro-searchers"], fso_fennel_searcher("_COMPILER"))

return {
    ["-reqver-version-info"] = {1, 3, 0}}