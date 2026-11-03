local helpers = require("diffview.tests.helpers")

local eq = helpers.eq
local api = vim.api

describe("diff window navigation", function()
  local Window = require("diffview.scene.window").Window

  before_each(function()
    vim.cmd("silent! only")
  end)

  after_each(function()
    vim.cmd("silent! only")
  end)

  it("turns off diff mode when navigation replaces a managed buffer", function()
    local expected = api.nvim_create_buf(false, true)
    local foreign = api.nvim_create_buf(false, true)
    local managed_win = api.nvim_get_current_win()
    api.nvim_win_set_buf(managed_win, expected)

    vim.cmd("vsplit")
    local peer_win = api.nvim_get_current_win()
    vim.wo[managed_win].diff = true
    vim.wo[peer_win].diff = true
    api.nvim_set_current_win(managed_win)

    local win = Window({
      id = managed_win,
      file = { bufnr = expected },
    })
    api.nvim_win_set_buf(managed_win, foreign)

    eq(false, vim.wo[managed_win].diff)
    eq(false, vim.wo[peer_win].diff)
    win:set_id(nil)
  end)

  it("keeps diff mode for the expected buffer", function()
    local expected = api.nvim_create_buf(false, true)
    local managed_win = api.nvim_get_current_win()
    api.nvim_win_set_buf(managed_win, expected)
    vim.wo[managed_win].diff = true

    local win = Window({
      id = managed_win,
      file = { bufnr = expected },
    })
    win:on_buf_enter(expected)

    eq(true, vim.wo[managed_win].diff)
    win:set_id(nil)
  end)
end)
