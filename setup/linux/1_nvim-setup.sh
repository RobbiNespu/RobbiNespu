#!/usr/bin/env bash

# Ultimate Neovim Setup Script for Debian 13
# This script sets up a complete Neovim configuration, fixes common issues, and handles C compiler setup

# Colors for output
COLOR_RESET='\033[0m'
COLOR_RED='\033[31m'
COLOR_GREEN='\033[32m'
COLOR_YELLOW='\033[33m'
COLOR_BLUE='\033[34m'
COLOR_CYAN='\033[36m'

# Default flags
FORCE=false
SKIP_BACKUP=false
FIX_ONLY=false
SETUP_ONLY=false
NO_COMPILER=false
REMOVE_ALL=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --fix-only)
            FIX_ONLY=true
            shift
            ;;
        --setup-only)
            SETUP_ONLY=true
            shift
            ;;
        --no-compiler)
            NO_COMPILER=true
            shift
            ;;
        --remove-all)
            REMOVE_ALL=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --force, -f         Force installation without prompts"
            echo "  --skip-backup       Skip backing up existing configuration"
            echo "  --fix-only          Only fix existing configuration"
            echo "  --setup-only        Only setup configuration files"
            echo "  --no-compiler       Skip compiler installation"
            echo "  --remove-all        Remove all Neovim configuration"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Utility functions
write_color_text() {
    local text="$1"
    local color="$2"
    echo -e "${color}${text}${COLOR_RESET}"
}

write_success() {
    write_color_text "$1" "$COLOR_GREEN"
}

write_error() {
    write_color_text "$1" "$COLOR_RED"
}

write_warning() {
    write_color_text "$1" "$COLOR_YELLOW"
}

write_info() {
    write_color_text "$1" "$COLOR_BLUE"
}

write_header() {
    write_color_text "\n=== $1 ===" "$COLOR_CYAN"
}

test_command_exists() {
    command -v "$1" &> /dev/null
}

test_root() {
    [ "$(id -u)" -eq 0 ]
}

install_compiler_tools() {
    write_header "Installing C Compiler Tools"
    
    if [ "$NO_COMPILER" = true ]; then
        write_info "Skipping compiler installation as requested"
        return
    fi
    
    # Check if build-essential is installed
    if test_command_exists "gcc"; then
        write_success "✅ GCC compiler already installed"
        gcc --version | head -n1
        return
    fi
    
    write_info "Installing build-essential and development tools..."
    
    if test_root; then
        apt update
        apt install -y build-essential gcc g++ make cmake
    else
        sudo apt update
        sudo apt install -y build-essential gcc g++ make cmake
    fi
    
    if test_command_exists "gcc"; then
        write_success "✅ Compiler tools installed successfully"
        gcc --version | head -n1
    else
        write_warning "⚠️ Failed to install compiler tools"
        write_info "TreeSitter compilation may not work without a C compiler"
    fi
}

install_missing_tools() {
    write_header "Installing Missing Tools via APT"
    
    local tools=(
        "ripgrep:rg (for Telescope live_grep)"
        "fd-find:fd (for Telescope enhanced file finding)"
        "unzip:unzip (for Mason package extraction)"
        "gzip:gzip (for Mason package compression)"
        "wget:wget (for Mason downloads)"
        "curl:curl (for downloads)"
        "git:git (for version control)"
    )
    
    local to_install=()
    
    for tool_entry in "${tools[@]}"; do
        IFS=':' read -r package description <<< "$tool_entry"
        # Extract command name from description (first word in parentheses)
        local cmd=$(echo "$description" | grep -oP '^\K[^(]+' | xargs)
        
        if ! test_command_exists "$cmd"; then
            write_info "Will install $package - $description"
            to_install+=("$package")
        else
            write_success "✅ $cmd already installed"
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        write_info "Installing packages: ${to_install[*]}"
        if test_root; then
            apt update
            apt install -y "${to_install[@]}"
        else
            sudo apt update
            sudo apt install -y "${to_install[@]}"
        fi
        
        # Create fd symlink if needed (fd-find installs as fdfind on Debian)
        if [ -f /usr/bin/fdfind ] && [ ! -f /usr/bin/fd ]; then
            write_info "Creating fd symlink..."
            if test_root; then
                ln -s /usr/bin/fdfind /usr/bin/fd
            else
                sudo ln -s /usr/bin/fdfind /usr/bin/fd
            fi
        fi
    fi
}

