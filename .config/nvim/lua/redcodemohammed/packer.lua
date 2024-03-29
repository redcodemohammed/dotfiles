vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'

    -- Telescope plugin
    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.5',
        requires = { {'nvim-lua/plenary.nvim'} }
    }

    -- Rose Pine colorscheme
    use {
        'daltonmenezes/aura-theme',
        rtp = 'packages/neovim',
        config = function()
            vim.cmd("colorscheme aura-dark") -- Or any Aura theme available
        end
    }


    -- Treesitter
    use {
        'nvim-treesitter/nvim-treesitter',
        {run = ':TSUpdate'}
    }

    -- Harpoon
    use {
        'ThePrimeagen/harpoon'
    }

    -- Undotree
    use 'mbbill/undotree'

    -- fugitive
    use 'tpope/vim-fugitive'

    -- LSP Zero
    use {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v3.x',
        requires = {
            --- Uncomment the two plugins below if you want to manage the language servers from neovim
            {'williamboman/mason.nvim'},
            {'williamboman/mason-lspconfig.nvim'},

            -- LSP Support
            {'neovim/nvim-lspconfig'},
            -- Autocompletion
            {'hrsh7th/nvim-cmp'},
            {'hrsh7th/cmp-nvim-lsp'},
            {'L3MON4D3/LuaSnip'},
        }
    }

    -- which key
    use {
        "folke/which-key.nvim",
        config = function()
            vim.o.timeout = true
            vim.o.timeoutlen = 300
            require("which-key").setup {
                -- your configuration comes here
                -- or leave it empty to use the default settings
                -- refer to the configuration section below
            }
        end
    }
end)
