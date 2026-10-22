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

-- Lists a directory's entries, or nothing if it does not exist
---@param dir string Directory to list
---@return string[] Entry names
local function list_dir(dir)
    local ok, entries = pcall(pandoc.system.list_directory, dir)
    return ok and entries or {}
end

-- Scans the _extensions folders next to the document and at the project
-- root for Quarto extension configuration files and collects their information
---@return table<string, Extension> Table mapping extension names to their information
function stamp_extensions.get_extension_info()
    ---@type table<string, Extension>
    local exts = {}

    -- Process a single extension configuration file
    ---@param dir string Extension directory that may hold _extension.yml
    ---@param ext_name string Extension name
    ---@param location string "local" or "publisher/extension-name"
    ---@return boolean found Whether dir holds an extension
    local function process_dir(dir, ext_name, location)
        local info = stamp_utils.read_yaml_file(pandoc.path.join({dir, "_extension.yml"}))
        if info and not exts[ext_name] then
            exts[ext_name] = {
                info = info,
                location = location
            }
        end
        return info ~= nil
    end

    -- Search the document's directory first, then the project root
    local roots = { pandoc.path.directory(quarto.doc.input_file) }
    if quarto.project.directory and
       pandoc.path.normalize(quarto.project.directory) ~= pandoc.path.normalize(roots[1]) then
        table.insert(roots, quarto.project.directory)
    end

    -- Single-level: _extensions/extension-name/_extension.yml
    -- Two-level: _extensions/publisher/extension-name/_extension.yml
    for _, root in ipairs(roots) do
        local ext_dir = pandoc.path.join({root, "_extensions"})
        for _, entry in ipairs(list_dir(ext_dir)) do
            local entry_dir = pandoc.path.join({ext_dir, entry})
            if not process_dir(entry_dir, entry, "local") then
                for _, name in ipairs(list_dir(entry_dir)) do
                    process_dir(pandoc.path.join({entry_dir, name}), name, entry .. "/" .. name)
                end
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