return {
  {
    "nvim-java/nvim-java",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      require("java").setup()

      local java_keymap = function(lhs, command, description)
        vim.keymap.set("n", lhs, "<cmd>" .. command .. "<cr>", {
          desc = description,
          silent = true,
        })
      end

      java_keymap("<leader>jr", "JavaRunnerRunMain", "Java: Run main class")
      java_keymap("<leader>js", "JavaRunnerStopMain", "Java: Stop main class")
      java_keymap("<leader>jl", "JavaRunnerToggleLogs", "Java: Toggle runner logs")
      java_keymap("<leader>jb", "JavaBuildBuildWorkspace", "Java: Build workspace")
      java_keymap("<leader>jp", "JavaProfile", "Java: Open profiles")
      java_keymap("<leader>jv", "JavaSettingsChangeRuntime", "Java: Select runtime")
      java_keymap("<leader>jm", "JavaTestRunCurrentMethod", "Java: Run test method")
      java_keymap("<leader>jM", "JavaTestDebugCurrentMethod", "Java: Debug test method")
      java_keymap("<leader>jc", "JavaTestRunCurrentClass", "Java: Run test class")
      java_keymap("<leader>jC", "JavaTestDebugCurrentClass", "Java: Debug test class")
      java_keymap("<leader>ja", "JavaTestRunAllTests", "Java: Run all tests")
      java_keymap("<leader>jA", "JavaTestDebugAllTests", "Java: Debug all tests")
      java_keymap("<leader>jo", "JavaTestViewLastReport", "Java: Open last test report")

      vim.lsp.config("jdtls", {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })
      vim.lsp.enable("jdtls")
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()

      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: Start or continue" })
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: Step over" })
      vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: Step into" })
      vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: Step out" })

      vim.keymap.set("n", "<leader>bb", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
      vim.keymap.set("n", "<leader>bB", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "Set conditional breakpoint" })
      vim.keymap.set("n", "<leader>bc", dap.continue, { desc = "Start or continue debugging" })
      vim.keymap.set("n", "<leader>bl", dap.run_last, { desc = "Run last debug session" })
      vim.keymap.set("n", "<leader>br", dap.repl.toggle, { desc = "Toggle debug REPL" })
      vim.keymap.set("n", "<leader>bt", dap.terminate, { desc = "Terminate debug session" })
      vim.keymap.set("n", "<leader>bu", dapui.toggle, { desc = "Toggle debugger UI" })
      vim.keymap.set({ "n", "v" }, "<leader>be", dapui.eval, { desc = "Evaluate expression" })
    end,
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("nvim-dap-virtual-text").setup()
    end,
  },
}
