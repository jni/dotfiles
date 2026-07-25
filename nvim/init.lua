-- leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- bootstrap lazy.nvim (plugin manager)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- plugins
require("lazy").setup({
  { "tpope/vim-sleuth" },
  {
    "lukas-reineke/virt-column.nvim",
    opts = {
      char = "│",
      virtcolumn = "80",
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  {
    "j-hui/fidget.nvim",
    opts = {},
  },
  {
    "toppair/peek.nvim",
    event = { "VeryLazy" },
    build = "deno task --quiet build:fast",
    config = function()
      require("peek").setup({
        app = "webview",
        update_on_change = true,
      })
      vim.api.nvim_create_user_command("Peek", require("peek").open, {})
      vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
    end,
  },
})

-- Ruff config using native vim.lsp.config. Ruff's built-in language server
-- (`ruff server`) surfaces lint diagnostics -- undefined names (F821, i.e.
-- NameErrors), redefinitions (F811), unused variables (F841), etc. -- and
-- automatically uses the nearest pyproject.toml/ruff.toml config if the
-- project has one, falling back to Ruff's defaults otherwise. Preferred over
-- basedpyright since I care about much more about lint errors than type
-- checking.
vim.lsp.config('ruff', {
  cmd = { 'ruff', 'server' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'ruff.toml', '.ruff.toml', 'setup.py', 'setup.cfg', '.git' },
})
vim.lsp.enable('ruff')

-- Basedpyright alongside Ruff, purely for code navigation. `ruff server` is a
-- linter/formatter server: it implements diagnostics, code actions and
-- formatting, but *not* textDocument/definition, references, hover or rename,
-- so gd/gr/K/<leader>rn have no server to talk to with Ruff alone. Type
-- checking is off, so Ruff stays the source of lint diagnostics and
-- basedpyright only contributes unresolved-import/syntax errors on top.
vim.lsp.config('basedpyright', {
  cmd = { 'basedpyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', '.git' },
  settings = {
    basedpyright = {
      -- let Ruff own import sorting
      disableOrganizeImports = true,
      analysis = {
        typeCheckingMode = 'off',
      },
    },
  },
})
vim.lsp.enable('basedpyright')

-- Ghostty's `-e` strips any argument starting with `+` (it treats them as
-- its own `+action` CLI syntax), silently dropping nvim's `+cmd` args. Route
-- through `sh -c` so the `+cmd` is buried inside one shell-quoted string
-- instead of being its own top-level argv token.
local function shellquote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function open_in_new_window(filepath, line, col)
  local cmd = string.format('nvim %s %s',
    shellquote(string.format('+call cursor(%d,%d)', line, col)),
    shellquote(filepath))
  vim.fn.jobstart({ 'ghostty', '-e', 'sh', '-c', cmd })
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf

    -- gd: open definition in new Ghostty window
    vim.keymap.set('n', 'gd', function()
      -- filter by method: Ruff attaches to Python buffers too but can't answer
      -- this, and its offset_encoding may differ from the server that can
      local clients = vim.lsp.get_clients({
        bufnr = bufnr, method = 'textDocument/definition',
      })
      if #clients == 0 then
        print("No LSP client supports go-to-definition here")
        return
      end
      local encoding = clients[1].offset_encoding or 'utf-16'

      local params = vim.lsp.util.make_position_params(0, encoding)
      vim.lsp.buf_request(bufnr, 'textDocument/definition', params, function(_, result)
        if not result or vim.tbl_isempty(result) then
          print("No definition found")
          return
        end
        local location = result[1]
        local uri = location.uri or location.targetUri
        local range = location.range or location.targetSelectionRange
        local filepath = vim.uri_to_fname(uri)
        local line = range.start.line + 1
        local col = range.start.character + 1
        open_in_new_window(filepath, line, col)
      end)
    end, { buffer = bufnr, desc = "Go to definition (new window)" })

    -- gD: go to definition in same window
    vim.keymap.set('n', 'gD', vim.lsp.buf.definition,
      { buffer = bufnr, desc = "Go to definition (same window)" })

    vim.keymap.set('n', 'K',  vim.lsp.buf.hover,      { buffer = bufnr })
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { buffer = bufnr })
    -- NB: no buffer-local 'gr' here -- it would shadow the quickfix-based
    -- find-references mapping defined below, which is the one we want.
  end,
})

-- open references in a new window
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function(args)
    vim.keymap.set('n', '<CR>', function()
      local qf_idx = vim.fn.line('.')
      local qf_item = vim.fn.getqflist()[qf_idx]
      if not qf_item then return end

      local filepath = vim.fn.bufname(qf_item.bufnr)
      local line = qf_item.lnum
      local col = qf_item.col

      vim.cmd('cclose')
      open_in_new_window(filepath, line, col)
    end, { buffer = args.buf, desc = "Open reference in new window", nowait = true })
  end,
})

