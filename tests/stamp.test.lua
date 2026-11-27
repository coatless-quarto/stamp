-- stamp tests. Run from the repo root: quarto pandoc lua path/to/qtest.lua
-- The fixtures run no code. stamp asks R and Python for their versions, and
-- shows "not installed" when they are missing, as they are on CI.
local t = require("qtest")

--- The text of one stamp section, with the tags and extra spaces removed.
---@param html string
---@param name string Section name, e.g. "extensions"
---@return string
local function section(html, name)
  local s = html:match('<section id="stamp%-' .. name .. '".-</section>')
  t.ok(s, "the stamp has a " .. name .. " section")
  return (s:gsub("<[^>]+>", " "):gsub("%s+", " "))
end

--- Ids of the stamp sections in the page, in order.
---@param html string
---@return string
local function sections(html)
  local ids = {}
  for id in html:gmatch('<section id="stamp%-([a-z]+)"') do ids[#ids + 1] = id end
  return table.concat(ids, ",")
end

-- The version in stamp's own _extension.yml, which the extensions table shows
local f = assert(io.open("_extensions/stamp/_extension.yml"))
local VERSION = f:read("a"):match("\nversion:%s*([^\n]+)")
f:close()

t.test("html: the minimal stamp goes at the bottom, one linked section each", function()
  local r = t.render("default.qmd", "html")
  r:succeeded()
  t.count(r.text, '<section id="document-information"', 1)
  t.in_order(r.text, { "Body text before the stamp.", ">Document Information</h2>" })
  t.eq(sections(r.text), "system,session,extensions", "minimal sections")
  t.contains(section(r.text, "extensions"), "stamp " .. VERSION .. " local")
end)

-- Regressions: every render printed each _extension.yml it read, and
-- "command not found" when R or Python was missing.
t.test("html: stamp renders without printing anything of its own", function()
  local r = t.render("default.qmd", "html")
  r:succeeded()
  r:no_warnings()
  t.not_contains(r.log, "_extension.yml")
  t.not_contains(r.log, "not found")
end)

t.test("typst: the stamp and its section labels are in the output", function()
  local r = t.render("default.qmd", "typst")
  r:succeeded()
  t.in_order(r.text, { "Body text before the stamp.", "= Document Information",
    "== System Information", "<stamp-system>", "<stamp-extensions>" })
end)

-- Regressions: stamp: true crashed the filter, and stamp: false still added
-- the stamp.
t.test("stamp: true adds the default stamp, stamp: false leaves it out", function()
  local on = t.render("on.qmd", "html")
  on:succeeded()
  t.eq(sections(on.text), "system,session,extensions", "stamp: true sections")
  local off = t.render("off.qmd", "html")
  off:succeeded()
  t.not_contains(off.text, "Document Information")
end)

-- Regressions: level: default showed nothing, and level: full left the
-- document's format and the project folder empty.
t.test("level: full shows every section, filled in; level: default is minimal", function()
  local full = t.render("full.qmd", "html")
  full:succeeded()
  t.eq(sections(full.text), "system,environment,document,project,session,extensions", "full sections")
  t.contains(section(full.text, "document"), "format html")
  t.contains(section(full.text, "project"), "quarto.project.directory /")
  local default = t.render("level-default.qmd", "html")
  default:succeeded()
  t.eq(sections(default.text), "system,session,extensions", "level: default sections")
end)

t.test("sections add to the level; mode: replace shows only those listed", function()
  local add = t.render("add.qmd", "html")
  add:succeeded()
  t.eq(sections(add.text), "system,environment,session,extensions", "mode: add sections")
  local replace = t.render("replace.qmd", "html")
  replace:succeeded()
  t.eq(sections(replace.text), "document", "mode: replace sections")
end)

-- Regression: only lower-case placement values were read.
t.test("placement: top, in any letter case, puts the stamp first", function()
  local r = t.render("top.qmd", "html")
  r:succeeded()
  t.in_order(r.text, { ">Document Information</h2>", "Body text before the stamp." })
end)

-- Regression: custom placement only found its div at the top level.
t.test("placement: custom replaces the placement-id div, at any depth", function()
  local r = t.render("custom.qmd", "html")
  r:succeeded()
  t.in_order(r.text, { "Text before the placeholder.", "Inside a div.",
    ">Document Information</h2>", "Text after the placeholder." })
  t.not_contains(r.text, 'id="here"')
end)

-- Regression: the extensions table was empty for a page in a project
-- subfolder, because stamp only looked next to the page.
t.test("a page in a project subfolder lists the project's extensions", function()
  local r = t.render("project", "html", { output = "project/sub/page.html" })
  r:succeeded()
  local exts = section(r.text, "extensions")
  t.contains(exts, "stamp " .. VERSION .. " local")
  t.contains(exts, "widget 1.2.3 acme/widget")
end)
