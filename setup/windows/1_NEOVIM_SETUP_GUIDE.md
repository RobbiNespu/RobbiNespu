# 🚀 Ultimate Neovim Setup Script

A comprehensive PowerShell script that sets up a complete, modern Neovim development environment on Windows with enhanced features and productivity tools.

## 📋 Overview

This script (`1_neovim.ps1`) automatically installs and configures:
- Complete Neovim configuration with modern plugins
- Language servers via Mason
- Essential development tools
- C compiler environment for TreeSitter
- Enhanced keybindings and productivity features

## ✨ Key Features

### 🎯 **Whitespace Visualization**
- **Toggle**: `<Space>w`
- Shows tabs as `→`, spaces as `·`
- Perfect for debugging YAML indentation issues
- Highlights trailing whitespace

### 🧭 **Enhanced Navigation**
- **Window Navigation**: `<Ctrl-h/j/k/l>`
- **Buffer Switching**: `<Shift-h/l>`
- **Centered Scrolling**: `<Ctrl-d/u>` keeps cursor centered
- **Smart Window Management**: Enhanced split controls

### ✏️ **Better Editing Experience**
- **Visual Text Movement**: `J` and `K` in visual mode
- **Smart Indenting**: Visual mode indenting stays selected
- **Auto-format**: On save for `.lua`, `.py`, `.js`, `.ts`, etc.
- **Whitespace Cleanup**: Automatic trailing whitespace removal

### 🔧 **Advanced Features**
- **Auto-format on save** for common file types
- **File change detection** when switching back to Neovim
- **Quick close**: Press `q` to close help, LSP info, etc.
- **Enhanced yank highlighting** with timeout

### 🐛 **Diagnostic Tools**
- **Trouble.nvim** with keybindings:
  - `<Space>xx` - Toggle diagnostics
  - `<Space>xw` - Workspace diagnostics
  - `<Space>xd` - Document diagnostics

### 🎨 **Beautiful Dashboard**
- **Alpha dashboard** with ASCII art
- **Quick actions**: Find files, new file, recent files, etc.
- **Shows on startup** for easy navigation

## 🛠️ Prerequisites

Before running the script, ensure you have:

1. **PowerShell 5.1+** (Windows 10/11)
2. **Scoop package manager** (for tool installation)
3. **Git** (for plugin management)
4. **Neovim** (will be installed if missing)

### Installing Scoop (if needed)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

## 🚀 Usage

### Basic Setup
```powershell
.\1_neovim.ps1
```

### Advanced Options
```powershell
# Force reinstall with automatic backup
.\1_neovim.ps1 -Force

# Skip backup (overwrite existing config)
.\1_neovim.ps1 -SkipBackup

# Fix existing configuration only
.\1_neovim.ps1 -FixOnly

# Setup configuration only (skip tools)
.\1_neovim.ps1 -SetupOnly

# Skip compiler installation
.\1_neovim.ps1 -NoCompiler

# Remove all Neovim configuration
.\1_neovim.ps1 -RemoveAll
```

## 📦 What Gets Installed

### 🛠️ **Development Tools**
- `ripgrep` (rg) - Fast text search
- `fd` - Enhanced file finder
- `unzip` - Archive extraction
- `gzip` - Compression support
- `wget` - Download utility

### 🐍 **Language Providers**
- **Node.js**: `neovim` npm package
- **Python**: `pynvim` package

### 🔨 **Compiler Support**
- **Visual Studio 2022** environment setup
- **MinGW** fallback installation
- **Automatic compiler detection**

## 🎮 Key Bindings

### 📁 **File Management**
- `<Space>e` - Toggle file explorer
- `<Space>ef` - Focus file explorer
- `<Space>ff` - Find files
- `<Space>fs` - Find in files
- `<Space>fr` - Find recent files
- `<Space>fb` - Find buffers
- `<Space>fh` - Find help

### 🪟 **Window Management**
- `<Space>sv` - Split vertically
- `<Space>sh` - Split horizontally
- `<Space>se` - Make splits equal
- `<Space>sx` - Close split
- `<Ctrl-h/j/k/l>` - Navigate windows

### 📄 **Buffer Navigation**
- `<Shift-l>` - Next buffer
- `<Shift-h>` - Previous buffer

### 🔍 **LSP Features**
- `gd` - Go to definition
- `gD` - Go to declaration
- `K` - Show hover documentation
- `<Space>ca` - Code actions
- `<Space>rn` - Rename symbol
- `gR` - Show references
- `gi` - Show implementations
- `]d` - Next diagnostic
- `[d` - Previous diagnostic
- `<Space>d` - Show line diagnostics
- `<Space>rs` - Restart LSP

### 🐛 **Diagnostics**
- `<Space>xx` - Toggle Trouble
- `<Space>xw` - Workspace diagnostics
- `<Space>xd` - Document diagnostics