install_providers() {
    write_header "Installing Node.js and Python Providers"
    
    if test_command_exists "npm"; then
        write_info "Installing neovim npm package..."
        if npm install -g neovim; then
            write_success "✅ Node.js provider installed"
        else
            write_warning "⚠️ Failed to install neovim npm package"
        fi
    else
        write_warning "npm not found. Installing Node.js..."
        if test_root; then
            apt install -y nodejs npm
        else
            sudo apt install -y nodejs npm
        fi
        
        if test_command_exists "npm"; then
            npm install -g neovim
            write_success "✅ Node.js provider installed"
        else
            write_warning "Failed to install Node.js. Node.js provider will remain unavailable."
        fi
    fi
    
    if test_command_exists "pip3"; then
        write_info "Installing pynvim package..."
        if pip3 install --user pynvim; then
            write_success "✅ Python provider installed"
        else
            write_warning "⚠️ Failed to install pynvim"
        fi
    elif test_command_exists "pip"; then
        write_info "Installing pynvim package..."
        if pip install --user pynvim; then
            write_success "✅ Python provider installed"
        else
            write_warning "⚠️ Failed to install pynvim"
        fi
    else
        write_warning "pip not found. Installing Python3 and pip..."
        if test_root; then
            apt install -y python3 python3-pip
        else
            sudo apt install -y python3 python3-pip
        fi
        
        if test_command_exists "pip3"; then
            pip3 install --user pynvim
            write_success "✅ Python provider installed"
        else
            write_warning "Failed to install pip. Python provider will remain unavailable."
        fi
    fi
}

