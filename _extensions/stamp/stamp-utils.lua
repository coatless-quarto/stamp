---@class TinyYAML
---@field parse fun(content: string): table

---@type TinyYAML
local tinyyaml = require("tinyyaml")

---@class StampUtils
---@field create_table fun(headers: string[], rows: pandoc.Row[], class_name: string): pandoc.Table
---@field read_yaml_file fun(file_path: string): table|nil
local stamp_utils = {}

-- Creates a formatted two-column Pandoc table with headers and rows
---@param headers string[] Array with two header strings
---@param rows pandoc.Row[] Array of table rows
---@param class_name string CSS class name for the table
---@return pandoc.Table Formatted Pandoc table
function stamp_utils.create_table(headers, rows, class_name)
   return pandoc.Table(
       { long = {}, short = {} },
       {
           { pandoc.AlignLeft, .5 },
           { pandoc.AlignLeft, .5 }
       },
       pandoc.TableHead({
           pandoc.Row({
               pandoc.Cell({ pandoc.Div(headers[1]) }),
               pandoc.Cell({ pandoc.Div(headers[2]) })
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
       pandoc.Attr("", { class_name })
   )
end

-- Reads and parses a YAML file, logging the content
---@param file_path string Path to YAML file
---@return table|nil Parsed YAML content or nil if file cannot be read
function stamp_utils.read_yaml_file(file_path)
   local f = io.open(file_path, "r")
   if f then
       local content = f:read("*all")
       f:close()
       
       -- Log file reading activity
       quarto.log.output("Reading YAML file: " .. file_path)
       quarto.log.output(content)
       
       return tinyyaml.parse(content)
   end
   return nil
end

---@type StampUtils
return stamp_utils