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

-- Basedpyright config using native vim.lsp.config:
vim.lsp.config('basedpyright', {
  cmd = { 'basedpyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', '.git' },
  settings = {
    basedpyright = {
      typeCheckingMode = 'recommended',
    },
  },
})
vim.lsp.enable('basedpyright')

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf

    -- gd: open definition in new Ghostty window
    vim.keymap.set('n', 'gd', function()
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      if #clients == 0 then
        print("No LSP client attached")
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
        local line = range.start.line
        local col = range.start.character
        vim.fn.jobstart({
          'ghostty', '-e', 'nvim',
          string.format('+call cursor(%d,%d)', line, col),
          filepath
        })
      end)
    end, { buffer = bufnr, desc = "Go to definition (new window)" })

    -- gD: go to definition in same window
    vim.keymap.set('n', 'gD', vim.lsp.buf.definition,
      { buffer = bufnr, desc = "Go to definition (same window)" })

    vim.keymap.set('n', 'K',  vim.lsp.buf.hover,      { buffer = bufnr })
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, { buffer = bufnr })
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { buffer = bufnr })
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
      vim.fn.jobstart({
        'ghostty', '-e', 'nvim',
        string.format('+call cursor(%d,%d)', line, col),
        filepath
      })
    end, { buffer = args.buf, desc = "Open reference in new window", nowait = true })
  end,
})

vim.keymap.set('n', 'gr', function()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then
    require("fidget").notify("No LSP client attached", vim.log.levels.WARN)
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
end, { buffer = bufnr, desc = "Find references (new window on select)" })

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
    severity = { min = vim.diagnostic.severity.ERROR },
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

-- don't use a dedicated line for the command line
vim.opt.cmdheight = 0