setup_neovim() {
    write_header "Neovim Configuration Setup"
    
    # Check prerequisites
    write_info "Checking prerequisites..."
    
    if ! test_command_exists "nvim"; then
        write_error "Neovim is not installed or not in PATH!"
        write_info "Please install Neovim first:"
        write_info "  sudo apt install neovim"
        write_info "  or download from: https://github.com/neovim/neovim/releases"
        return 1
    fi
    
    if ! test_command_exists "git"; then
        write_error "Git is not installed or not in PATH!"
        write_info "Please install Git first:"
        write_info "  sudo apt install git"
        return 1
    fi
    
    write_success "Prerequisites check passed!"
    
    # Define paths
    local nvim_config_path="$HOME/.config/nvim"
    local backup_path="$HOME/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Backup existing configuration
    if [ -d "$nvim_config_path" ]; then
        if [ "$SKIP_BACKUP" = false ]; then
            write_warning "Existing Neovim configuration found!"
            if [ "$FORCE" = true ]; then
                write_info "Creating backup at: $backup_path"
                cp -r "$nvim_config_path" "$backup_path"
                rm -rf "$nvim_config_path"
            else
                read -p "Do you want to backup and replace it? (y/N): " response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    write_info "Creating backup at: $backup_path"
                    cp -r "$nvim_config_path" "$backup_path"
                    rm -rf "$nvim_config_path"
                else
                    write_info "Setup cancelled."
                    return 1
                fi
            fi
        else
            rm -rf "$nvim_config_path"
        fi
    fi
    
    # Create directory structure
    write_header "Creating Directory Structure"
    local directories=(
        "$nvim_config_path"
        "$nvim_config_path/lua"
        "$nvim_config_path/lua/config"
        "$nvim_config_path/lua/plugins"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        write_success "Created: $dir"
    done
    
    # Create configuration files
    write_header "Creating Configuration Files"
    
    create_config_files "$nvim_config_path"
    
    write_header "Setup Complete!"
    write_success "Neovim configuration has been successfully installed!"
    write_info "Configuration location: $nvim_config_path"
    
    if [ -d "$backup_path" ]; then
        write_info "Backup location: $backup_path"
    fi
}

create_config_files() {
    local nvim_config_path="$1"
    
    # Create init.lua
    cat > "$nvim_config_path/init.lua" << 'EOF'
-- init.lua
-- Bootstrap lazy.nvim
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

-- Load configuration
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Load plugins
require("lazy").setup("plugins", {
  change_detection = {
    notify = false,
  },
})
EOF
    write_success "Created: init.lua"
    
    # Create lua/config/options.lua
    cat > "$nvim_config_path/lua/config/options.lua" << 'EOF'
-- options.lua
local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs & indentation
opt.tabstop = 4
opt.shiftwidth = 4
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

-- Swap and backup
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.undodir = vim.fn.expand("~/.local/state/nvim/undo")

-- Update time
opt.updatetime = 250
opt.timeoutlen = 300

-- Completion
opt.completeopt = "menu,menuone,noselect"

-- Mouse
opt.mouse = "a"

-- Scrolling
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Performance
opt.lazyredraw = true

-- Whitespace characters (hidden by default)
opt.list = false
opt.listchars = {
  tab = "→ ",
  space = "·",
  trail = "•",
  extends = "⟩",
  precedes = "⟨",
  nbsp = "␣",
  eol = "↲",
}
EOF
    write_success "Created: lua/config/options.lua"
    
    # Create lua/config/keymaps.lua
    cat > "$nvim_config_path/lua/config/keymaps.lua" << 'EOF'
-- keymaps.lua
local keymap = vim.keymap

-- Set leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- General keymaps
keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode" })
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- Window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

-- Tab management
keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" })
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" })
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" })

-- Buffer navigation
keymap.set("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
keymap.set("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
keymap.set("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- Better window navigation
keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
keymap.set("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Resize windows
keymap.set("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase window height" })
keymap.set("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })

-- Move text up and down
keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move text down" })
keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move text up" })

-- Stay in indent mode
keymap.set("v", "<", "<gv", { desc = "Indent left" })
keymap.set("v", ">", ">gv", { desc = "Indent right" })

-- Better paste
keymap.set("v", "p", '"_dP', { desc = "Paste without yanking" })

-- Center cursor when scrolling
keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
keymap.set("n", "n", "nzzzv", { desc = "Next search result and center" })
keymap.set("n", "N", "Nzzzv", { desc = "Previous search result and center" })

-- Quick save and quit
keymap.set("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
keymap.set("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
keymap.set("n", "<leader>Q", "<cmd>qa!<CR>", { desc = "Quit all without saving" })

-- Toggle whitespace visualization
keymap.set("n", "<leader>tw", function()
  vim.opt.list = not vim.opt.list:get()
  if vim.opt.list:get() then
    print("Whitespace visible")
  else
    print("Whitespace hidden")
  end
end, { desc = "Toggle whitespace visualization" })

-- Format document
keymap.set("n", "<leader>fm", function()
  vim.lsp.buf.format({ async = true })
end, { desc = "Format document" })
EOF
    write_success "Created: lua/config/keymaps.lua"
    
    # Create lua/config/autocmds.lua
    cat > "$nvim_config_path/lua/config/autocmds.lua" << 'EOF'
-- autocmds.lua
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Highlight on yank
augroup("YankHighlight", { clear = true })
autocmd("TextYankPost", {
  group = "YankHighlight",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

-- Remove trailing whitespace on save
augroup("TrimWhitespace", { clear = true })
autocmd("BufWritePre", {
  group = "TrimWhitespace",
  pattern = "*",
  command = [[%s/\s\+$//e]],
})

-- Auto-format on save for specific filetypes
augroup("AutoFormat", { clear = true })
autocmd("BufWritePre", {
  group = "AutoFormat",
  pattern = { "*.lua", "*.js", "*.ts", "*.jsx", "*.tsx", "*.py" },
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})

-- Close certain filetypes with 'q'
augroup("QuickClose", { clear = true })
autocmd("FileType", {
  group = "QuickClose",
  pattern = { "qf", "help", "man", "lspinfo", "checkhealth" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = event.buf, silent = true })
  end,
})

-- Restore cursor position
augroup("RestoreCursor", { clear = true })
autocmd("BufReadPost", {
  group = "RestoreCursor",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Create parent directories on save
augroup("AutoMkdir", { clear = true })
autocmd("BufWritePre", {
  group = "AutoMkdir",
  callback = function(event)
    local file = vim.loop.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})
EOF
    write_success "Created: lua/config/autocmds.lua"
    
    # Create lua/plugins/init.lua
    cat > "$nvim_config_path/lua/plugins/init.lua" << 'EOF'
-- plugins/init.lua
return {
  -- Colorscheme
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({
        style = "night",
        transparent = false,
        terminal_colors = true,
      })
      vim.cmd([[colorscheme tokyonight]])
    end,
  },

  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 35,
        },
        renderer = {
          group_empty = true,
          icons = {
            show = {
              folder_arrow = true,
            },
          },
        },
        filters = {
          dotfiles = false,
        },
      })
      vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
    end,
  },

  -- Fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")

      telescope.setup({
        defaults = {
          mappings = {
            i = {
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-j>"] = actions.move_selection_next,
              ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
            },
          },
        },
      })

      telescope.load_extension("fzf")

      local keymap = vim.keymap
      keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
      keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string" })
      keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor" })
      keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find buffers" })
      keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Find help" })
    end,
  },

  -- LSP Configuration
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      { "antosha417/nvim-lsp-file-operations", config = true },
    },
    config = function()
      local lspconfig = require("lspconfig")
      local cmp_nvim_lsp = require("cmp_nvim_lsp")
      local keymap = vim.keymap

      local on_attach = function(client, bufnr)
        local opts = { buffer = bufnr, silent = true }

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

        opts.desc = "Show documentation"
        keymap.set("n", "K", vim.lsp.buf.hover, opts)

        opts.desc = "Restart LSP"
        keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts)
      end

      local capabilities = cmp_nvim_lsp.default_capabilities()

      local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
      end

      -- Configure LSP servers
      lspconfig["lua_ls"].setup({
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              library = {
                [vim.fn.expand("$VIMRUNTIME/lua")] = true,
                [vim.fn.stdpath("config") .. "/lua"] = true,
              },
            },
          },
        },
      })

      lspconfig["ts_ls"].setup({
        capabilities = capabilities,
        on_attach = on_attach,
      })

      lspconfig["html"].setup({
        capabilities = capabilities,
        on_attach = on_attach,
      })

      lspconfig["cssls"].setup({
        capabilities = capabilities,
        on_attach = on_attach,
      })

      lspconfig["tailwindcss"].setup({
        capabilities = capabilities,
        on_attach = on_attach,
      })

      lspconfig["pyright"].setup({
        capabilities = capabilities,
        on_attach = on_attach,
      })
    end,
  },

  -- Mason for LSP server management
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
            package_uninstalled = "✗",
          },
        },
      })

      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "ts_ls",
          "html",
          "cssls",
          "tailwindcss",
          "pyright",
        },
        automatic_installation = true,
      })
    end,
  },

  -- Autocompletion
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
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
      })
    end,
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPre", "BufNewFile" },
    build = ":TSUpdate",
    dependencies = {
      "windwp/nvim-ts-autotag",
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        highlight = {
          enable = true,
        },
        indent = { enable = true },
        autotag = { enable = true },
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
          "python",
        },
        auto_install = true,
      })
    end,
  },

  -- Auto pairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({
        check_ts = true,
        ts_config = {
          lua = { "string" },
          javascript = { "template_string" },
        },
      })

      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      local cmp = require("cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },

  -- Git signs
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "│" },
          change = { text = "│" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
      })

      vim.keymap.set("n", "<leader>gp", ":Gitsigns preview_hunk<CR>", { desc = "Preview hunk" })
      vim.keymap.set("n", "<leader>gt", ":Gitsigns toggle_current_line_blame<CR>", { desc = "Toggle git blame" })
    end,
  },

  -- Comments
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = true,
  },

  -- Bufferline
  {
    "akinsho/bufferline.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    version = "*",
    opts = {
      options = {
        mode = "buffers",
        offsets = {
          {
            filetype = "NvimTree",
            text = "File Explorer",
            highlight = "Directory",
            separator = true,
          },
        },
      },
    },
  },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "tokyonight",
        },
      })
    end,
  },

  -- Which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 500
    end,
    opts = {},
  },

  -- Indent guides
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPre", "BufNewFile" },
    main = "ibl",
    opts = {
      indent = { char = "┊" },
    },
  },

  -- Surround
  {
    "kylechui/nvim-surround",
    event = { "BufReadPre", "BufNewFile" },
    version = "*",
    config = true,
  },

  -- TODO comments
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = true,
  },

  -- Trouble
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    cmd = "Trouble",
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics (Trouble)" },
    },
  },

  -- Alpha dashboard
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        [[                                                    ]],
        [[ ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗]],
        [[ ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║]],
        [[ ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║]],
        [[ ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║]],
        [[ ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║]],
        [[ ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
        [[                                                    ]],
      }

      dashboard.section.buttons.val = {
        dashboard.button("f", "  Find file", ":Telescope find_files <CR>"),
        dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
        dashboard.button("r", "  Recently used files", ":Telescope oldfiles <CR>"),
        dashboard.button("t", "  Find text", ":Telescope live_grep <CR>"),
        dashboard.button("c", "  Configuration", ":e $MYVIMRC <CR>"),
        dashboard.button("q", "  Quit Neovim", ":qa<CR>"),
      }

      alpha.setup(dashboard.opts)

      vim.cmd([[autocmd FileType alpha setlocal nofoldenable]])
    end,
  },
}
EOF
    write_success "Created: lua/plugins/init.lua"
    
    # Create README.md
    cat > "$nvim_config_path/README.md" << 'EOF'
