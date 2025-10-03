local lsp = require('lsp-zero')

lsp.on_attach(function(client, bufnr)
    -- see :help lsp-zero-keybindings
    -- to learn the available actions
    lsp.default_keymaps({ buffer = bufnr })
end)

lsp.setup_servers({
    'ts_ls',
    'rust_analyzer',
    'eslint',
    'lua_ls',
    "volar",
    "tailwindcss",
    "jedi_language_server",
    "prismals",
    "marksman",
    "jsonls",
    "html",
    "emmet_language_server",
    "dockerls",
    "docker_compose_language_service",
    "cssls",
    "bashls",
    "jedi_language_server",
})

lsp.set_sign_icons({})

lsp.extend_cmp()

local cmp = require('cmp')
local cmp_select = { behavior = cmp.SelectBehavior.Select }
cmp.setup({
    mapping = cmp.mapping.preset.insert({
        ['<C-y>'] = cmp.mapping.complete(),
        ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
        ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
        ['<CR>'] = cmp.mapping.confirm({ select = false }),
         
    })
})

-- to learn how to use mason.nvim with lsp-zero
-- read this: https://github.com/VonHeikemen/lsp-zero.nvim/blob/v3.x/doc/md/guide/integrate-with-mason-nvim.md
require('mason').setup({})
require('mason-lspconfig').setup({
    ensure_installed = {
        'ts_ls',
        'rust_analyzer',
        'eslint',
        'lua_ls',
        "volar",
        "tailwindcss",
        "jedi_language_server",
        "prismals",
        "marksman",
        "jsonls",
        "html",
        "emmet_language_server",
        "dockerls",
        "docker_compose_language_service",
        "cssls",
        "bashls",
        "jedi_language_server",
    },
    handlers = { lsp.default_setup, },
})

-- setup for dart
require("lspconfig").dartls.setup({
    cmd = { "dart", "language-server", "--protocol=lsp" },
    filetypes = { "dart" },
    init_options = {
        closingLabels = true,
        flutterOutline = true,
        onlyAnalyzeProjectsWithOpenFiles = true,
        outline = true,
        suggestFromUnimportedLibraries = true,
    },
    -- root_dir = root_pattern("pubspec.yaml"),
    settings = {
        dart = {
            completeFunctionCalls = true,
            showTodos = true,
        },
    },
    on_attach = function(client, bufnr)
    end,
})

lsp.on_attach(function(client, bufnr)
    local opts = { buffer = bufnr, remap = false }

    vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
    vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
    vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
    vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
    vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
    vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)
    vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
    vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
    vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
    vim.keymap.set("i", "<C-i>", function() vim.lsp.buf.signature_help() end, opts)
end)


lsp.setup()
