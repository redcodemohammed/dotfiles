function setColor(color)
	color = color or 'catppuccin'
	vim.cmd.colorscheme(color)
	-- set the background to be transperent
	vim.api.nvim_set_hl(0, 'Normal', { bg = 'none'})
	vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'none'})
end

setColor()
