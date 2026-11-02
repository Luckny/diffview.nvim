local helpers = require("diffview.tests.helpers")

local eq = helpers.eq

describe("diffview.viewed_state", function()
  local state
  local path
  local adapter
  local left
  local right

  before_each(function()
    package.loaded["diffview.viewed_state"] = nil
    state = require("diffview.viewed_state")
    path = vim.fn.tempname() .. "/viewed_files.json"
    state._set_path(path)
    adapter = {
      class = { name = function() return "GitAdapter" end },
      ctx = { toplevel = "/repo" },
    }
    left = { commit = "aaaaaaaa", __tostring = function() return "aaaaaaaa" end }
    right = { stage = 0, __tostring = function() return ":0:" end }
  end)

  after_each(function()
    vim.fn.delete(vim.fn.fnamemodify(path, ":h"), "rf")
    state._reset()
  end)

  it("persists viewed entries across reloads", function()
    local comparison = state.activate(adapter, left, right, 30)
    state.set_many(comparison, {
      { kind = "working", path = "lua/example.lua" },
    }, true)

    state._set_path(path)
    comparison = state.activate(adapter, left, right, 30)

    eq(true, state.is_viewed(comparison, "working", "lua/example.lua"))
  end)

  it("separates change kinds and resolved revisions", function()
    local comparison = state.activate(adapter, left, right, 30)
    state.set_many(comparison, {
      { kind = "working", path = "README.md" },
    }, true)

    eq(false, state.is_viewed(comparison, "staged", "README.md"))

    local other = state.activate(adapter, { commit = "bbbbbbbb" }, right, 30)
    eq(false, state.is_viewed(other, "working", "README.md"))
  end)

  it("clears all entries in one comparison", function()
    local comparison = state.activate(adapter, left, right, 30)
    state.set_many(comparison, {
      { kind = "working", path = "a.lua" },
      { kind = "working", path = "b.lua" },
    }, true)

    state.clear(comparison)

    eq(false, state.is_viewed(comparison, "working", "a.lua"))
    eq(false, state.is_viewed(comparison, "working", "b.lua"))
  end)

  it("prunes expired comparisons", function()
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile({ vim.json.encode({
      version = 1,
      comparisons = {
        expired = {
          identity = {},
          entries = { old = true },
          updated_at = os.time() - 31 * 24 * 60 * 60,
        },
      },
    }) }, path)

    state._set_path(path)
    state.activate(adapter, left, right, 30)

    local decoded = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
    eq(nil, decoded.comparisons.expired)
  end)
end)
