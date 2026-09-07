-- Neovim 0.10+. Loaded via require('zopen') from the plugin runtime path.
local M = {}
local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(source, ":p:h:h:h")
local config = {
  script = root .. "/zotero-attachment",
  -- Set to { "python3" } to bypass the script's nix-shell shebang.
  runner = {},
  args = {}, -- e.g. { "--data-dir", "/path/to/zotero" }
}

local function fail(message)
  vim.notify("zopen: " .. message, vim.log.levels.ERROR)
end

function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

-- Keys may contain Unicode, dots, colons, slashes, underscores and hyphens.
-- Whitespace and Markdown citation delimiters terminate a key.
local function normalize(value)
  value = vim.trim(value)
  if value:sub(1, 1) == "@" then value = value:sub(2) end
  if value == "" or value:find("[%s@%[%]{}(),;\"'<>]") then
    error("Invalid citation key: " .. value, 0)
  end
  return "@" .. value
end

local function cursor_key()
  local line = vim.api.nvim_get_current_line()
  local column = vim.api.nvim_win_get_cursor(0)[2] + 1 -- byte offset
  local start = 1
  while true do
    local first, last = line:find("@[^%s@%[%]{}(),;\"'<>]+", start)
    if not first then break end
    -- A sentence-ending period is not considered part of a citation.
    while line:sub(last, last) == "." and last > first do last = last - 1 end
    if column >= first and column <= last then
      return normalize(line:sub(first, last))
    end
    start = math.max(last + 1, first + 1)
  end
  error("No @citation key under the cursor", 0)
end

local function filename_key()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then error("Current buffer has no filename", 0) end
  return normalize(vim.fn.fnamemodify(name, ":t:r"))
end

-- Deliberately a small frontmatter reader, not a full YAML parser.
-- Supports top-level scalar keys, quotes and trailing comments. In particular,
-- accepts source: @fan2009, although YAML strictly requires quoting '@...'.
local function frontmatter_key(field)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if not lines[1] or not lines[1]:gsub("^\239\187\191", ""):match("^%-%-%-%s*$") then
    error("Current buffer has no YAML frontmatter", 0)
  end
  local value, closed
  for i = 2, #lines do
    if lines[i]:match("^%-%-%-%s*$") or lines[i]:match("^%.%.%.%s*$") then
      closed = true
      break
    end
    local key, raw = lines[i]:match("^([%w_%-]+):%s*(.*)$")
    if key == field then
      if value ~= nil then error("Duplicate frontmatter field: " .. field, 0) end
      value = raw
    end
  end
  if not closed then error("Unterminated YAML frontmatter", 0) end
  if value == nil then error("Missing frontmatter field: " .. field, 0) end
  value = vim.trim(value)
  if value:sub(1, 1) == '"' or value:sub(1, 1) == "'" then
    local quote = value:sub(1, 1)
    local ending = value:find(quote, 2, true)
    if not ending then error("Unterminated quoted frontmatter value", 0) end
    local tail = vim.trim(value:sub(ending + 1))
    if tail ~= "" and tail:sub(1, 1) ~= "#" then
      error("Expected a single citation key in " .. field, 0)
    end
    value = value:sub(2, ending - 1)
  else
    value = value:gsub("%s+#.*$", "")
  end
  if value:match("^[>|*&!]") then error("Expected a scalar citation key in " .. field, 0) end
  return normalize(value)
end

local function run(argv, callback)
  local ok, err = pcall(vim.system, argv, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        fail(vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr)
          or (argv[1] .. " exited with status " .. result.code))
      elseif callback then
        callback(result.stdout or "")
      end
    end)
  end)
  if not ok then fail(tostring(err)) end
end

local function dispatch(key, action)
  if action == "select" then
    -- Percent-encode the citation key, preserving the @ identifier prefix.
    local encoded = key:sub(2):gsub("([^%w%-._~])", function(c)
      return string.format("%%%02X", string.byte(c))
    end)
    run({ "xdg-open", "zotero://select/library/items/@" .. encoded })
  elseif action == "pdf" then
    local argv = vim.deepcopy(config.runner)
    argv[#argv + 1] = vim.fn.expand(config.script)
    vim.list_extend(argv, config.args)
    argv[#argv + 1] = "--"
    argv[#argv + 1] = key
    run(argv, function(stdout)
      local path = stdout:gsub("[\r\n]+$", "")
      if path == "" or path:find("[\r\n]") then
        fail("Lookup did not return exactly one attachment path (do not configure --all)")
        return
      end
      run({ "xdg-open", path })
    end)
  else
    error("Unknown action: " .. tostring(action) .. " (use 'pdf' or 'select')", 0)
  end
end

local function invoke(resolve, action)
  local ok, err = pcall(function() dispatch(resolve(), action or "pdf") end)
  if not ok then fail(tostring(err)) end
end

-- All functions default to opening the attachment. Pass "select" for Zotero.
function M.cursor(action) invoke(cursor_key, action) end
function M.file(action) invoke(filename_key, action) end
function M.frontmatter(field, action)
  invoke(function() return frontmatter_key(field) end, action)
end
function M.open(key, action)
  invoke(function() return normalize(key) end, action)
end

return M
