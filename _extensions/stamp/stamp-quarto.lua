---@type StampUtils
local stamp_utils = require("stamp-utils")
---@type StampSystem
local stamp_system = require("stamp-system")

---@class StampQuarto
---@field get_env_vars fun(): pandoc.Row[]
---@field get_doc_props fun(): pandoc.Row[]
---@field get_project_props fun(): pandoc.Row[]
---@field get_environment_section fun(): pandoc.Div
---@field get_document_section fun(): pandoc.Div
---@field get_project_section fun(): pandoc.Div
---@field get_session_section fun(): pandoc.Div
local stamp_quarto = {}

-- Collects Quarto environment variables and creates table rows
---@return pandoc.Row[] Array of rows containing environment variables
function stamp_quarto.get_env_vars()
    ---@type {[1]: string, [2]: string}[]
    local env_vars = {
        {"QUARTO_ROOT", os.getenv("QUARTO_ROOT") or "not set"},
        {"QUARTO_SHARE_PATH", os.getenv("QUARTO_SHARE_PATH") or "not set"},
        {"QUARTO_BIN_PATH", os.getenv("QUARTO_BIN_PATH") or "not set"}
    }
    
    local rows = pandoc.List()
    for _, var in ipairs(env_vars) do
        rows[#rows + 1] = pandoc.Row({
            pandoc.Cell({ pandoc.Div(var[1]) }),
            pandoc.Cell({ pandoc.Div(var[2]) })
        })
    end
    return rows
end

-- Collects Quarto document properties and creates table rows
---@return pandoc.Row[] Array of rows containing document properties
function stamp_quarto.get_doc_props()
    local rows = pandoc.List()
    ---@type {[1]: string, [2]: any}[]
    local doc_props = {
        {"input_file", quarto.doc.input_file},
        {"output_file", quarto.doc.output_file},
        {"format", quarto.doc.format},
        {"render_tools", quarto.doc.render_tools}
    }
    
    for _, prop in ipairs(doc_props) do
        if prop[2] then
            rows[#rows + 1] = pandoc.Row({
                pandoc.Cell({ pandoc.Div("quarto.doc." .. prop[1]) }),
                pandoc.Cell({ pandoc.Div(tostring(prop[2])) })
            })
        end
    end
    return rows
end

-- Collects Quarto project properties and creates table rows
---@return pandoc.Row[] Array of rows containing project properties
function stamp_quarto.get_project_props()
    local rows = pandoc.List()
    ---@type {[1]: string, [2]: any}[]
    local project_props = {
        {"dir", quarto.project.dir},
        {"output_directory", quarto.project.output_directory},
        {"render_tools", quarto.project.render_tools}
    }
    
    for _, prop in ipairs(project_props) do
        if prop[2] then
            rows[#rows + 1] = pandoc.Row({
                pandoc.Cell({ pandoc.Div("quarto.project." .. prop[1]) }),
                pandoc.Cell({ pandoc.Div(tostring(prop[2])) })
            })
        end
    end
    return rows
end

-- Creates environment variables section with header and table
---@return pandoc.Div Division containing environment section
function stamp_quarto.get_environment_section()
    local env_table = stamp_utils.create_table(
        {"Environment Variable", "Value"},
        stamp_quarto.get_env_vars(),
        "quarto-env-vars"
    )
    
    local div = pandoc.Div({
        pandoc.Header(3, "Quarto Environment Variables"),
        env_table
    })
    div.attr.classes:insert("quarto-env-info")
    return div
end

-- Creates document properties section with header and table
---@return pandoc.Div Division containing document section
function stamp_quarto.get_document_section()
    local doc_table = stamp_utils.create_table(
        {"Property", "Value"},
        stamp_quarto.get_doc_props(),
        "quarto-doc-props"
    )
    
    local div = pandoc.Div({
        pandoc.Header(3, "Quarto Document Properties"),
        doc_table
    })
    div.attr.classes:insert("quarto-doc-info")
    return div
end

-- Creates project properties section with header and table
---@return pandoc.Div Division containing project section
function stamp_quarto.get_project_section()
    local project_table = stamp_utils.create_table(
        {"Property", "Value"},
        stamp_quarto.get_project_props(),
        "quarto-project-props"
    )
    
    local div = pandoc.Div({
        pandoc.Header(3, "Quarto Project Properties"),
        project_table
    })
    div.attr.classes:insert("quarto-project-info")
    return div
end

-- Creates session information section with version details
---@return pandoc.Div Division containing session information
function stamp_quarto.get_session_section()
    local rows = pandoc.List()
    
    -- Add version information rows
    ---@type {[1]: string, [2]: string}[]
    local version_info = {
        {"Quarto Version", tostring(quarto.config.version())},
        {"Pandoc Version", tostring(PANDOC_VERSION)},
        {"R Version", stamp_system.get_version("R --version")},
        {"Python Version", stamp_system.get_version("python --version")}
    }
    
    for _, info in ipairs(version_info) do
        rows[#rows + 1] = pandoc.Row({
            pandoc.Cell({ pandoc.Div(info[1]) }),
            pandoc.Cell({ pandoc.Div(info[2]) })
        })
    end
    
    local div = pandoc.Div({
        pandoc.Header(3, "Session Information"),
        pandoc.Table(
            { long = {}, short = {} },
            {
                { pandoc.AlignLeft, .5 },
                { pandoc.AlignLeft, .5 }
            },
            pandoc.TableHead({
                pandoc.Row({
                    pandoc.Cell({ pandoc.Div("Software") }),
                    pandoc.Cell({ pandoc.Div("Version") })
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
            pandoc.Attr("", { "session-info-table" })
        )
    })
    
    div.attr.classes:insert("session-info")
    return div
end

---@type StampQuarto
return stamp_quarto