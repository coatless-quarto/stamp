---@type StampUtils
local stamp_utils = require("stamp-utils")

---@class Extension
---@field info table
---@field location string

---@class ExtensionData
---@field name string
---@field data Extension

---@class StampExtensions
---@field get_extension_info fun(): table<string, Extension>
---@field create_extensions_table fun(exts: table<string, Extension>): pandoc.Table
---@field get_extensions_section fun(): pandoc.Div
local stamp_extensions = {}

-- Scans filesystem for Quarto extension configuration files and collects their information
---@return table<string, Extension> Table mapping extension names to their information
function stamp_extensions.get_extension_info()
    ---@type table<string, Extension>
    local exts = {}
    -- Patterns to match different extension file locations
    -- Single-level: _extensions/extension-name/_extension.yml
    -- Two-level: _extensions/publisher/extension-name/_extension.yml
    local patterns = {
        "_extensions/([^/]+)/_extension.yml",
        "_extensions/([^/]+)/([^/]+)/_extension.yml"
    }
    
    -- Process a single extension configuration file
    ---@param file string Path to extension file
    ---@param match string[] Captured pattern matches
    local function process_file(file, match)
        local info = stamp_utils.read_yaml_file(file)
        if info then
            local location = (#match == 1) and "local" or (match[1] .. "/" .. match[2])
            local ext_name = match[#match]
            exts[ext_name] = {
                info = info,
                location = location
            }
        end
    end
    
    -- Find and process all extension configuration files
    for path in io.popen('find _extensions -follow -name "_extension.yml"'):lines() do
        for _, pattern in ipairs(patterns) do
            local matches = {path:match(pattern)}
            if #matches > 0 then
                process_file(path, matches)
                break
            end
        end
    end
    
    return exts
end

-- Creates a Pandoc table displaying extension information
---@param exts table<string, Extension> Extension information from get_extension_info
---@return pandoc.Table Table showing extension details
function stamp_extensions.create_extensions_table(exts)
    -- Create table header row
    local header = pandoc.Row({
        pandoc.Cell({ pandoc.Div("Name") }),
        pandoc.Cell({ pandoc.Div("Version") }),
        pandoc.Cell({ pandoc.Div("Location") })
    })
    
    -- Create sorted list of extensions for consistent display
    local rows = pandoc.List()
    ---@type ExtensionData[]
    local sorted_extensions = {}
    for name, data in pairs(exts) do
        table.insert(sorted_extensions, {name = name, data = data})
    end
    table.sort(sorted_extensions, function(a, b) return a.name < b.name end)
    
    -- Create table rows from sorted extensions
    for _, ext in ipairs(sorted_extensions) do
        local version = ext.data.info.version or "unknown"
        rows[#rows + 1] = pandoc.Row({
            pandoc.Cell({ pandoc.Div(ext.name) }),
            pandoc.Cell({ pandoc.Div(version) }),
            pandoc.Cell({ pandoc.Div(ext.data.location) })
        })
    end
    
    -- Create and return formatted table
    return pandoc.Table(
        { long = {}, short = {} },
        {
            { pandoc.AlignLeft, .4 },
            { pandoc.AlignLeft, .3 },
            { pandoc.AlignLeft, .3 }
        },
        pandoc.TableHead({ header }),
        {
            {
                attr = pandoc.Attr(),
                body = rows,
                head = {},
                row_head_columns = 0
            }
        },
        pandoc.TableFoot(),
        pandoc.Attr("", { "extensions-table" })
    )
end

-- Creates a complete section displaying extension information
---@return pandoc.Div Div containing extensions header and table
function stamp_extensions.get_extensions_section()
    local exts = stamp_extensions.get_extension_info()
    local table = stamp_extensions.create_extensions_table(exts)
    
    local div = pandoc.Div({
        pandoc.Header(3, "Extensions"),
        table
    })
    div.attr.classes:insert("extensions-info")
    return div
end

---@type StampExtensions
return stamp_extensions