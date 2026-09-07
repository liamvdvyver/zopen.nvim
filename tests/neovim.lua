-- Run from the repository root: nvim --headless -u NONE -l tests/neovim.lua
local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)
local z = require('zopen')
z.setup({}) -- lazy.nvim's minimal opts = {} installation
local calls = {}
vim.notify = function(message) error(message) end
vim.system = function(argv, _, callback)
  calls[#calls + 1] = argv
  callback({ code = 0, stdout = '/tmp/test paper.pdf\n', stderr = '' })
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  '---', 'source: @fan2009 # comment', '---', '[@fan2009; @other2020]',
})
z.frontmatter('source', 'select')
assert(calls[1][2] == 'zotero://select/library/items/@fan2009')
vim.api.nvim_win_set_cursor(0, { 4, 3 })
z.cursor('select')
assert(calls[2][2] == calls[1][2])
vim.api.nvim_buf_set_name(0, '/tmp/@fan2009.md')
z.file()
assert(vim.wait(1000, function() return #calls == 4 end))
assert(calls[3][1] == root .. '/zotero-attachment', 'Bundled script must resolve automatically')
assert(calls[3][#calls[3]] == '@fan2009')
assert(calls[4][1] == 'xdg-open')
assert(calls[4][2] == '/tmp/test paper.pdf')

z.setup({ runner = { 'python3' }, args = { '--data-dir', '/tmp/my library' } })
z.open('@fan2009')
assert(vim.wait(1000, function() return #calls == 6 end))
assert(vim.deep_equal(calls[5], {
  'python3', root .. '/zotero-attachment', '--data-dir', '/tmp/my library', '--', '@fan2009',
}))
print('zopen Neovim plugin tests passed')
