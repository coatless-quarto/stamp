---@class StampConfig
---@field SECTIONS table<string, string>
---@field LEVELS {minimal: string[], full: string[], default: string}
---@field combine_sections fun(sections1: string[], sections2: string[]): string[]
---@field get_enabled_sections fun(meta: table): string[]
---@field is_section_enabled fun(section: string, enabled_sections: string[]): boolean
local stamp_config = {}

-- Define section names and their groupings
-- Maps section identifiers to their display names
---@type table<string, string>
stamp_config.SECTIONS = {
    system = "System Information",
    environment = "Quarto Environment Variables",
    document = "Quarto Document Properties",
    project = "Quarto Project Properties",
    session = "Session Information",
    extensions = "Extensions"
}

-- Define output levels with their included sections
-- minimal: basic system info and extensions
-- full: all available sections
---@type {minimal: string[], full: string[], default: string}
stamp_config.LEVELS = {
    minimal = {"system", "session", "extensions"},
    full = {"system", "environment", "document", "project", "session", "extensions"},
    default = "minimal" -- default falls back to minimal
}

-- Helper function to combine and deduplicate sections
---@param sections1 string[] First array of section names
---@param sections2 string[] Second array of section names
---@return string[] Combined and deduplicated array of section names
function stamp_config.combine_sections(sections1, sections2)
    ---@type table<string, boolean>
    local seen = {}
    ---@type string[]
    local result = {}
    
    -- Helper to add sections while avoiding duplicates
    ---@param sections string[]|any
    local function add_sections(sections)
        if type(sections) ~= "table" then return end
        for _, section in ipairs(sections) do
            if not seen[section] then
                seen[section] = true
                table.insert(result, section)
            end
        end
    end
    
    add_sections(sections1)
    add_sections(sections2)
    return result
end

-- Determines which sections should be enabled based on metadata configuration
---@param meta table Document metadata containing stamp configuration
---@return string[] Array of enabled section names
function stamp_config.get_enabled_sections(meta)
    -- If no stamp config present, use default level
    if not meta.stamp then
        return stamp_config.LEVELS[stamp_config.LEVELS.default]
    end
    
    ---@type string[]
    local base_sections = {}
    
    -- First check for level configuration
    if meta.stamp.level then
        local level = pandoc.utils.stringify(meta.stamp.level):lower()
        if stamp_config.LEVELS[level] then
            base_sections = stamp_config.LEVELS[level]
        else
            base_sections = stamp_config.LEVELS[stamp_config.LEVELS.default]
        end
    else
        -- If no level specified, use default
        base_sections = stamp_config.LEVELS[stamp_config.LEVELS.default]
    end
    
    -- Then check for additional sections
    if meta.stamp.sections then
        ---@type string[]
        local additional_sections = {}
        local config_sections = meta.stamp.sections
        
        -- Handle both array and single value cases
        if type(config_sections) == "table" then
            if config_sections[1] then
                -- Array case
                for _, section in ipairs(config_sections) do
                    local section_name = pandoc.utils.stringify(section):lower()
                    if stamp_config.SECTIONS[section_name] then
                        table.insert(additional_sections, section_name)
                    end
                end
            else
                -- Single value case
                local section_name = pandoc.utils.stringify(config_sections):lower()
                if stamp_config.SECTIONS[section_name] then
                    table.insert(additional_sections, section_name)
                end
            end
        end
        
        -- Determine how to handle sections based on meta.stamp.mode
        local mode = meta.stamp.mode and pandoc.utils.stringify(meta.stamp.mode):lower() or "add"
        
        if mode == "replace" then
            -- Use only explicitly specified sections
            if #additional_sections > 0 then
                return additional_sections
            end
            -- If no valid sections specified, fall back to base sections
            return base_sections
        else
            -- "add" mode (default): combine base sections with additional sections
            return stamp_config.combine_sections(base_sections, additional_sections)
        end
    end
    
    -- Return base sections if no additional sections specified
    return base_sections
end

-- Check if a specific section is enabled in the current configuration
---@param section string Section name to check
---@param enabled_sections string[] Array of currently enabled sections
---@return boolean true if section is enabled, false otherwise
function stamp_config.is_section_enabled(section, enabled_sections)
    for _, enabled in ipairs(enabled_sections) do
        if enabled == section then
            return true
        end
    end
    return false
end

---@type StampConfig
return stamp_config