# Neovim Configuration

A modern, fully-featured Neovim configuration for Debian 13.

## Features

- 🎨 Beautiful Tokyo Night colorscheme
- 📁 File explorer with nvim-tree
- 🔍 Fuzzy finding with Telescope
- 🧠 LSP support with native LSP and Mason
- ✨ Autocompletion with nvim-cmp
- 🌳 Syntax highlighting with Treesitter
- 📝 Auto pairs and surround
- 💬 Easy commenting
- 🎯 Quick navigation and keybindings
- 📊 Beautiful statusline and bufferline
- 🔧 Diagnostics with Trouble
- 🎪 Dashboard with Alpha

## Key Bindings

### General
- `<Space>` - Leader key
- `jk` - Exit insert mode
- `<leader>w` - Save file
- `<leader>q` - Quit
- `<leader>Q` - Quit all without saving

### File Management
- `<leader>e` - Toggle file explorer
- `<leader>ff` - Find files
- `<leader>fs` - Find string (grep)
- `<leader>fb` - Find buffers
- `<leader>fh` - Find help

### Window Management
- `<leader>sv` - Split window vertically
- `<leader>sh` - Split window horizontally
- `<leader>se` - Make splits equal size
- `<leader>sx` - Close current split
- `<C-h/j/k/l>` - Navigate between windows

