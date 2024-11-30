---@type StampDocument
local stamp_document = require("stamp-document")

-- Return Pandoc filter that adds document information
return {
   {
       Pandoc = stamp_document.place_info_div
   }
}