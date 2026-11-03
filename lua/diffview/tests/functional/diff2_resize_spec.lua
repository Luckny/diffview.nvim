local helpers = require("diffview.tests.helpers")

local eq = helpers.eq
local api = vim.api

describe("two-way diff window sizing", function()
  local Diff2 = require("diffview.scene.layouts.diff_2").Diff2
  local config = require("diffview.config")

  local function fake_window(id, nulled)
    return {
      id = id,
      is_nulled = function() return nulled end,
    }
  end

  local function fake_layout(name, a, b)
    return setmetatable({
      class = Diff2,
      name = name,
      a = a,
      b = b,
      is_valid = function() return true end,
    }, { __index = Diff2 })
  end

  before_each(function()
    config.setup({
      view = { null_file_win_ratio = 0.25 },
    })
    vim.cmd("silent! only")
  end)

  it("gives a nulled side-by-side window one quarter of the space", function()
    local a_id = api.nvim_get_current_win()
    vim.cmd("vsplit")
    local b_id = api.nvim_get_current_win()
    local layout = fake_layout(
      "diff2_horizontal",
      fake_window(a_id, true),
      fake_window(b_id, false)
    )

    layout:resize_windows()

    local a_width = api.nvim_win_get_width(a_id)
    local b_width = api.nvim_win_get_width(b_id)
    eq(true, b_width >= a_width * 2)
  end)

  it("gives a nulled stacked window one quarter of the space", function()
    local a_id = api.nvim_get_current_win()
    vim.cmd("split")
    local b_id = api.nvim_get_current_win()
    local layout = fake_layout(
      "diff2_vertical",
      fake_window(a_id, false),
      fake_window(b_id, true)
    )

    layout:resize_windows()

    local a_height = api.nvim_win_get_height(a_id)
    local b_height = api.nvim_win_get_height(b_id)
    eq(true, a_height >= b_height * 2)
  end)

  it("restores equal sizing when neither side is nulled", function()
    local a_id = api.nvim_get_current_win()
    vim.cmd("vsplit")
    local b_id = api.nvim_get_current_win()
    api.nvim_win_set_width(a_id, 20)
    local layout = fake_layout(
      "diff2_horizontal",
      fake_window(a_id, false),
      fake_window(b_id, false)
    )

    layout:resize_windows()

    local difference = math.abs(api.nvim_win_get_width(a_id) - api.nvim_win_get_width(b_id))
    eq(true, difference <= 1)
  end)
end)
