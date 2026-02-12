-- make all files with yaml extension helm
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = { "*.yaml", "*.yml" },
	callback = function()
		vim.bo.filetype = "helm"
	end,
})
