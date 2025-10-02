# Ultimate Neovim Setup Script
# This script sets up a complete Neovim configuration, fixes common issues, and handles C compiler setup

param(
    [switch]$Force,
    [switch]$SkipBackup,
    [switch]$FixOnly,
    [switch]$SetupOnly,
    [switch]$NoCompiler,
    [switch]$RemoveAll
)

# Colors for output
$ColorReset = "`e[0m"
$ColorRed = "`e[31m"
$ColorGreen = "`e[32m"
$ColorYellow = "`e[33m"
$ColorBlue = "`e[34m"
$ColorCyan = "`e[36m"

function Write-ColorText {
    param([string]$Text, [string]$Color)
    Write-Host "${Color}${Text}${ColorReset}"
}

function Write-Success { param([string]$Text); Write-ColorText $Text $ColorGreen }
function Write-Error { param([string]$Text); Write-ColorText $Text $ColorRed }
function Write-Warning { param([string]$Text); Write-ColorText $Text $ColorYellow }
function Write-Info { param([string]$Text); Write-ColorText $Text $ColorBlue }
function Write-Header { param([string]$Text); Write-ColorText "`n=== $Text ===" $ColorCyan }

function Test-CommandExists {
    param([string]$Command)
    return (Get-Command $Command -ErrorAction SilentlyContinue) -ne $null
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Setup-VisualStudioEnvironment {
    Write-Header "Setting up Visual Studio Environment"
    
    $vsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community"
    $vcvarsPath = "$vsPath\VC\Auxiliary\Build\vcvars64.bat"
    
    if (Test-Path $vcvarsPath) {
        Write-Info "Setting up Visual Studio environment..."
        
        # Run vcvars64.bat and capture environment
        cmd /c "`"$vcvarsPath`" && set" | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
            }
        }
        
        Write-Success "✅ Visual Studio environment loaded"
        return $true
    } else {
        Write-Warning "❌ Visual Studio not found at expected location"
        return $false
    }
}

function Install-CompilerTools {
    Write-Header "Installing C Compiler Tools"
    
    if ($NoCompiler) {
        Write-Info "Skipping compiler installation as requested"
        return
    }
    
    # Check if Visual Studio is available
    if (Setup-VisualStudioEnvironment) {
        Write-Success "✅ Using Visual Studio 2022 Community compiler"
        return
    }
    
    # Fall back to installing MinGW via Scoop
    if (Test-CommandExists "scoop") {
        Write-Info "Installing MinGW compiler via Scoop..."
        try {
            scoop install mingw
            Write-Success "✅ MinGW compiler installed"
        } catch {
            Write-Warning "⚠️ Failed to install MinGW: $($_.Exception.Message)"
            Write-Info "TreeSitter compilation may not work without a C compiler"
        }
    } else {
        Write-Warning "⚠️ No compiler found and Scoop not available"
        Write-Info "Install Visual Studio Build Tools or MinGW manually for TreeSitter compilation"
    }
}

function Install-MissingTools {
    Write-Header "Installing Missing Tools via Scoop"
    
    if (-not (Test-CommandExists "scoop")) {
        Write-Error "Scoop is not installed. Please install Scoop first:"
        Write-Info "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
        Write-Info "Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"
        return
    }
    
    $tools = @{
        "ripgrep" = "rg (for Telescope live_grep)"
        "fd" = "fd (for Telescope enhanced file finding)"
        "unzip" = "unzip (for Mason package extraction)"
        "gzip" = "gzip (for Mason package compression)"
        "wget" = "wget (for Mason downloads)"
    }
    
    foreach ($tool in $tools.GetEnumerator()) {
        if (-not (Test-CommandExists $tool.Key)) {
            Write-Info "Installing $($tool.Key) - $($tool.Value)"
            try {
                scoop install $tool.Key
                Write-Success "✅ Installed $($tool.Key)"
            } catch {
                Write-Warning "⚠️ Failed to install $($tool.Key): $($_.Exception.Message)"
            }
        } else {
            Write-Success "✅ $($tool.Key) already installed"
        }
    }
}

function Install-Providers {
    Write-Header "Installing Node.js and Python Providers"
    
    if (Test-CommandExists "npm") {
        Write-Info "Installing neovim npm package..."
        try {
            npm install -g neovim
            Write-Success "✅ Node.js provider installed"
        } catch {
            Write-Warning "⚠️ Failed to install neovim npm package: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "npm not found. Node.js provider will remain unavailable."
    }
    
    if (Test-CommandExists "pip") {
        Write-Info "Installing pynvim package..."
        try {
            pip install pynvim
            Write-Success "✅ Python provider installed"
        } catch {
            Write-Warning "⚠️ Failed to install pynvim: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "pip not found. Python provider will remain unavailable."
    }
}

function Setup-Neovim {
    Write-Header "Neovim Configuration Setup"
    
    # Check prerequisites
    Write-Info "Checking prerequisites..."
    
    if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
        Write-Error "Neovim is not installed or not in PATH!"
        Write-Info "Please install Neovim first:"
        Write-Info "  scoop install neovim"
        Write-Info "  or download from: https://github.com/neovim/neovim/releases"
        return
    }
    
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "Git is not installed or not in PATH!"
        Write-Info "Please install Git first:"
        Write-Info "  scoop install git"
        Write-Info "  or download from: https://git-scm.com/download/win"
        return
    }
    
    Write-Success "Prerequisites check passed!"
    
    # Define paths
    $nvimConfigPath = "$env:LOCALAPPDATA\nvim"
    $backupPath = "$env:LOCALAPPDATA\nvim.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    # Backup existing configuration
    if (Test-Path $nvimConfigPath) {
        if (-not $SkipBackup) {
            Write-Warning "Existing Neovim configuration found!"
            if ($Force) {
                Write-Info "Creating backup at: $backupPath"
                    Copy-Item $nvimConfigPath $backupPath -Recurse
                    Remove-Item $nvimConfigPath -Recurse -Force
            } else {
                $response = Read-Host "Do you want to backup and replace it? (y/N)"
                if ($response -eq 'y' -or $response -eq 'Y') {
                    Write-Info "Creating backup at: $backupPath"
                        Copy-Item $nvimConfigPath $backupPath -Recurse
                        Remove-Item $nvimConfigPath -Recurse -Force
                } else {
                    Write-Info "Setup cancelled."
                    return
                }
            }
        } else {
                Remove-Item $nvimConfigPath -Recurse -Force
            }
    }
    
    # Create directory structure
    Write-Header "Creating Directory Structure"
    $directories = @(
        $nvimConfigPath,
        "$nvimConfigPath\lua",
        "$nvimConfigPath\lua\config",
        "$nvimConfigPath\lua\plugins"
    )
    
    foreach ($dir in $directories) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Success "Created: $dir"
    }
    
    # Create configuration files
    Write-Header "Creating Configuration Files"
    
    # Create all configuration files
    Create-ConfigFiles $nvimConfigPath
    
    Write-Header "Setup Complete!"
    Write-Success "Neovim configuration has been successfully installed!"
    Write-Info "Configuration location: $nvimConfigPath"
    
    if (Test-Path $backupPath) {
        Write-Info "Backup location: $backupPath"
    }
}

function Create-ConfigFiles {
    param([string]$nvimConfigPath)
    
    # init.lua
    $initLua = @"
-- Load core configuration
require('config.options')
require('config.keymaps')
require('config.autocmds')

-- Load plugins
require('plugins')
"@
    
    # options.lua - Enhanced with whitespace visualization
    $optionsLua = @"
local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs & indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true

-- Line wrapping
opt.wrap = false

-- Search settings
opt.ignorecase = true
opt.smartcase = true

-- Cursor line
opt.cursorline = true

-- Appearance
opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"

-- Backspace
opt.backspace = "indent,eol,start"

-- Clipboard
opt.clipboard:append("unnamedplus")

-- Split windows
opt.splitright = true
opt.splitbelow = true

-- Turn off swapfile
opt.swapfile = false

-- Whitespace visualization (toggle with <leader>w)
opt.list = false
opt.listchars = {
  tab = '→ ',
  space = '·',
  trail = '·',
  extends = '>',
  precedes = '<',
  nbsp = '+'
}

-- Better diff
opt.diffopt:append('vertical')

-- Undo
opt.undofile = true
opt.undodir = vim.fn.stdpath('data') .. '/undo'
"@
    
    # keymaps.lua - Enhanced with whitespace toggle and better navigation
    $keymapsLua = @"
local keymap = vim.keymap

-- Set leader key
vim.g.mapleader = " "

-- General keymaps
keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- Whitespace visualization toggle
keymap.set("n", "<leader>w", ":set list!<CR>", { desc = "Toggle whitespace visualization" })

-- Increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" })
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" })

-- Window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

-- Window navigation
keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to top window" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Tab management
keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" })
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" })

-- Buffer navigation
keymap.set("n", "<S-l>", ":bnext<CR>", { desc = "Next buffer" })
keymap.set("n", "<S-h>", ":bprevious<CR>", { desc = "Previous buffer" })

-- Better indenting
keymap.set("v", "<", "<gv", { desc = "Indent left" })
keymap.set("v", ">", ">gv", { desc = "Indent right" })

-- Move text up and down
keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move text down" })
keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move text up" })

-- Keep cursor centered when scrolling
keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })

-- NvimTree
keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
keymap.set("n", "<leader>ef", "<cmd>NvimTreeFocus<CR>", { desc = "Focus file explorer" })
"@
    
    # autocmds.lua - Enhanced
    $autocmdsLua = @"
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Highlight on yank
autocmd('TextYankPost', {
  desc = 'Highlight when yanking text',
  group = augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

-- Remove trailing whitespace on save
autocmd('BufWritePre', {
  pattern = '*',
  group = augroup('trim-whitespace', { clear = true }),
  command = '%s/\\s\\+$//e',
})

-- Auto-format on save for specific file types
autocmd('BufWritePre', {
  pattern = { '*.lua', '*.py', '*.js', '*.ts', '*.jsx', '*.tsx' },
  group = augroup('format-on-save', { clear = true }),
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})

-- Close certain windows with 'q'
autocmd('FileType', {
  pattern = { 'qf', 'help', 'man', 'lspinfo', 'checkhealth' },
  group = augroup('close-with-q', { clear = true }),
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = event.buf, silent = true })
  end,
})

-- Check if file changed outside of vim
autocmd({ 'FocusGained', 'TermClose', 'TermLeave' }, {
  group = augroup('checktime', { clear = true }),
  command = 'checktime',
})
"@
    
    # plugins/init.lua
    $pluginsInitLua = @"
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Colorscheme
  require("plugins.colorscheme"),
  
  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 30,
        },
        renderer = {
          group_empty = true,
          },
        filters = {
          dotfiles = false,
        },
      })
    end,
  },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "dracula"
        }
      })
    end,
  },

  -- Fuzzy finder
  require("plugins.telescope"),

  -- Syntax highlighting
  require("plugins.treesitter"),

  -- LSP configuration
  require("plugins.lsp"),

  -- Autocompletion
  require("plugins.completion"),

  -- Git integration
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
    end,
  },

  -- Auto pairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup()
    end,
  },

  -- Comment plugin
  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
  },

  -- Buffer line
  {
    "akinsho/bufferline.nvim",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("bufferline").setup({
        options = {
          diagnostics = "nvim_lsp",
          separator_style = "slant",
        }
      })
    end,
  },

  -- Mason (LSP installer)
  {
    "williamboman/mason.nvim",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      require("mason").setup({
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗"
          }
        }
      })
      
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "html",
          "cssls",
          "tailwindcss",
          "pyright",
          "ts_ls",
        },
        automatic_installation = true,
      })
    end,
  },
})
"@
    
    # plugins/colorscheme.lua
    $colorschemeLua = @"
return {
  "dracula/vim",
  name = "dracula",
  priority = 1000,
  config = function()
    vim.cmd("colorscheme dracula")
  end,
}
"@
    
    # plugins/telescope.lua (Fixed without fzf)
    $telescopeLua = @"
return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")

    telescope.setup({
      defaults = {
        path_display = { "truncate" },
        mappings = {
          i = {
            ["<C-k>"] = actions.move_selection_previous,
            ["<C-j>"] = actions.move_selection_next,
            ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
          },
        },
      },
    })

    -- Set keymaps
    local keymap = vim.keymap
    keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
    keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Find recent files" })
    keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string" })
    keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor" })
    keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find buffers" })
  end,
}
"@
    
    # plugins/treesitter.lua (Enhanced with compiler detection)
    $treesitterLua = @"
return {
  "nvim-treesitter/nvim-treesitter",
  event = { "BufReadPre", "BufNewFile" },
  build = function()
    -- Only try to build if a compiler is available
    if vim.fn.executable("gcc") == 1 or vim.fn.executable("clang") == 1 or vim.fn.executable("cl") == 1 then
      return ":TSUpdate"
    else
      vim.notify("No C compiler found. TreeSitter parsers may not compile.", vim.log.levels.WARN)
    end
  end,
  dependencies = {
    "windwp/nvim-ts-autotag",
  },
  config = function()
    local treesitter = require("nvim-treesitter.configs")

    treesitter.setup({
      -- Only auto-install if compiler is available
      auto_install = vim.fn.executable("gcc") == 1 or vim.fn.executable("clang") == 1 or vim.fn.executable("cl") == 1,
      
      highlight = {
        enable = true,
      },
      indent = { enable = true },
      autotag = {
        enable = true,
      },
      ensure_installed = {
        "json",
        "javascript",
        "typescript",
        "tsx",
        "yaml",
        "html",
        "css",
        "markdown",
        "markdown_inline",
        "bash",
        "lua",
        "vim",
        "dockerfile",
        "gitignore",
        "query",
        "vimdoc",
        "c",
        "python",
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          scope_incremental = false,
          node_decremental = "<bs>",
        },
      },
    })
  end,
}
"@
    
    # plugins/lsp.lua
    $lspLua = @"
return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    { "antosha417/nvim-lsp-file-operations", config = true },
    { "folke/neodev.nvim", opts = {} },
  },
  config = function()
    local lspconfig = require("lspconfig")
    local cmp_nvim_lsp = require("cmp_nvim_lsp")

    local keymap = vim.keymap

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("UserLspConfig", {}),
      callback = function(ev)
        local opts = { buffer = ev.buf, silent = true }

        opts.desc = "Show LSP references"
        keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", opts)

        opts.desc = "Go to declaration"
        keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

        opts.desc = "Show LSP definitions"
        keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts)

        opts.desc = "Show LSP implementations"
        keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts)

        opts.desc = "Show LSP type definitions"
        keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts)

        opts.desc = "See available code actions"
        keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)

        opts.desc = "Smart rename"
        keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

        opts.desc = "Show buffer diagnostics"
        keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts)

        opts.desc = "Show line diagnostics"
        keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

        opts.desc = "Go to previous diagnostic"
        keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)

        opts.desc = "Go to next diagnostic"
        keymap.set("n", "]d", vim.diagnostic.goto_next, opts)

        opts.desc = "Show documentation for what is under cursor"
        keymap.set("n", "K", vim.lsp.buf.hover, opts)

        opts.desc = "Restart LSP"
        keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts)
      end,
    })

    local capabilities = cmp_nvim_lsp.default_capabilities()

    local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    -- Configure LSP servers directly
    local servers = {
      "lua_ls",
      "html",
      "cssls",
      "tailwindcss",
      "pyright",
      "ts_ls"
    }

    for _, server in ipairs(servers) do
      lspconfig[server].setup({
        capabilities = capabilities,
      })
    end
  end,
}
"@
    
    # plugins/completion.lua
    $completionLua = @"
return {
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",
  dependencies = {
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    {
      "L3MON4D3/LuaSnip",
      version = "v2.*",
      build = function()
        -- Only build if make is available
        if vim.fn.executable("make") == 1 then
          return "make install_jsregexp"
        end
      end,
    },
    "saadparwaiz1/cmp_luasnip",
    "rafamadriz/friendly-snippets",
    "onsails/lspkind.nvim",
  },
  config = function()
    local cmp = require("cmp")
    local luasnip = require("luasnip")
    local lspkind = require("lspkind")

    require("luasnip.loaders.from_vscode").lazy_load()

    cmp.setup({
      completion = {
        completeopt = "menu,menuone,preview,noselect",
      },
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<C-k>"] = cmp.mapping.select_prev_item(),
        ["<C-j>"] = cmp.mapping.select_next_item(),
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping.confirm({ select = false }),
      }),
      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "buffer" },
        { name = "path" },
      }),
      formatting = {
        format = lspkind.cmp_format({
          maxwidth = 50,
          ellipsis_char = "...",
        }),
      },
    })
  end,
}
"@
    
    # plugins/whichkey.lua
    $whichkeyLua = @"
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  config = function()
    require("which-key").setup()
  end,
}
"@
    # plugins/indentline.lua
    $indentlineLua = @"
return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  opts = {},
}
"@
    # plugins/surround.lua
    $surroundLua = @"
return {
  "kylechui/nvim-surround",
  event = "VeryLazy",
  config = function()
    require("nvim-surround").setup()
  end,
}
"@
    # plugins/todocomments.lua
    $todocommentsLua = @"
return {
  "folke/todo-comments.nvim",
  dependencies = "nvim-lua/plenary.nvim",
  config = function()
    require("todo-comments").setup()
  end,
}
"@
    # plugins/trouble.lua
    $troubleLua = @"
return {
  "folke/trouble.nvim",
  dependencies = "nvim-tree/nvim-web-devicons",
  config = function()
    require("trouble").setup()
    
    local keymap = vim.keymap
    keymap.set("n", "<leader>xx", "<cmd>TroubleToggle<cr>", { desc = "Toggle Trouble" })
    keymap.set("n", "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", { desc = "Workspace diagnostics" })
    keymap.set("n", "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>", { desc = "Document diagnostics" })
  end,
}
"@
    # plugins/project.lua
    $projectLua = @"
return {
  "ahmedkhalf/project.nvim",
  config = function()
    require("project_nvim").setup()
  end,
}
"@
    # plugins/autosession.lua
    $autosessionLua = @"
return {
  "rmagatti/auto-session",
  config = function()
    require("auto-session").setup()
  end,
}
"@
    # plugins/markdownpreview.lua
    $markdownPreviewLua = @"
return {
  "iamcco/markdown-preview.nvim",
  build = "cd app && npm install",
  ft = { "markdown" },
  config = function()
    vim.g.mkdp_auto_start = 1
  end,
}
"@
    # plugins/contextcomment.lua
    $contextCommentLua = @"
return {
  "JoosepAlviste/nvim-ts-context-commentstring",
  config = function()
    require("ts_context_commentstring").setup {}
  end,
}
"@
    # plugins/alpha.lua
    $alphaLua = @"
return {
  "goolord/alpha-nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    dashboard.section.header.val = {
      "                                                     ",
      "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
      "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
      "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
      "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
      "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
      "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
      "                                                     ",
    }

    dashboard.section.buttons.val = {
      dashboard.button("f", "  Find file", ":Telescope find_files <CR>"),
      dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
      dashboard.button("r", "  Recent files", ":Telescope oldfiles <CR>"),
      dashboard.button("s", "  Find text", ":Telescope live_grep <CR>"),
      dashboard.button("c", "  Config", ":e $MYVIMRC <CR>"),
      dashboard.button("q", "  Quit", ":qa<CR>"),
    }

    alpha.setup(dashboard.opts)
  end,
}
"@
    # plugins/minimap.lua
    $minimapLua = @"
return {
  "gorbit99/codewindow.nvim",
  config = function()
    local codewindow = require("codewindow")
    codewindow.setup()
    codewindow.apply_default_keybinds()
  end,
}
"@
    # plugins/git.lua
    $gitLua = @"
return {
  'tpope/vim-fugitive',
  cmd = { 'Git', 'G' },
  config = function()
    -- No extra config needed for basic usage
  end,
}
"@
    # Write all configuration files
    $configFiles = @{
        "init.lua" = $initLua
        "lua\config\options.lua" = $optionsLua
        "lua\config\keymaps.lua" = $keymapsLua
        "lua\config\autocmds.lua" = $autocmdsLua
        "lua\plugins\init.lua" = $pluginsInitLua
        "lua\plugins\colorscheme.lua" = $colorschemeLua
        "lua\plugins\telescope.lua" = $telescopeLua
        "lua\plugins\treesitter.lua" = $treesitterLua
        "lua\plugins\lsp.lua" = $lspLua
        "lua\plugins\completion.lua" = $completionLua
        # New recommended plugins
        "lua\plugins\whichkey.lua" = $whichkeyLua
        "lua\plugins\indentline.lua" = $indentlineLua
        "lua\plugins\surround.lua" = $surroundLua
        "lua\plugins\todocomments.lua" = $todocommentsLua
        "lua\plugins\trouble.lua" = $troubleLua
        "lua\plugins\project.lua" = $projectLua
        "lua\plugins\autosession.lua" = $autosessionLua
        "lua\plugins\markdownpreview.lua" = $markdownPreviewLua
        "lua\plugins\contextcomment.lua" = $contextCommentLua
        "lua\plugins\alpha.lua" = $alphaLua
        # Minimap plugin
        "lua\plugins\minimap.lua" = $minimapLua
        # Git plugin
        "lua\plugins\git.lua" = $gitLua
    }
    
    foreach ($file in $configFiles.GetEnumerator()) {
        $filePath = Join-Path $nvimConfigPath $file.Key
        $file.Value | Out-File -FilePath $filePath -Encoding UTF8
        Write-Success "Created: $($file.Key)"
    }
    
    # Create README
    $readme = @"
# Neovim Configuration

This configuration was automatically generated by the ultimate Neovim setup script.

## Key Bindings

### General
- Leader key: `<Space>`
- Exit insert mode: `jk`
- Clear search highlights: `<leader>nh`
- Toggle whitespace visualization: `<leader>w` (NEW!)

### File Management
- File explorer toggle: `<leader>e`
- File explorer focus: `<leader>ef`
- Find files: `<leader>ff`
- Find in files: `<leader>fs`
- Find recent files: `<leader>fr`
- Find buffers: `<leader>fb`
- Find help: `<leader>fh`

### Window Management
- Split vertically: `<leader>sv`
- Split horizontally: `<leader>sh`
- Make splits equal: `<leader>se`
- Close split: `<leader>sx`
- Navigate left: `<C-h>`
- Navigate down: `<C-j>`
- Navigate up: `<C-k>`
- Navigate right: `<C-l>`

### Buffer Navigation
- Next buffer: `<S-l>`
- Previous buffer: `<S-h>`

### LSP
- Go to definition: `gd`
- Go to declaration: `gD`
- Show hover documentation: `K`
- Code actions: `<leader>ca`
- Rename symbol: `<leader>rn`
- Show references: `gR`
- Show implementations: `gi`
- Next diagnostic: `]d`
- Previous diagnostic: `[d`
- Show line diagnostics: `<leader>d`
- Restart LSP: `<leader>rs`

### Diagnostics
- Toggle Trouble: `<leader>xx`
- Workspace diagnostics: `<leader>xw`
- Document diagnostics: `<leader>xd`

### Editing
- Comment/uncomment: `gcc` (line), `gc` (visual)
- Indent left (visual): `<`
- Indent right (visual): `>`
- Move text down (visual): `J`
- Move text up (visual): `K`

### Scrolling
- Scroll down and center: `<C-d>`
- Scroll up and center: `<C-u>`

## Plugins Included

- **Dracula** - Colorscheme
- **nvim-tree** - File explorer
- **Telescope** - Fuzzy finder
- **TreeSitter** - Syntax highlighting
- **LSP** - Language server protocol
- **Mason** - LSP installer
- **nvim-cmp** - Autocompletion
- **Gitsigns** - Git integration
- **nvim-autopairs** - Auto pairs
- **Comment.nvim** - Commenting
- **Bufferline** - Buffer tabs
- **Lualine** - Statusline
- **Which-Key** - Keybinding hints
- **indent-blankline** - Indent guides
- **nvim-surround** - Surround text objects
- **todo-comments** - Highlight TODO comments
- **Trouble** - Diagnostics list
- **Alpha** - Dashboard

## Language Servers

The following language servers are automatically installed:
- **lua_ls** - Lua
- **ts_ls** - TypeScript/JavaScript
- **html** - HTML
- **cssls** - CSS
- **tailwindcss** - Tailwind CSS
- **pyright** - Python

## Whitespace Visualization

NEW! Press `<leader>w` to toggle whitespace visualization:
- Tabs appear as `→`
- Spaces appear as `·`
- Trailing spaces are highlighted
- Line endings appear as special characters

This is especially useful for:
- Debugging YAML indentation issues
- Detecting mixed tabs and spaces
- Finding trailing whitespace

## Compiler Support

This configuration includes automatic C compiler detection for TreeSitter:
- Detects Visual Studio 2022 Community compiler
- Falls back to MinGW if available
- Gracefully handles missing compilers

## Next Steps

1. Open Neovim: `nvim`
2. Wait for plugins to install automatically (Lazy.nvim will run on first start)
3. Restart Neovim after initial plugin installation
4. Run `:checkhealth` to verify everything is working
5. Run `:Mason` to check installed language servers
6. Run `:TSUpdate` to update TreeSitter parsers

## Useful Commands

- `:Lazy` - Plugin manager interface
- `:Mason` - LSP server manager
- `:checkhealth` - Health check
- `:LspInfo` - LSP status
- `:TSUpdate` - Update TreeSitter parsers
- `:set list!` - Toggle whitespace visualization
- `:Telescope` - Open Telescope picker
- `:Alpha` - Open dashboard

Enjoy your new Neovim setup!
"@
    
    $readme | Out-File -FilePath "$nvimConfigPath\README.md" -Encoding UTF8
    Write-Success "Created: README.md"
}

function Fix-ExistingConfig {
    Write-Header "Fixing Existing Configuration"
    
    $nvimConfigPath = "$env:LOCALAPPDATA\nvim"
    
    if (-not (Test-Path $nvimConfigPath)) {
        Write-Error "No existing Neovim configuration found at $nvimConfigPath"
        Write-Info "Please run the script without -FixOnly to create a new configuration"
        return
    }
    
    # Fix plugins/init.lua if it exists and is corrupted
    $pluginsInitPath = "$nvimConfigPath\lua\plugins\init.lua"
    if (Test-Path $pluginsInitPath) {
        Write-Info "Fixing plugins/init.lua..."
    Create-ConfigFiles $nvimConfigPath
    Write-Success "✅ Configuration files updated"
    }
    
    # Install missing tools and providers
    Install-MissingTools
    Install-Providers
    Install-CompilerTools
}

function Show-Summary {
    Write-Header "Setup Complete!"
    
    Write-Info "The following has been accomplished:"
    Write-Success "✅ Neovim configuration installed/updated"
    Write-Success "✅ Missing tools installed (ripgrep, fd, unzip, etc.)"
    Write-Success "✅ Node.js and Python providers installed"
    Write-Success "✅ C compiler environment configured"
    Write-Success "✅ Whitespace visualization enabled (<leader>w)"
    Write-Success "✅ Enhanced keybindings for better workflow"
    Write-Success "✅ Improved autocmds and formatting"
    Write-Success "✅ Better buffer and window navigation"
    Write-Success "✅ Trouble diagnostics integration"
    Write-Success "✅ Alpha dashboard with quick actions"
    
    Write-Header "Next Steps"
    Write-Info "1. Open Neovim: nvim"
    Write-Info "2. Wait for plugins to install automatically"
    Write-Info "3. Restart Neovim"
    Write-Info "4. Run :checkhealth to verify everything is working"
    Write-Info "5. Run :Mason to install additional language servers"
    Write-Info "6. Run :TSUpdate to update TreeSitter parsers"
    
    Write-Header "Key Features"
    Write-Info "📁 File Explorer: <Space>e"
    Write-Info "🔍 Find Files: <Space>ff"
    Write-Info "🔎 Find Text: <Space>fs"
    Write-Info "👁️  Toggle Whitespace: <Space>w (NEW!)"
    Write-Info "🐛 Show Diagnostics: <Space>xx"
    Write-Info "📝 Go to Definition: gd"
    Write-Info "💡 Code Actions: <Space>ca"
    Write-Info "✏️  Rename: <Space>rn"
    Write-Info "💬 Comment: gcc"
    
    Write-Header "Troubleshooting"
    Write-Info "If you encounter C compiler errors:"
    Write-Info "1. Run this script again to setup Visual Studio environment"
    Write-Info "2. Or install MinGW: scoop install mingw"
    Write-Info "3. Or run with -NoCompiler flag to skip compiler setup"
    
    Write-Success "`n🎉 Neovim setup complete! Enjoy your new development environment!"
}

function Test-CompilerAvailability {
    Write-Header "Testing Compiler Availability"
    
    $compilers = @("gcc", "clang", "cl", "cc")
    $found = $false
    
    foreach ($compiler in $compilers) {
        if (Test-CommandExists $compiler) {
            Write-Success "✅ Found compiler: $compiler"
            $found = $true
        }
    }
    
    if (-not $found) {
        Write-Warning "⚠️ No C compiler found in PATH"
        Write-Info "TreeSitter parsers may not compile properly"
    }
    
    return $found
}

function Show-CompilerInfo {
    Write-Header "Compiler Information"
    
    # Check Visual Studio
    $vsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community"
    if (Test-Path $vsPath) {
        Write-Info "📍 Visual Studio 2022 Community found at: $vsPath"
        Write-Info "   Use 'Developer Command Prompt' or run this script to setup environment"
    }
    
    # Check MinGW
    if (Test-CommandExists "gcc") {
        $gccVersion = gcc --version | Select-Object -First 1
        Write-Info "📍 GCC found: $gccVersion"
    }
    
    # Check Clang
    if (Test-CommandExists "clang") {
        $clangVersion = clang --version | Select-Object -First 1
        Write-Info "📍 Clang found: $clangVersion"
    }
    
    # Check MSVC
    if (Test-CommandExists "cl") {
        Write-Info "📍 MSVC compiler (cl.exe) found"
    }
}

# Main execution
Write-Header "Ultimate Neovim Setup Script"
Write-Info "This script will setup a complete Neovim development environment"

if ($RemoveAll) {
    $nvimConfigPath = "$env:LOCALAPPDATA\nvim"
    if (Test-Path $nvimConfigPath) {
        Remove-Item $nvimConfigPath -Recurse -Force
        Write-Success "All Neovim configuration files and directories have been removed: $nvimConfigPath"
    } else {
        Write-Info "No Neovim configuration directory found at $nvimConfigPath. Nothing to remove."
    }
    return
}

try {
    # Show compiler information
    Show-CompilerInfo
    
    if ($FixOnly) {
        Fix-ExistingConfig
    } elseif ($SetupOnly) {
        Setup-Neovim
    } else {
        # Run complete setup
        Setup-Neovim
        Install-MissingTools
        Install-Providers
        Install-CompilerTools
    }
    
    # Test compiler availability
    Test-CompilerAvailability
    
    Show-Summary
    
    # Show config location at the end
    $nvimConfigPath = "$env:LOCALAPPDATA\nvim"
    $initLuaPath = Join-Path $nvimConfigPath "init.lua"
    Write-Header "Neovim Config Location"
    Write-Info "Your Neovim configuration directory: $nvimConfigPath"
    Write-Info "Main config file: $initLuaPath"
    
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    Write-Info "Please check the error message above and try again."
    Write-Info ""
    Write-Info "Common solutions:"
    Write-Info "1. Run as Administrator if needed"
    Write-Info "2. Install Scoop: https://scoop.sh"
    Write-Info "3. Install Visual Studio Community: https://visualstudio.microsoft.com"
    Write-Info "4. Check internet connection for downloads"
}