## Neovim Config + Java Sample Project

This repository contains a Neovim configuration powered by lazy.nvim and a small Java Maven project (`JavaTest`) for validating Java LSP, completion, formatting, and debugging.

### Prerequisites
- Neovim 0.9+
- Git
- A recent C/C++ toolchain (for Treesitter compilers)
- Java JDK 17 or 21 (configured in `ftplugin/java.lua`), and `JAVA_HOME` set
- Node.js (recommended for some LSPs)

### Layout
- `init.lua`: Entry point; bootstraps lazy.nvim and loads options/keymaps/plugins.
- `lua/configurations/`
  - `options.lua`: Sensible defaults (line numbers, tab/shiftwidth=4, clipboard, etc.).
  - `keymaps.lua`: Leader is space; includes buffer/window, diagnostics, language-specific maps (Rust/Java).
  - `plugins.lua`: Discovers plugin specs in `lua/plugins/*.lua`.
  - `debug/*.lua`: DAP setups for .NET, Rust, Python, Java plus shared defaults.
- `lua/plugins/`
  - `language-server-protocol.lua`: Starts non-Java LSPs per filetype with shared mappings and diagnostics UI.
  - `mason.lua` + `mason-lspconfig.lua`: Installer and LSP bridge; ensures `lua_ls`, `clangd`, `rust_analyzer`, `ts_ls`, and Java tooling (`jdtls`, `java-debug-adapter`, `java-test`, `codelldb`).
  - `treesitter.lua`: Parsers for Lua, C/C++, C#, Rust, Java, Markdown, Bash, YAML, XML, Vim; large-file safety and Windows-friendly excludes.
  - `completion.lua`: nvim-cmp with LSP, buffer, path, cmdline sources and LuaSnip.
  - `debug-adapter-protocol.lua`: nvim-dap + dap-ui with base keymaps and language adapters.
  - Other UI/dev plugins: bufferline, lualine, neo-tree, telescope, toggleterm, neogit, git blame, colors, copilot, formatter, lsp-progress, etc.
- `ftplugin/java.lua`: Dedicated jdtls launcher with Windows-aware paths, Mason discovery, Lombok, inlay hints, format settings, test/debug bundles, and rich Java keymaps.
- `JavaTest/`: Minimal Maven project to try LSP/test/debug.

### Installation
1) Clone or copy this config into your Neovim config directory on Windows:
```bash
%USERPROFILE%\AppData\Local\nvim
```
2) Open Neovim. lazy.nvim will bootstrap and install plugins.
3) Mason will auto-install required Java tools on first run (jdtls, java-debug-adapter, java-test, codelldb). You can also open `:Mason` to inspect/install.

### Key Features
- LSP with shared capabilities and keymaps: `gd`, `gi`, `gr`, `K`, `<leader>ca`, `<leader>rn`, `<leader>f`, `<leader>fd`.
- Diagnostics: virtual text, signs, `<leader>fd` float, next/prev via `<leader>ne` and `<leader>pe`; errors only via `<leader>e`/`<leader>p`.
- Completion: nvim-cmp with snippets; confirm on Enter.
- Treesitter: highlighting, indentation; guards for large files.
- DAP: dap-ui layouts, breakpoints, stepping, REPL.

### Java specifics
- jdtls starts only for Java buffers (handled in `ftplugin/java.lua`). Root is derived from Maven/Gradle markers or `.git`.
- Mason-resolved launcher, Lombok, and Java debug/test bundles are wired automatically.
- Runtime configuration includes JavaSE-17 and JavaSE-21 (21 default). Adjust in `ftplugin/java.lua` if needed.
- Useful Java mappings inside Java buffers:
  - `<leader>co`: Organize imports
  - `<leader>crv`: Extract variable (normal/visual)
  - `<leader>crc`: Extract constant (normal/visual)
  - `<leader>crm`: Extract method (visual)
  - General LSP maps (see above) also apply

### Debugging (DAP)
- Base keys:
  - `<leader><F5>`: Continue
  - `<F10>/<F11>/<F12>`: Step over/into/out
  - `<leader>b`: Toggle breakpoint
  - `<leader>B`: Conditional breakpoint
  - `<leader>dr`: Open REPL
  - `<leader>dl`: Run last
  - `<leader>dt`: Toggle UI

### JavaTest project
Location: `JavaTest/` with `pom.xml`, `src/main/java/com/example/Main.java`, and `src/test/java/com/example/CalculatorTest.java`.

Run with Maven:
```bash
cd JavaTest
mvn -q clean package
mvn -q test
```

Launch and test inside Neovim:
1) Open any file under `JavaTest` (e.g., `Main.java`). jdtls will start and attach.
2) Use LSP features: hover `K`, jump `gd`, format `<leader>f`, rename `<leader>rn`.
3) Set a breakpoint with `<leader>b`, start debug with `<leader><F5>`.

### Rust/Java helpers
- Rust (on `FileType=rust`): quick mappings for `cargo check/build/run/test` and a lightweight comment toggle.
- Java: extra helpers to compile/run the current file:
  - `<leader>jc`: Compile current file with `javac`
  - `<leader>jr`: Compile then run in file directory
  - `<leader>ji`: Compile then run with redirected input (optional)
  - `<leader>jm`: Insert a `main` method snippet

### Troubleshooting
- jdtls not starting: ensure `:Mason` shows `jdtls` installed; verify `JAVA_HOME` and JDK version; check Lombok and launcher jar paths.
- Treesitter parser issues on Windows: `vimdoc` is disabled by default to avoid healthcheck errors.
- Large files: Treesitter highlighting may be disabled automatically for performance.

### Customization
- Add/adjust plugins by creating/editing files under `lua/plugins/*.lua`.
- Change options in `lua/configurations/options.lua` and keymaps in `lua/configurations/keymaps.lua`.
- Tweak LSP servers in `lua/plugins/language-server-protocol.lua` and Java in `ftplugin/java.lua`.


