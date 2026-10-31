local global_node_modules = vim.fn.trim(vim.fn.system("npm root -g"))
local ng_path = global_node_modules .. "/@angular/language-server"

return {
  cmd = {
    "ngserver",
    "--stdio",
    "--tsProbeLocations",
    ng_path,
    "--ngProbeLocations",
    ng_path,
  },
  filetypes = { "htmlangular", "typescript", "html" },
  root_markers = { "angular.json", "nx.json", ".git" },
}

