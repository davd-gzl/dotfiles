-- LunarVim Configuration
-- https://www.lunarvim.org/docs/configuration

-- General settings
lvim.log.level = "warn"
lvim.format_on_save.enabled = false
lvim.colorscheme = "lunar"

-- Required for opencode.nvim file reload on edits
vim.o.autoread = true

-- Telescope find files (preserved from original config)
vim.keymap.set("n", "<leader>f", "<Cmd>Telescope find_files<CR>", {})

-- ============================================================================
-- Additional Plugins
-- ============================================================================
lvim.plugins = {
  -- snacks.nvim: Enhanced UI primitives (recommended for opencode.nvim)
  {
    "folke/snacks.nvim",
    lazy = false,
    opts = {
      input = {},
      picker = {
        actions = {
          opencode_send = function(...)
            return require("opencode").snacks_picker_send(...)
          end,
        },
        win = {
          input = {
            keys = {
              ["<a-a>"] = { "opencode_send", mode = { "n", "i" } },
            },
          },
        },
      },
    },
  },

  -- opencode.nvim: AI assistant integration
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    dependencies = {
      { "folke/snacks.nvim", optional = true },
    },
    config = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {
        -- Add your opencode configuration here if needed
      }

      -- Keymaps
      -- <C-a>  Ask opencode with context
      -- <C-x>  Select opencode action (prompts, commands, etc.)
      -- <C-.>  Toggle opencode terminal
      -- go     Operator: add range to opencode
      -- goo    Operator: add current line to opencode
      vim.keymap.set({ "n", "x" }, "<C-a>", function()
        require("opencode").ask("@this: ", { submit = true })
      end, { desc = "Ask opencode" })

      vim.keymap.set({ "n", "x" }, "<C-x>", function()
        require("opencode").select()
      end, { desc = "Execute opencode action" })

      vim.keymap.set({ "n", "t" }, "<C-.>", function()
        require("opencode").toggle()
      end, { desc = "Toggle opencode" })

      vim.keymap.set({ "n", "x" }, "go", function()
        return require("opencode").operator("@this ")
      end, { desc = "Add range to opencode", expr = true })

      vim.keymap.set("n", "goo", function()
        return require("opencode").operator("@this ") .. "_"
      end, { desc = "Add line to opencode", expr = true })

      -- Scroll opencode messages
      vim.keymap.set("n", "<S-C-u>", function()
        require("opencode").command("session.half.page.up")
      end, { desc = "Scroll opencode up" })

      vim.keymap.set("n", "<S-C-d>", function()
        require("opencode").command("session.half.page.down")
      end, { desc = "Scroll opencode down" })

      -- Remap default <C-a>/<C-x> (increment/decrement) to +/-
      vim.keymap.set("n", "+", "<C-a>", { desc = "Increment under cursor", noremap = true })
      vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement under cursor", noremap = true })
    end,
  },
}
