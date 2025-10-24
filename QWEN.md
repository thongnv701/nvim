# Neovim Configuration Context

This document provides context for the Neovim configuration located in `C:\Users\ADMIN\OneDrive\nvim\`. This is a Lua-based Neovim configuration optimized for development in Python, Java, C#, and Rust.

## Project Structure

```
C:\Users\ADMIN\OneDrive\nvim\
├───.gitignore
├───init.lua
├───lazy-lock.json
├───.git\...
├───JavaTest\ (contains a sample Java project with pom.xml)
└───lua\
    ├───configurations\
    │   ├───keymaps.lua (key mappings configuration)
    │   ├───lazy.lua (lazy.nvim plugin manager configuration)
    │   ├───options.lua (Neovim options/settings)
    │   ├───plugins.lua (plugins configuration)
    │   └───debug\ (debugging configuration folder)
    └───plugins\
        ├───auto-pairs.lua (auto pairs plugin configuration)
        ├───blamer.lua (git blame plugin configuration)
        ├───bufferline.lua (buffer line UI plugin configuration)
        └───... (additional language-specific and utility plugins)
```

## Key Components

### init.lua
This is the main entry point for the Neovim configuration. It likely sources files from the `lua/configurations` directory.

### Lua Configurations
- `keymaps.lua`: Contains key mappings for various functions
- `lazy.lua`: Sets up the lazy.nvim plugin manager
- `options.lua`: Defines core Neovim options and settings
- `plugins.lua`: Main plugins configuration file

### Lua Plugins
- `auto-pairs.lua`: Automatic insertion of matching pairs (parentheses, brackets, quotes)
- `blamer.lua`: Git blame information display
- `bufferline.lua`: Tab/buffer visualization and management

## Language Support Focus

### Python
- LSP Configuration: Ensure python-lsp-server (pylsp) or similar is used
- Formatter: black, isort, or autopep8
- Linter: flake8, pylint, or ruff
- Testing: pytest support

### Java
- LSP Configuration: eclipse.jdt.ls or similar Java LSP
- Build Tool: Maven/Gradle integration
- Testing: JUnit support
- Note: The JavaTest directory contains a pom.xml suggesting Java development setup

### C#
- LSP Configuration: omnisharp or csharp-ls
- Framework: Support for .NET Framework and .NET Core
- Testing: NUnit, xUnit, or MSTest integration

### Rust
- LSP Configuration: rust-analyzer
- Build System: Cargo integration
- Formatter: rustfmt
- Linter: clippy

## Plugin Categories

### LSP (Language Server Protocol)
LSP servers for each language should be configured:
- Python: pylsp or pyright
- Java: jdtls
- C#: omnisharp or csharp-ls
- Rust: rust-analyzer

### Completion
- nvim-cmp: Main completion engine
- LSP-based completion for each language
- Snippet support (LuaSnip, etc.)

### Treesitter
Syntax highlighting and parsing for each language:
- Python: treesitter parser
- Java: treesitter parser
- C#: treesitter parser
- Rust: treesitter parser

### Debugging (DAP - Debug Adapter Protocol)
Debug support for each language:
- Python: debugpy
- Java: java-debug
- C#: mock debug adapter or omnisharp's DAP
- Rust: CodeLLDB

### Git Integration
- Gitsigns: Git signs in the sign column
- Lazygit: Git UI
- Blamer: Inline git blame

### UI/UX
- Bufferline: Tab/buffer management
- NerdTree/Neo-tree: File explorer
- Telescope: Fuzzy finder
- Lualine: Status line
- Noice: Improved UI notifications
- Which-key: Key binding hints

### Formatting
- Null-ls: Additional formatters and linters
- Auto-formatting on save
- Format-on-exit capabilities

### Project Management
- Project.nvim or similar: Project switching and management
- Session management
- Working directory management

## Important Notes for AI Assistance

When modifying this configuration:

1. **Plugin Management**: New plugins should be added to `lua/configurations/plugins.lua` and configured in the `lua/plugins/` directory with corresponding files.

2. **LSP Configuration**: Each language's LSP server configuration should be added to ensure proper language support.

3. **Treesitter Parsers**: Ensure treesitter parsers for Python, Java, C#, and Rust are installed and configured.

4. **Key Mappings**: Add language-specific key mappings to `lua/configurations/keymaps.lua`.

5. **Lazy-lock.json**: This file contains plugin versions managed by lazy.nvim. Changes to plugins may require updating this file.

6. **Language Server Installation**: Remember that LSP servers need to be installed separately and may require system dependencies.

7. **Filetype Detection**: Ensure proper filetype detection for all target languages.

8. **Performance**: With multiple language servers, consider lazy loading and optimization for startup time.

This configuration follows modern Neovim conventions using primarily Lua (not legacy Vimscript) and leverages the power of treesitter, LSP, and DAP for a modern IDE-like experience.