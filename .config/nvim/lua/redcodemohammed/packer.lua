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
		'rose-pine/neovim',
		as = 'rose-pine'
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
end)
