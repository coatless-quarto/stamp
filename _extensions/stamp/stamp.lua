-- stamp: adds a "Document Information" block that records how the
-- document was rendered (system, Quarto environment, document, project,
-- session and extensions), similar to R's sessioninfo.

---@class StampSection
---@field title string Section heading
---@field class string Class of the section div
---@field table_class string Class of the section table
---@field headers string[] Column headers
---@field widths? number[] Column widths (default: equal)
---@field rows fun(): string[][] Builds the table rows

---@class StampConfig
---@field placement string "bottom" (default), "top" or "custom"
---@field placement_id string Id of the div replaced by custom placement
---@field sections table<string, boolean> Set of enabled section names

---@class StampExtension
---@field name string
---@field version string
---@field location string "local" or "publisher/extension-name"

-- Section names in display order; `level: full` shows all of them
local ORDER = {"system", "environment", "document", "project", "session", "extensions"}

-- Sections included by each level
---@type table<string, string[]>
local LEVELS = {
    minimal = {"system", "session", "extensions"},
    full = ORDER
}

-- Level used when `level` is missing, unknown or "default"
local DEFAULT_LEVEL = "minimal"

-- Friendly names for pandoc.system.os values
local OS_NAMES = { darwin = "macOS", linux = "Linux", mingw32 = "Windows" }

-- Creates a table row with one cell per string
---@param texts string[] Cell texts
---@return pandoc.Row
local function make_row(texts)
    local cells = {}
    for i, text in ipairs(texts) do
        cells[i] = pandoc.Cell({ pandoc.Div(text) })
    end
    return pandoc.Row(cells)
end