### ✏️ **Editing**
- `gcc` - Comment/uncomment line
- `gc` - Comment/uncomment (visual)
- `<` - Indent left (visual)
- `>` - Indent right (visual)
- `J` - Move text down (visual)
- `K` - Move text up (visual)

### 📜 **Scrolling**
- `<Ctrl-d>` - Scroll down and center
- `<Ctrl-u>` - Scroll up and center

## 🔌 Plugins Included

### 🎨 **UI & Appearance**
- **Dracula** - Beautiful dark theme
- **nvim-tree** - File explorer
- **lualine** - Status line
- **bufferline** - Buffer tabs
- **alpha** - Dashboard
- **indent-blankline** - Indent guides

### 🔍 **Search & Navigation**
- **Telescope** - Fuzzy finder
- **which-key** - Keybinding hints
- **project.nvim** - Project management

### 💻 **Language Support**
- **TreeSitter** - Syntax highlighting
- **nvim-lspconfig** - LSP configuration
- **Mason** - LSP installer
- **nvim-cmp** - Autocompletion
- **LuaSnip** - Snippet engine

### 🛠️ **Development Tools**
- **gitsigns** - Git integration
- **nvim-autopairs** - Auto pairs
- **Comment.nvim** - Commenting
- **nvim-surround** - Surround text objects
- **todo-comments** - TODO highlighting
- **trouble.nvim** - Diagnostics list

### 📝 **Additional Features**
- **auto-session** - Session management
- **markdown-preview** - Markdown preview
- **codewindow** - Minimap
- **vim-fugitive** - Git commands

## 🌐 Language Servers

Automatically installed language servers:
- **lua_ls** - Lua
- **ts_ls** - TypeScript/JavaScript
- **html** - HTML
- **cssls** - CSS
- **tailwindcss** - Tailwind CSS
- **pyright** - Python

## 📁 Configuration Structure

```
%LOCALAPPDATA%\nvim\
├── init.lua                 # Main configuration
├── lua/
│   ├── config/
│   │   ├── options.lua      # Vim options
│   │   ├── keymaps.lua      # Key bindings
│   │   └── autocmds.lua     # Auto commands
│   └── plugins/
│       ├── init.lua         # Plugin manager
│       ├── colorscheme.lua  # Theme
│       ├── telescope.lua    # Fuzzy finder
│       ├── treesitter.lua   # Syntax highlighting
│       ├── lsp.lua          # Language servers
│       ├── completion.lua   # Autocompletion
│       └── ...              # Other plugins
└── README.md                # Configuration guide
```

## 🚀 Getting Started

1. **Run the script**:
   ```powershell
   .\1_neovim.ps1
   ```

2. **Open Neovim**:
   ```powershell
   nvim
   ```

3. **Wait for plugins** to install automatically (Lazy.nvim will handle this)

4. **Restart Neovim** after initial plugin installation

5. **Verify setup**:
   ```vim
   :checkhealth
   :LspInfo
   :Mason
   ```

## 🔧 Troubleshooting

### Common Issues

**C Compiler Errors**:
- Run the script again to setup Visual Studio environment
- Or install MinGW: `scoop install mingw`
- Or run with `-NoCompiler` flag

**Permission Errors**:
- Run PowerShell as Administrator
- Check execution policy: `Get-ExecutionPolicy`

**Plugin Installation Issues**:
- Check internet connection
- Run `:Lazy` in Neovim to check plugin status
- Restart Neovim after plugin installation

**LSP Issues**:
- Run `:Mason` to check language server status
- Run `:LspInfo` to see active language servers
- Restart LSP: `<Space>rs`

### Useful Commands

```vim
:Lazy          " Plugin manager interface
:Mason         " LSP server manager
:checkhealth   " Health check
:LspInfo       " LSP status
:TSUpdate      " Update TreeSitter parsers
:set list!     " Toggle whitespace visualization
:Telescope     " Open Telescope picker
:Alpha         " Open dashboard
```

## 🎯 Tips & Tricks

### Whitespace Visualization
- Press `<Space>w` to toggle whitespace display
- Perfect for debugging YAML indentation
- Shows tabs as `→` and spaces as `·`

### Quick Navigation
- Use `<Ctrl-h/j/k/l>` for window navigation
- Use `<Shift-h/l>` for buffer switching
- Use `<Space>ff` for instant file finding

### Diagnostics
- Use `<Space>xx` to open Trouble diagnostics
- Navigate through errors with `]d` and `[d`
- Get quick fixes with `<Space>ca`

## 📝 Customization

The configuration is modular and easy to customize:

- **Options**: Edit `lua/config/options.lua`
- **Keymaps**: Edit `lua/config/keymaps.lua`
- **Autocmds**: Edit `lua/config/autocmds.lua`
- **Plugins**: Edit `lua/plugins/` files

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

**Happy coding with your enhanced Neovim setup!** 🎉
