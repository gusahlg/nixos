-- Last-mile user configuration runs after plugins are set up.

vim.filetype.add({
	extension = {
		env = "sh",
		tfvars = "terraform",
	},
	filename = {
		[".env"] = "sh",
		["flake.lock"] = "json",
	},
})
