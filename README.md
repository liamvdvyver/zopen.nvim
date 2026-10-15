# zopen.nvim

_Lovingly vibecoded in 15 minutes, I make no guarantees of quality._

Open Zotero attachments or select items from Neovim using citation keys under
the cursor, filenames, or YAML frontmatter.

## Requirements

- Neovim 0.10+ on Linux
- Zotero with locally available attachments
- Python 3
- `xdg-open`

Citation keys must be stored in Zotero's `citationKey` field (current Better
BibTeX) or as `Citation Key: ...` in Extra.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim).

```lua
{ 'liamvdvyver/zopen.nvim', opts = {} }
```

No mappings are installed automatically. The bundled lookup script is found
automatically; no `main` or `config` entry is needed.

## Usage

```lua
local z = require('zopen')

z.cursor()                       -- @vaswani2023 under the cursor
z.file()                         -- Current filename: @vaswani2023.md
z.frontmatter('source')           -- Frontmatter: source: '@vaswani2023'
z.open('@vaswani2023')                -- Explicit citation key
```

By default, these open a local attachment with `xdg-open`, preferring PDFs.
Pass `'select'` as the final argument to select the item in Zotero instead:

```lua
z.cursor('select')
z.file('select')
z.frontmatter('source', 'select')
z.open('@vaswani2023', 'select')
```

Example mappings:

```lua
vim.keymap.set('n', '<leader>zp', function() require('zopen').cursor() end)
vim.keymap.set('n', '<leader>zs', function() require('zopen').cursor('select') end)
vim.keymap.set('n', '<leader>zr', function() require('zopen').frontmatter('source') end)
```

Processes run asynchronously; errors appear as notifications. Frontmatter
supports simple top-level scalar values, quotes, and trailing comments—not
nested YAML or lists. Unsaved buffer edits are respected.

## Configuration

Defaults detect a single Linux Zotero profile and its data/attachment directories.
Override settings through lazy.nvim's `opts` or `require('zopen').setup({...})`:

```lua
opts = {
  runner = { 'python3' }, -- Use Python directly instead of nix-shell
  args = { '--data-dir', '/path/to/zotero' },
  -- script = '/path/to/zotero-attachment', -- Override the bundled script
}
```

Additional script options: `--prefs /path/to/prefs.js`,
`--base-dir /path/to/linked/attachments`, and `--library-id ID`.
Do not pass `--all` through the plugin.

## Standalone CLI

```sh
./zotero-attachment @vaswani2023        # Print one local attachment path
./zotero-attachment --all @vaswani2023  # Print all local attachment paths
```

Without Nix, run `python3 zotero-attachment @vaswani2023`. Zotero item/attachment
keys and `zotero://select/library/items/@vaswani2023` URIs are also accepted.

## Database safety

Original database files are **only read**. The script copies the database and
WAL journal to a temporary directory, checks for changes during copying, and
queries the copy with SQLite read-only mode and `query_only`. It never downloads
attachments or modifies your library. Close Zotero for a guaranteed stable
view: copying a live database is not atomic.

## Tests

```sh
nix-shell -p python3 --run 'python3 -m unittest -v'
nvim --headless -u NONE -l tests/neovim.lua
```
