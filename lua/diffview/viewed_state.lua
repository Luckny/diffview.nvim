local utils = require("diffview.utils")

local M = {}

local VERSION = 1
local DAY_SECONDS = 24 * 60 * 60
local data
local loaded_path
local override_path

local function state_path()
  if override_path then return override_path end

  local base
  if vim.fn.has("nvim-0.8") == 1 then
    base = vim.fn.stdpath("state")
  else
    -- stdpath("state") was added in Neovim 0.8.
    base = vim.fn.stdpath("data")
  end
  return base .. "/diffview/viewed_files.json"
end

local function fresh_data()
  return {
    version = VERSION,
    comparisons = {},
  }
end

local function encode_key(parts)
  return vim.fn.sha256(vim.json.encode(parts))
end

local function revision_identity(rev)
  if rev.commit then
    return { "commit", rev.commit }
  elseif rev.stage ~= nil then
    return { "stage", rev.stage }
  end
  return { tostring(rev) }
end

local function comparison_identity(adapter, left, right)
  return {
    adapter.class:name(),
    adapter.ctx.toplevel,
    revision_identity(left),
    revision_identity(right),
  }
end

local function persist()
  local path = loaded_path or state_path()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")

  local temp = path .. ".tmp"
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    utils.warn("Failed to encode viewed-file state.")
    return
  end

  if vim.fn.writefile({ encoded }, temp) ~= 0 then
    utils.warn("Failed to write viewed-file state.")
    return
  end

  local renamed = vim.loop.fs_rename(temp, path)
  if not renamed then
    vim.loop.fs_unlink(path)
    renamed = vim.loop.fs_rename(temp, path)
  end
  if not renamed then
    vim.loop.fs_unlink(temp)
    utils.warn("Failed to replace viewed-file state.")
  end
end

local function prune(retention_days)
  local cutoff = os.time() - retention_days * DAY_SECONDS
  local changed = false

  for key, record in pairs(data.comparisons) do
    if type(record) ~= "table" or type(record.updated_at) ~= "number"
        or record.updated_at < cutoff then
      data.comparisons[key] = nil
      changed = true
    end
  end

  if changed then persist() end
end

local function load(retention_days)
  local path = state_path()
  if data and loaded_path == path then
    prune(retention_days)
    return
  end

  loaded_path = path
  data = fresh_data()

  if vim.fn.filereadable(path) == 1 then
    local content = table.concat(vim.fn.readfile(path), "\n")
    local ok, decoded = pcall(vim.json.decode, content)
    if ok and type(decoded) == "table" and decoded.version == VERSION
        and type(decoded.comparisons) == "table" then
      data = decoded
    else
      utils.warn("Ignoring invalid viewed-file state: " .. path)
    end
  end

  prune(retention_days)
end

---@param adapter VCSAdapter
---@param left Rev
---@param right Rev
---@param retention_days integer
---@return string
function M.activate(adapter, left, right, retention_days)
  load(retention_days)

  local identity = comparison_identity(adapter, left, right)
  local key = encode_key(identity)
  local record = data.comparisons[key]

  if not record then
    record = {
      identity = identity,
      entries = {},
      updated_at = os.time(),
    }
    data.comparisons[key] = record
  else
    record.updated_at = os.time()
  end

  persist()
  return key
end

---@param kind vcs.FileKind
---@param path string
---@return string
function M.entry_key(kind, path)
  return encode_key({ kind, path })
end

---@param comparison_key string
---@param kind vcs.FileKind
---@param path string
---@return boolean
function M.is_viewed(comparison_key, kind, path)
  local record = data and data.comparisons[comparison_key]
  return not not (record and record.entries[M.entry_key(kind, path)])
end

---@param comparison_key string
---@param entries FileEntry[]
---@param viewed boolean
function M.set_many(comparison_key, entries, viewed)
  local record = data and data.comparisons[comparison_key]
  if not record then return end

  for _, entry in ipairs(entries) do
    local key = M.entry_key(entry.kind, entry.path)
    record.entries[key] = viewed or nil
  end
  record.updated_at = os.time()
  persist()
end

---@param comparison_key string
function M.clear(comparison_key)
  local record = data and data.comparisons[comparison_key]
  if not record then return end

  record.entries = {}
  record.updated_at = os.time()
  persist()
end

-- Test-only seams keep filesystem tests isolated from real user state.
function M._set_path(path)
  override_path = path
  data = nil
  loaded_path = nil
end

function M._reset()
  data = nil
  loaded_path = nil
  override_path = nil
end

return M
