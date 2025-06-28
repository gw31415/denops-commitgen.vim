# denops-commitgen.vim

> [!NOTE]
> The Lua module is available for **Neovim only**. To use the full functionality of this plugin, you must use Neovim.

AI-powered commit message generator for Vim/Neovim using [Denops](https://github.com/vim-denops/denops.vim) and OpenAI models.

## Features
- Generate conventional commit messages for your staged Git changes using AI (OpenAI models, e.g., GPT-4o)
- Supports both Vim and Neovim
- Async and sync interfaces
- Customizable model and number of suggestions
- Lua interface for Neovim users

## Requirements
- [Vim](https://www.vim.org/) or [Neovim](https://neovim.io/)
- [denops.vim](https://github.com/vim-denops/denops.vim)
- [Deno](https://deno.land/) (v1.34.0 or later recommended)
- OpenAI API key (if using OpenAI models)

## Installation
Use your favorite plugin manager. Example with [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'vim-denops/denops.vim'
Plug 'gw31415/denops-commitgen.vim'
```

Or with [lazy.nvim](https://github.com/folke/lazy.nvim) for Neovim:

```lua
{
  'vim-denops/denops.vim',
  'gw31415/denops-commitgen.vim',
}
```

## Configuration
You can set the model and number of suggestions globally in your `vimrc` or `init.vim`:

```vim
let g:commitgen_model = 'gpt-4o'   " Default: 'gpt-4o'
let g:commitgen_count = 5          " Default: 5
```

## Usage

### Vim/Neovim (VimL)
- **Sync**: Get commit messages for the current file or path:
  ```vim
  echo commitgen#get('path/to/file')
  ```
- **Async**: Get commit messages asynchronously:
  ```vim
  call commitgen#get_async('path/to/file', {v -> echo v})
  ```

### Neovim (Lua)
> [!NOTE]
> The Lua module is available for **Neovim only**. Full functionality, including the Lua interface, requires Neovim 0.11 or later.

This plugin provides a Lua interface for Neovim 0.11+:

```lua
local commitgen = require('commitgen')
commitgen.paste({ after = true, renew = false })
commitgen.request({ renew = true })
```
- `paste`: Prompts you to select a commit message and inserts it into the buffer.
- `request`: Pre-fetches commit messages for the current staged changes.

## License
See [LICENSE](./LICENSE). 