return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        yamlls = {
          settings = {
            yaml = {
              schemas = {
                ["https://circleci.com/schema/config.json"] = ".circleci/config.yml",
              },
            },
          },
        },
      },
    },
  },
}