-- Creates a left-aligned Pandoc table with any number of columns
---@param headers string[] Column headers
---@param rows string[][] Body rows, one string per cell
---@param class string Class of the table
---@param widths? number[] Column widths as fractions of the line (default: equal)
---@return pandoc.Table
local function make_table(headers, rows, class, widths)
    local colspecs = {}
    for i = 1, #headers do
        colspecs[i] = { pandoc.AlignLeft, widths and widths[i] or 1 / #headers }
    end
    local body = {}
    for i, row in ipairs(rows) do
        body[i] = make_row(row)
    end
    return pandoc.Table(
        { long = {}, short = {} },
        colspecs,
        pandoc.TableHead({ make_row(headers) }),
        { { attr = pandoc.Attr(), body = body, head = {}, row_head_columns = 0 } },
        pandoc.TableFoot(),
        pandoc.Attr("", { class })
    )
end

-- Builds rows from {label, value} pairs, skipping values that are not set
---@param props {[1]: string, [2]: any}[]
---@return string[][]
local function property_rows(props)
    local rows = {}
    for _, prop in ipairs(props) do
        if prop[2] then
            table.insert(rows, { prop[1], tostring(prop[2]) })
        end
    end
    return rows
end

-- Gets the version of R or Python, or "not installed"
---@param program string Program to run with --version
---@param pattern string Lua pattern that captures the version number
---@return string
local function program_version(program, pattern)
    -- Run the program without a shell, so a missing program is an error
    -- here instead of "command not found" on the console
    local ok, output = pcall(pandoc.pipe, program, {"--version"}, "")
    return ok and output:match("^[^\n]*"):match(pattern) or "not installed"
end

-- Lists a directory's entries, or nothing if it does not exist
---@param dir string Directory to list
---@return string[] Entry names
local function list_dir(dir)
    local ok, entries = pcall(pandoc.system.list_directory, dir)
    return ok and entries or {}
end

-- Reads the top-level `version:` of an _extension.yml
---@param file string Path to _extension.yml
---@return string|nil version The version, "unknown" if it has none, or nil if there is no file
local function read_version(file)
    local f = io.open(file, "r")
    if not f then
        return nil
    end
    local content = f:read("a")
    f:close()
    quarto.log.debug("Reading YAML file: " .. file)

    local value = ("\n" .. content):match("\nversion:[ \t]*([^\r\n]*)")
    if not value then
        return "unknown"
    end
    -- Drop a trailing comment and spaces, then any surrounding quotes
    value = value:gsub("%s+#.*$", ""):gsub("%s+$", "")
    value = value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
    return value ~= "" and value or "unknown"
end

-- Collects the extensions in the _extensions folders next to the document
-- and at the project root; the document's folder wins on a name clash
---@return StampExtension[] Extensions sorted by name
local function find_extensions()
    ---@type table<string, StampExtension>
    local found = {}

    -- Records the extension in dir, if it has an _extension.yml
    ---@param dir string Extension directory
    ---@param name string Extension name
    ---@param location string "local" or "publisher/extension-name"
    ---@return boolean found Whether dir holds an extension
    local function add(dir, name, location)
        local version = read_version(pandoc.path.join({dir, "_extension.yml"}))
        if version and not found[name] then
            found[name] = { name = name, version = version, location = location }
        end
        return version ~= nil
    end

    local roots = { pandoc.path.directory(quarto.doc.input_file) }
    local project_dir = quarto.project.directory
    if project_dir and pandoc.path.normalize(project_dir) ~= pandoc.path.normalize(roots[1]) then
        table.insert(roots, project_dir)
    end

    -- Single-level: _extensions/extension-name/_extension.yml
    -- Two-level: _extensions/publisher/extension-name/_extension.yml
    for _, root in ipairs(roots) do
        local ext_dir = pandoc.path.join({root, "_extensions"})
        for _, entry in ipairs(list_dir(ext_dir)) do
            local entry_dir = pandoc.path.join({ext_dir, entry})
            if not add(entry_dir, entry, "local") then
                for _, name in ipairs(list_dir(entry_dir)) do
                    add(pandoc.path.join({entry_dir, name}), name, entry .. "/" .. name)
                end
            end
        end
    end

    ---@type StampExtension[]
    local exts = {}
    for _, ext in pairs(found) do
        table.insert(exts, ext)
    end
    table.sort(exts, function(a, b) return a.name < b.name end)
    return exts
end

-- Every section, by the name that `sections` and the levels use
---@type table<string, StampSection>
local SECTIONS = {
    system = {
        title = "System Information",
        class = "system-info",
        table_class = "system-info-table",
        headers = {"Property", "Value"},
        rows = function()
            return {
                {"Operating System", OS_NAMES[pandoc.system.os] or pandoc.system.os},
                {"Lua Version", _VERSION or "unknown"}
            }
        end
    },
    environment = {
        title = "Quarto Environment Variables",
        class = "quarto-env-info",
        table_class = "quarto-env-vars",
        headers = {"Environment Variable", "Value"},
        rows = function()
            local rows = {}
            for i, name in ipairs({"QUARTO_ROOT", "QUARTO_SHARE_PATH", "QUARTO_BIN_PATH"}) do
                rows[i] = { name, os.getenv(name) or "not set" }
            end
            return rows
        end
    },
    document = {
        title = "Quarto Document Properties",
        class = "quarto-doc-info",
        table_class = "quarto-doc-props",
        headers = {"Property", "Value"},
        rows = function()
            -- Quarto has no quarto.doc.format, so the format row reads the
            -- target format from quarto.format.format_identifier()
            local format_id = quarto.format.format_identifier() --[[@as table]]
            return property_rows({
                {"quarto.doc.input_file", quarto.doc.input_file},
                {"quarto.doc.output_file", quarto.doc.output_file},
                {"format", format_id["target-format"]}
            })
        end
    },
    project = {
        title = "Quarto Project Properties",
        class = "quarto-project-info",
        table_class = "quarto-project-props",
        headers = {"Property", "Value"},
        rows = function()
            return property_rows({
                {"quarto.project.directory", quarto.project.directory},
                {"quarto.project.output_directory", quarto.project.output_directory}
            })
        end
    },
    session = {
        title = "Session Information",
        class = "session-info",
        table_class = "session-info-table",
        headers = {"Software", "Version"},
        rows = function()
            return {
                {"Quarto Version", tostring(quarto.config.version())},
                {"Pandoc Version", tostring(PANDOC_VERSION)},
                {"R Version", program_version("R", "R version ([%d%.]+)")},
                {"Python Version", program_version("python", "Python ([%d%.]+)")}
            }
        end
    },
    extensions = {
        title = "Extensions",
        class = "extensions-info",
        table_class = "extensions-table",
        headers = {"Name", "Version", "Location"},
        widths = {.4, .3, .3},
        rows = function()
            local rows = {}
            for i, ext in ipairs(find_extensions()) do
                rows[i] = { ext.name, ext.version, ext.location }
            end
            return rows
        end
    }
}

-- Creates one section: a heading and its table inside a classed div
---@param spec StampSection
---@return pandoc.Div
local function section(spec)
    return pandoc.Div({
        pandoc.Header(3, pandoc.Inlines(spec.title)),
        make_table(spec.headers, spec.rows(), spec.table_class, spec.widths)
    }, pandoc.Attr("", { spec.class }))
end

-- Reads the stamp options from the document metadata
---@param meta pandoc.Meta
---@return StampConfig
local function read_config(meta)
    -- `stamp: true` (or any non-map value) means "use the defaults"
    local options = meta.stamp
    if type(options) ~= "table" then
        options = {}
    end

    -- Reads an option as a string, or nil if it is not set
    ---@param key string
    ---@return string|nil
    local function option(key)
        return options[key] and pandoc.utils.stringify(options[key]) or nil
    end

    -- Sections named in `sections` (a list or a single value), ignoring unknown names
    local extra = {}
    local listed = options.sections
    if type(listed) == "table" then
        for _, item in ipairs(listed[1] and listed or { listed }) do
            local name = pandoc.utils.stringify(item):lower()
            if SECTIONS[name] then
                table.insert(extra, name)
            end
        end
    end

    local level = (option("level") or DEFAULT_LEVEL):lower()
    local base = LEVELS[level] or LEVELS[DEFAULT_LEVEL]
    -- `mode: replace` shows only the listed sections; the default `add`
    -- combines them with the level's sections
    if (option("mode") or "add"):lower() == "replace" and #extra > 0 then
        base = {}
    end

    local sections = {}
    for _, name in ipairs(base) do sections[name] = true end
    for _, name in ipairs(extra) do sections[name] = true end

    return {
        placement = (option("placement") or "bottom"):lower(),
        placement_id = option("placement-id") or "document-information",
        sections = sections
    }
end

-- Builds the stamp and places it at the top, the bottom or a custom div
---@param doc pandoc.Pandoc
---@return pandoc.Pandoc
local function place_stamp(doc)
    -- `stamp: false` turns the stamp off
    if doc.meta.stamp == false then
        return doc
    end

    local config = read_config(doc.meta)

    local blocks = pandoc.Blocks({ pandoc.Header(2, pandoc.Inlines("Document Information")) })
    for _, name in ipairs(ORDER) do
        if config.sections[name] then
            blocks:insert(section(SECTIONS[name]))
        end
    end
    local info_div = pandoc.Div(blocks, pandoc.Attr("document-information"))

    -- Custom placement replaces the div with the given id, at any depth,
    -- and falls back to the bottom if there is none
    if config.placement == "custom" then
        local placed = false
        -- Blocks:walk returns Blocks; the stubs inherit List:walk's pandoc.List
        doc.blocks = doc.blocks:walk({
            Div = function(div)
                if not placed and div.identifier == config.placement_id then
                    placed = true
                    return info_div
                end
            end
        }) --[[@as pandoc.Blocks]]
        if placed then
            return doc
        end
    elseif config.placement == "top" then
        doc.blocks:insert(1, info_div)
        return doc
    end

    doc.blocks:insert(info_div)
    return doc
end

return {
    { Pandoc = place_stamp }
}
