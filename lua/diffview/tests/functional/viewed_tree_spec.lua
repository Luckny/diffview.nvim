local helpers = require("diffview.tests.helpers")

local eq = helpers.eq

describe("viewed file trees", function()
  local DiffView = require("diffview.scene.views.diff.diff_view").DiffView
  local FileDict = require("diffview.vcs.file_dict").FileDict

  local function make_view(files)
    local file_dict = FileDict()
    file_dict:set_working(files)
    file_dict:update_file_trees()
    return setmetatable({
      class = DiffView,
      files = file_dict,
    }, { __index = DiffView })
  end

  it("derives directory state from every descendant", function()
    local view = make_view({
      { path = "src/a.lua", kind = "working", viewed = true },
      { path = "src/b.lua", kind = "working", viewed = false },
    })
    local dir = view.files.working_tree.root.children.src.data

    eq(false, view:is_dir_viewed(dir))
    view.files.working[2].viewed = true
    eq(true, view:is_dir_viewed(dir))
  end)

  it("collapses fully viewed directories", function()
    local view = make_view({
      { path = "src/nested/a.lua", kind = "working", viewed = true },
      { path = "src/nested/b.lua", kind = "working", viewed = true },
    })

    view:collapse_viewed_dirs()

    eq(true, view.files.working_tree.root.children.src.data.collapsed)
    eq(true, view.files.working_tree.root.children.src.children.nested.data.collapsed)
  end)

  it("returns all descendants for a directory", function()
    local view = make_view({
      { path = "src/a.lua", kind = "working", viewed = false },
      { path = "src/nested/b.lua", kind = "working", viewed = false },
    })
    local dir = view.files.working_tree.root.children.src.data

    eq(2, #view:viewed_entries_for(dir))
  end)
end)
