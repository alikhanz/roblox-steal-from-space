--!strict
-- Single source of truth for paths and pinned versions used by the task scripts.

local Paths = {}

-- Must match the luau-lsp version pinned in rokit.toml: definitions are fetched from the same tag.
Paths.LUAU_LSP_VERSION = "1.70.1"

Paths.PROJECT_FILE = "default.project.json"
Paths.SOURCEMAP = "sourcemap.json"
Paths.BUILD_DIR = "build"
Paths.BUILD_FILE = "build/game.rbxl"
Paths.NET_CONTRACT = "net/remotes.zap"

Paths.TYPES_DIR = "types"
Paths.ROBLOX_DEFINITIONS = "types/globalTypes.d.luau"
Paths.ROBLOX_DEFINITIONS_VERSION = "types/version.txt"

Paths.PACKAGE_DIRS = { "Packages", "ServerPackages" }

-- Code that ships in the game and is checked against Roblox types.
Paths.GAME_SOURCES = { "src" }
-- Tooling and tests that run under Lune.
Paths.TOOLING_SOURCES = { "lune", "tests" }

Paths.TESTS_DIR = "tests"
Paths.TEST_SUFFIX = ".spec.luau"

return Paths
