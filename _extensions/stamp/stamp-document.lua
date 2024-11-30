
-- Import required modules for handling different aspects of document information
---@type StampSystem
local stamp_system = require("stamp-system")       -- System information
---@type StampExtensions
local stamp_extensions = require("stamp-extensions") -- Extension information
---@type StampQuarto
local stamp_quarto = require("stamp-quarto")       -- Quarto-specific information
---@type StampConfig
local stamp_config = require("stamp-config")       -- Configuration settings

---@class StampDocument
---@field create_info_div fun(meta: table): pandoc.Div
---@field get_meta_string fun(meta: table, key: string, default: string): string
---@field place_info_div fun(doc: pandoc.Doc): pandoc.Doc
local stamp_document = {}

-- Creates a div containing all enabled information sections
---@param meta table Document metadata containing configuration
---@return pandoc.Div div Pandoc Div element with document information
function stamp_document.create_info_div(meta)
    -- Get list of sections that should be included based on configuration
    ---@type string[]
    local enabled_sections = stamp_config.get_enabled_sections(meta)
    ---@type pandoc.Block[]
    local sections = {}
    
    -- Add main header for document information
    table.insert(sections, pandoc.Header(2, "Document Information"))
    
    -- Add each enabled section to the document
    -- System information (OS, Lua version)
    if stamp_config.is_section_enabled("system", enabled_sections) then
        table.insert(sections, stamp_system.get_system_info())
    end
    
    -- Quarto environment variables
    if stamp_config.is_section_enabled("environment", enabled_sections) then
        table.insert(sections, stamp_quarto.get_environment_section())
    end
    
    -- Quarto document properties
    if stamp_config.is_section_enabled("document", enabled_sections) then
        table.insert(sections, stamp_quarto.get_document_section())
    end
    
    -- Quarto project properties
    if stamp_config.is_section_enabled("project", enabled_sections) then
        table.insert(sections, stamp_quarto.get_project_section())
    end
    
    -- Session information (software versions)
    if stamp_config.is_section_enabled("session", enabled_sections) then
        table.insert(sections, stamp_quarto.get_session_section())
    end
    
    -- Quarto extensions information
    if stamp_config.is_section_enabled("extensions", enabled_sections) then
        table.insert(sections, stamp_extensions.get_extensions_section())
    end
    
    -- Create div containing all sections
    local div = pandoc.Div(sections)
    div.attr.identifier = "document-information"
    return div
end

-- Helper function to safely extract string values from metadata
---@param meta table Document metadata
---@param key string Key to look up in meta.stamp
---@param default string Default value if key not found
---@return string value String value from metadata or default
function stamp_document.get_meta_string(meta, key, default)
    if not meta.stamp or not meta.stamp[key] then
        return default
    end
    return pandoc.utils.stringify(meta.stamp[key])
end

-- Places the information div in the document based on configuration
---@param doc pandoc.Doc Pandoc document object
---@return pandoc.Doc doc Modified document with information div inserted
function stamp_document.place_info_div(doc)
    local meta = doc.meta
    -- Get placement configuration from metadata or use defaults
    local placement = stamp_document.get_meta_string(meta, "placement", "bottom")
    local placement_id = stamp_document.get_meta_string(meta, "placement-id", "document-information")
    
    -- Create the information div
    local info_div = stamp_document.create_info_div(meta)
    
    -- Handle custom placement - looks for div with specific ID
    if placement == "custom" then
        for i, block in ipairs(doc.blocks) do
            if block.t == "Div" and block.attr.identifier == placement_id then
                doc.blocks[i] = info_div
                return doc
            end
        end
        -- If custom placement div not found, append to end
        table.insert(doc.blocks, info_div)
        return doc
    end
    
    -- Handle top/bottom placement
    if placement == "top" then
        table.insert(doc.blocks, 1, info_div)
    else
        table.insert(doc.blocks, info_div)
    end
    
    return doc
end

---@type StampDocument
return stamp_document