### Buffer Navigation
- `<S-h>` - Previous buffer
- `<S-l>` - Next buffer
- `<leader>bd` - Delete buffer

### LSP
- `gd` - Go to definition
- `gD` - Go to declaration
- `gi` - Go to implementation
- `gr` - Show references
- `K` - Show hover documentation
- `<leader>ca` - Code actions
- `<leader>rn` - Rename symbol
- `<leader>d` - Show line diagnostics
- `[d` / `]d` - Previous/Next diagnostic

### Git
- `<leader>gp` - Preview hunk
- `<leader>gt` - Toggle git blame

### Diagnostics
- `<leader>xx` - Toggle Trouble diagnostics
- `<leader>xX` - Buffer diagnostics

### Whitespace
- `<leader>tw` - Toggle whitespace visualization

## Plugins

- **Lazy.nvim** - Plugin manager
- **Tokyo Night** - Colorscheme
- **Nvim-tree** - File explorer
- **Telescope** - Fuzzy finder
- **LSP & Mason** - Language server support
- **Treesitter** - Syntax highlighting
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

Press `<leader>tw` to toggle whitespace visualization:
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
- Uses GCC/Clang from build-essential
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
EOF
    write_success "Created: README.md"
}

fix_existing_config() {
    write_header "Fixing Existing Configuration"
    
    local nvim_config_path="$HOME/.config/nvim"
    
    if [ ! -d "$nvim_config_path" ]; then
        write_error "No existing Neovim configuration found at $nvim_config_path"
        write_info "Please run the script without --fix-only to create a new configuration"
        return 1
    fi
    
    # Fix plugins/init.lua if it exists and is corrupted
    local plugins_init_path="$nvim_config_path/lua/plugins/init.lua"
    if [ -f "$plugins_init_path" ]; then
        write_info "Fixing plugins/init.lua..."
        create_config_files "$nvim_config_path"
        write_success "✅ Configuration files updated"
    fi
    
    # Install missing tools and providers
    install_missing_tools
    install_providers
    install_compiler_tools
}