vim.keymap.set('n', 'gr', function()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({
    bufnr = bufnr, method = 'textDocument/references',
  })
  if #clients == 0 then
    require("fidget").notify("No LSP client supports find-references here",
      vim.log.levels.WARN)
    return
  end
  local encoding = clients[1].offset_encoding or 'utf-16'
  local params = vim.lsp.util.make_position_params(0, encoding)
  params.context = { includeDeclaration = true }

  require("fidget").notify("Searching for references...")

  vim.lsp.buf_request(bufnr, 'textDocument/references', params, function(_, result)
    if not result or vim.tbl_isempty(result) then
      require("fidget").notify("No references found", vim.log.levels.WARN)
      return
    end
    local items = vim.lsp.util.locations_to_items(result, encoding)
    vim.fn.setqflist({}, ' ', { title = 'References', items = items })
    vim.cmd('copen')
  end)
end, { desc = "Find references (new window on select)" })

-- ================== CONFIG ================= --

-- automatically spell check markdown and Qmd files
vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
  pattern = { '*.md', '*.markdown', '*.qmd' },
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = { 'en_gb', 'es' }  -- adjust to taste
  end,
})

-- wrap long lines and show wrapping with underscores
vim.opt.linebreak = true
vim.opt.showbreak = '______'

-- indentation options: not needed with tpope/vim-sleuth
-- vim.opt.tabstop = 4
-- vim.opt.shiftwidth = 4
-- vim.opt.expandtab = true
vim.opt.autoindent = true

-- remap tab/shift-tab in insert to indent/dedent
vim.keymap.set('i', '<Tab>', '<C-T>')
vim.keymap.set('i', '<S-Tab>', '<C-D>')

-- formatoptions: start from default and remove 't'
-- (don't auto-wrap text while typing)
vim.opt.formatoptions:remove('t')
vim.opt.textwidth = 79


-- ignore case while searching, unless variable case in search string
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true

-- h/l/~/cursor keys wrap across line boundaries
vim.opt.whichwrap = 'h,l,~,[,]'

-- % matches <> as well as () [] {}
vim.opt.matchpairs:append('<:>')

-- g- as alias for g; (jump to older change position)
vim.keymap.set('n', 'g-', 'g;')

-- gl as alias for opening diagnostic float
vim.keymap.set(
  'n', 'gl', vim.diagnostic.open_float,
  { desc = "Show diagnostic message" }
)
-- diagnostics config
vim.diagnostic.config({
  severity_sort = true,       -- errors before warnings in lists
  signs = false,              -- don't use gutters
  underline = {
    severity = { min = vim.diagnostic.severity.WARN },
  },
  virtual_text = {
    severity = { min = vim.diagnostic.severity.WARN },
  },
})

-- Use the terminal's background color instead of neovim's
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" }) -- or "#000000"
  end,
})

-- Force distinct underline colors regardless of colorscheme
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "DiagnosticUnderlineError", { undercurl = true, sp = "#d16969" })
    vim.api.nvim_set_hl(0, "DiagnosticUnderlineWarn",  { undercurl = true, sp = "#d7ba7d" })
    vim.api.nvim_set_hl(0, "DiagnosticUnderlineInfo",  { undercurl = true, sp = "#888888" })
    vim.api.nvim_set_hl(0, "DiagnosticUnderlineHint",  { undercurl = true, sp = "#888888" })
  end,
})

