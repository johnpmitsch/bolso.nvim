# bolso.nvim

Ergonomic yank/delete history for Neovim. Access your clipboard stack using home-row letter labels.

## The Problem

Vim's numbered registers (`"1`–`"9`) are awkward to reach and yanks/deletes are tracked separately. You have to think ahead to save things to named registers before you need them.

## The Solution

bolso.nvim automatically captures all yanks and deletes into a **unified LIFO stack** and lets you access them through a floating picker with **home-row labels**: `a` is always the most recent, `s` is second, `d` is third, and so on.

```
┌──────────── bolso ────────────────────┐
│ [a] const handleClick = () => {       │
│ [s] import React from 'react'         │
│ [d] npm run build                     │
│                                       │
│ Press label to select, <Esc> to cancel│
└───────────────────────────────────────┘
```

## Installation

### lazy.nvim

```lua
{
  'yourusername/bolso.nvim',
  config = function()
    require('bolso').setup()
  end,
}
```

### packer.nvim

```lua
use {
  'yourusername/bolso.nvim',
  config = function()
    require('bolso').setup()
  end,
}
```

## Usage

1. **`<leader>b`** — Open the bolso picker
2. **Press a label** (`a`, `s`, `d`, …) — Select that entry
3. **Press an action**:
   - `p` — Paste after cursor
   - `P` — Paste before cursor
   - `y` — Yank to system clipboard
4. **`<Esc>`** or **`q`** — Cancel at any point

## Configuration

```lua
require('bolso').setup({
  -- Home-row labels (change for Dvorak, Colemak, etc.)
  labels = 'asdfghjkl',

  -- Maximum stack depth
  max_items = 9,

  -- Floating window appearance
  window = {
    width = 60,
    border = 'rounded',  -- see :h nvim_open_win
  },

  -- Action key bindings
  actions = {
    p = 'paste_after',
    P = 'paste_before',
    y = 'yank_to_clipboard',
  },

  -- Trigger keymap (set to `false` to disable, then map yourself)
  keymap = '<leader>b',
})
```

### Dvorak Example

```lua
require('bolso').setup({
  labels = 'aoeuhtns',
})
```

## Commands

| Command       | Description        |
|---------------|--------------------|
| `:Bolso`      | Open the picker    |
| `:BolsoClear` | Clear the stack    |

## Indicators

- `¶` — linewise entry
- `█` — blockwise entry
- *(none)* — charwise entry

## How It Works

bolso.nvim uses a single `TextYankPost` autocmd to capture every yank (`y`), delete (`d`), and change (`c`) operation that goes to the unnamed register. Consecutive duplicate entries are automatically deduplicated. The stack is purely in-memory — nothing is persisted to disk.

## License

MIT