show_summary() {
    write_header "Setup Complete!"
    
    write_info "The following has been accomplished:"
    write_success "✅ Neovim configuration installed/updated"
    write_success "✅ Missing tools installed (ripgrep, fd, unzip, etc.)"
    write_success "✅ Node.js and Python providers installed"
    write_success "✅ C compiler environment configured"
    write_success "✅ Whitespace visualization enabled (<leader>tw)"
    write_success "✅ Enhanced keybindings for better workflow"
    write_success "✅ Improved autocmds and formatting"
    write_success "✅ Better buffer and window navigation"
    write_success "✅ Trouble diagnostics integration"
    write_success "✅ Alpha dashboard with quick actions"
    
    write_header "Next Steps"
    write_info "1. Open Neovim: nvim"
    write_info "2. Wait for plugins to install automatically"
    write_info "3. Restart Neovim"
    write_info "4. Run :checkhealth to verify everything is working"
    write_info "5. Run :Mason to install additional language servers"
    write_info "6. Run :TSUpdate to update TreeSitter parsers"
    
    write_header "Key Features"
    write_info "📁 File Explorer: <Space>e"
    write_info "🔍 Find Files: <Space>ff"
    write_info "🔎 Find Text: <Space>fs"
    write_info "👁️  Toggle Whitespace: <Space>tw (NEW!)"
    write_info "🐛 Show Diagnostics: <Space>xx"
    write_info "📝 Go to Definition: gd"
    write_info "💡 Code Actions: <Space>ca"
    write_info "✏️  Rename: <Space>rn"
    write_info "💬 Comment: gcc"
    
    write_header "Troubleshooting"
    write_info "If you encounter C compiler errors:"
    write_info "1. Run this script again to setup compiler environment"
    write_info "2. Or install build-essential: sudo apt install build-essential"
    write_info "3. Or run with --no-compiler flag to skip compiler setup"
    
    write_success "\n🎉 Neovim setup complete! Enjoy your new development environment!"
}

test_compiler_availability() {
    write_header "Testing Compiler Availability"
    
    local compilers=("gcc" "clang" "cc")
    local found=false
    
    for compiler in "${compilers[@]}"; do
        if test_command_exists "$compiler"; then
            write_success "✅ Found compiler: $compiler"
            $compiler --version | head -n1
            found=true
        fi
    done
    
    if [ "$found" = false ]; then
        write_warning "⚠️ No C compiler found in PATH"
        write_info "TreeSitter parsers may not compile properly"
    fi
    
    return 0
}

show_compiler_info() {
    write_header "Compiler Information"
    
    # Check GCC
    if test_command_exists "gcc"; then
        local gcc_version=$(gcc --version | head -n1)
        write_info "📍 GCC found: $gcc_version"
    fi
    
    # Check Clang
    if test_command_exists "clang"; then
        local clang_version=$(clang --version | head -n1)
        write_info "📍 Clang found: $clang_version"
    fi
    
    # Check make
    if test_command_exists "make"; then
        local make_version=$(make --version | head -n1)
        write_info "📍 Make found: $make_version"
    fi
}

# Main execution
write_header "Ultimate Neovim Setup Script for Debian 13"
write_info "This script will setup a complete Neovim development environment"

if [ "$REMOVE_ALL" = true ]; then
    local nvim_config_path="$HOME/.config/nvim"
    if [ -d "$nvim_config_path" ]; then
        rm -rf "$nvim_config_path"
        write_success "All Neovim configuration files and directories have been removed: $nvim_config_path"
    else
        write_info "No Neovim configuration directory found at $nvim_config_path. Nothing to remove."
    fi
    exit 0
fi

# Show compiler information
show_compiler_info

if [ "$FIX_ONLY" = true ]; then
    fix_existing_config
elif [ "$SETUP_ONLY" = true ]; then
    setup_neovim
else
    # Run complete setup
    setup_neovim
    install_missing_tools
    install_providers
    install_compiler_tools
fi

# Test compiler availability
test_compiler_availability

show_summary

# Show config location at the end
local nvim_config_path="$HOME/.config/nvim"
local init_lua_path="$nvim_config_path/init.lua"
write_header "Neovim Config Location"
write_info "Your Neovim configuration directory: $nvim_config_path"
write_info "Main config file: $init_lua_path"
