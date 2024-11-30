---@class StampSystem
---@field get_os fun(): string
---@field get_version fun(cmd: string): string
---@field get_system_info fun(): pandoc.Div
local stamp_system = {}

-- Detects the operating system using multiple detection methods
---@return string Operating system name: "Windows", "macOS", "Linux" or "unknown" 
function stamp_system.get_os()
   -- Try using uname first as most reliable method
   local handle = io.popen("uname -s 2>&1")
   if handle then
       local result = handle:read("*l")
       handle:close()
       
       if result and result:match("^%u") then
           -- Map common uname outputs to friendly OS names
           ---@type table<string,string>
           local os_map = {
               ["^Darwin"] = "macOS",
               ["^Linux"] = "Linux", 
               ["^MINGW"] = "Windows",
               ["^MSYS"] = "Windows"
           }
           
           for pattern, os_name in pairs(os_map) do
               if result:match(pattern) then
                   return os_name
               end
           end
           return result
       end
   end

   -- Fallback detection methods if uname fails
   if os.getenv("OS") == "Windows_NT" then
       return "Windows"
   elseif os.getenv("HOME") then
       if os.getenv("HOME"):match("^/Users/") then
           return "macOS"
       end
       return "Linux"
   end

   return "unknown"
end

-- Gets version information for R or Python
---@param cmd string Command to execute to get version info
---@return string Version string or "not installed" if not found
function stamp_system.get_version(cmd)
   local handle = io.popen(cmd)
   local version = "not installed"
   
   if handle then
       local output = handle:read("*l")
       handle:close()
       
       if output then
           -- Extract version number based on command type
           if cmd:match("R") then
               version = output:match("R version ([%d%.]+)") or version
           else
               version = output:match("Python ([%d%.]+)") or version
           end
       end
   end
   
   return version
end

-- Creates a formatted div containing system information
---@return pandoc.Div Div containing system information table
function stamp_system.get_system_info()
   local rows = pandoc.List()

   -- Add system information rows
   rows[#rows + 1] = pandoc.Row({
       pandoc.Cell({ pandoc.Div("Operating System") }),
       pandoc.Cell({ pandoc.Div(stamp_system.get_os()) })
   })
   
   rows[#rows + 1] = pandoc.Row({
       pandoc.Cell({ pandoc.Div("Lua Version") }),
       pandoc.Cell({ pandoc.Div(_G._VERSION or "unknown") })
   })

   local div = pandoc.Div({
       pandoc.Header(3, "System Information"),
       pandoc.Table(
           { long = {}, short = {} },
           {
               { pandoc.AlignLeft, .5 },
               { pandoc.AlignLeft, .5 }
           },
           pandoc.TableHead({
               pandoc.Row({
                   pandoc.Cell({ pandoc.Div("Property") }),
                   pandoc.Cell({ pandoc.Div("Value") })
               })
           }),
           {
               {
                   attr = pandoc.Attr(),
                   body = rows,
                   head = {},
                   row_head_columns = 0
               }
           },
           pandoc.TableFoot(),
           pandoc.Attr("", { "system-info-table" })
       )
   })
   
   div.attr.classes:insert("system-info")
   return div
end

---@type StampSystem
return stamp_system