-- jump to last position on reopen
vim.api.nvim_create_autocmd('BufReadPost', {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 1 and mark[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- highlight trailing whitespace
vim.cmd([[
  highlight ExtraWhitespace ctermbg=darkgreen guibg=lightgreen
  match ExtraWhitespace /\s\+$/
]])

vim.api.nvim_create_autocmd('BufWinEnter', {
  callback = function() vim.cmd('match ExtraWhitespace /\\s\\+$/') end,
})
vim.api.nvim_create_autocmd('InsertEnter', {
  callback = function() vim.cmd('match ExtraWhitespace /\\s\\+\\%#\\@<!$/') end,
})
vim.api.nvim_create_autocmd('InsertLeave', {
  callback = function() vim.cmd('match ExtraWhitespace /\\s\\+$/') end,
})
vim.api.nvim_create_autocmd('BufWinLeave', {
  callback = function() vim.fn.clearmatches() end,
})

-- don't override terminal background colour
vim.opt.background = 'dark'
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
  end,
})

-- use the system clipboard when yanking
vim.keymap.set({"n", "x"}, "y", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set({"n", "x"}, "Y", '"+y$', { desc = "Yank to end of line (system clipboard)" })

-- gh: open the current line on GitHub, on the main branch of the `upstream`
-- remote (the canonical repo when working on a fork), or `origin` if there is
-- no upstream. Linking to the branch -- rather than a specific commit -- keeps
-- the current file path valid even across renames. If the local branch has
-- diverged from that branch, the line number is remapped by walking the diff
-- hunks between them so it still points at the right line.
local function gh_open_line()
  local notify = require("fidget").notify
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    notify("No file in buffer", vim.log.levels.WARN)
    return
  end
  local dir = vim.fn.fnamemodify(file, ":h")
  local line = vim.fn.line(".")

  local function git(args)
    local out = vim.fn.systemlist(vim.list_extend({ "git", "-C", dir }, args))
    return vim.v.shell_error == 0, out
  end

  -- repo-relative path (also verifies the file is tracked)
  local ok, relout = git({ "ls-files", "--full-name", "--error-unmatch", "--", file })
  if not ok or not relout[1] then
    notify("File is not tracked by git", vim.log.levels.WARN)
    return
  end
  local relpath = relout[1]

  -- choose remote: prefer upstream, else origin, else the only one
  local _, remotes = git({ "remote" })
  local has = {}
  for _, r in ipairs(remotes) do has[r] = true end
  local remote = has["upstream"] and "upstream" or (has["origin"] and "origin" or remotes[1])
  if not remote then
    notify("No git remote configured", vim.log.levels.WARN)
    return
  end

  -- that remote's default branch (falling back to main/master)
  local branch
  local okh, headref = git({ "symbolic-ref", "--short", "refs/remotes/" .. remote .. "/HEAD" })
  if okh and headref[1] then
    branch = headref[1]:match("[^/]+$")
  end
  if not branch then
    for _, cand in ipairs({ "main", "master" }) do
      if git({ "rev-parse", "--verify", "--quiet", remote .. "/" .. cand }) then
        branch = cand
        break
      end
    end
  end
  if not branch then
    notify("No main/master branch on '" .. remote .. "'", vim.log.levels.WARN)
    return
  end
  local branch_ref = remote .. "/" .. branch

  -- Remap the line to its position on the branch, accounting for local
  -- divergence: an unchanged line shifts by the net (added - removed) lines
  -- above it. `git diff branch_ref -- file` puts the branch on the `-` side
  -- and the working tree on the `+` side. For a hunk `@@ -a,b +c,d @@`, the
  -- offset for lines below it is (next branch line) - (next working line);
  -- when a side's count is 0 its number is a boundary, so the next line is
  -- start+1 rather than start+count (hence max(count, 1)).
  local target_line = line
  if git({ "cat-file", "-e", branch_ref .. ":" .. relpath }) then
    local _, diff = git({ "diff", "-U0", "--no-color", branch_ref, "--", file })
    local off = 0
    for _, l in ipairs(diff) do
      local a, b, c, d = l:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
      if a then
        a, c = tonumber(a), tonumber(c)
        b = b == "" and 1 or tonumber(b)
        d = d == "" and 1 or tonumber(d)
        if d > 0 and line >= c and line < c + d then
          target_line, off = a, nil -- line falls inside a changed hunk
          break
        elseif line < c or (d == 0 and line == c) then
          break -- hunk starts past our line; the accumulated offset holds
        else
          off = (a + math.max(b, 1)) - (c + math.max(d, 1))
        end
      end
    end
    if off then target_line = line + off end
  else
    notify(relpath .. " is not on " .. branch_ref .. "; link may 404", vim.log.levels.WARN)
  end

  local ok2, urlout = git({ "remote", "get-url", remote })
  if not ok2 or not urlout[1] then
    notify("Could not get URL for remote '" .. remote .. "'", vim.log.levels.ERROR)
    return
  end
  -- normalise the git remote URL to a GitHub web base
  local web = urlout[1]
    :gsub("^git@([^:]+):", "https://%1/") -- scp form: git@github.com:o/r
    :gsub("^ssh://git@", "https://")
    :gsub("%.git$", "")

  local permalink = string.format("%s/blob/%s/%s#L%d", web, branch, relpath, target_line)
  notify("Opening " .. permalink)
  vim.ui.open(permalink)
end

vim.keymap.set("n", "gh", gh_open_line, { desc = "Open current line on GitHub" })

-- don't use a dedicated line for the command line
vim.opt.cmdheight = 0
