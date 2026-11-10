--!strict
-- `lune run icons`: renders the UI icons and sprites (assets/ui/icons, assets/ui/sprites) and the
-- effect textures (assets/fx), all white SVG, to PNG in build/icons with headless Chrome, the same
-- renderer as the HTML mockups.
-- `lune run icons serve`: serves build/icons on localhost so Studio can upload the PNGs
-- (Studio MCP upload_image); the asset ids then go into src/client/UI/Icons.luau.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local Paths = require("./lib/Paths")
local Shell = require("./lib/Shell")

local OUT_DIR = `{Paths.BUILD_DIR}/icons`
local SOURCES = {
	-- Icons get a soft glow of their own colour (it is tinted with the icon in game).
	{ dir = "assets/ui/icons", glow = true },
	{ dir = "assets/ui/sprites", glow = false },
	-- Particle and beam textures for the aliens' effects: white, tinted by the emitter in game.
	{ dir = "assets/fx", glow = false },
}
local SIZE = 256
-- Images drawn bigger, by name: what covers a large area in the world (the rune under a big pet).
local SIZES: { [string]: number } = { rune = 1024, dustsheet = 1024, starsheet = 1024 }
local GLOW = "drop-shadow(0 0 7px rgba(255, 255, 255, 0.45))"
local PORT = 8790
local DEFAULT_CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe"

local function absolute(path: string): string
	local slashed = string.gsub(`{process.cwd}/{path}`, "\\", "/")
	return slashed
end

local function render(): boolean
	local chrome = process.env.CHROME or DEFAULT_CHROME
	if not fs.isFile(chrome) then
		Shell.fail(`Chrome not found at {chrome}; set CHROME to its path.`)
		return false
	end
	if not fs.isDir(OUT_DIR) then
		fs.writeDir(OUT_DIR)
	end
	local count = 0
	for _, source in SOURCES do
		for _, file in fs.readDir(source.dir) do
			local name = string.match(file, "^(.+)%.svg$")
			if name then
				local page = `{OUT_DIR}/{name}.html`
				local filter = if source.glow then `filter: {GLOW};` else ""
				local size = SIZES[name] or SIZE
				fs.writeFile(
					page,
					`<!DOCTYPE html><html><body style="margin:0;background:transparent">`
						.. `<img src="file:///{absolute(source.dir)}/{file}" style="display:block;width:{size}px;height:{size}px;{filter}">`
						.. `</body></html>`
				)
				local result = process.exec(chrome, {
					"--headless=new",
					"--disable-gpu",
					"--hide-scrollbars",
					"--allow-file-access-from-files",
					"--default-background-color=00000000",
					`--window-size={size},{size}`,
					`--screenshot={absolute(OUT_DIR)}/{name}.png`,
					`file:///{absolute(page)}`,
				})
				fs.removeFile(page)
				if not result.ok then
					Shell.fail(`Chrome failed on {file}: {result.stderr}`)
					return false
				end
				count += 1
			end
		end
	end
	Shell.success(`Rendered {count} images to {OUT_DIR}`)
	return true
end

local function serve()
	net.serve(PORT, function(request)
		local name = string.match(request.path, "^/([%w_%-]+%.png)$")
		local path = if name then `{OUT_DIR}/{name}` else nil
		if not path or not fs.isFile(path) then
			return { status = 404, body = "not found" }
		end
		return { status = 200, headers = { ["Content-Type"] = "image/png" }, body = fs.readFile(path) }
	end)
	print(`Serving {OUT_DIR} on http://localhost:{PORT}/<name>.png (Ctrl+C to stop)`)
end

if process.args[1] == "serve" then
	serve()
else
	Shell.runSteps("Icons", { { name = "Render icons (Chrome)", run = render } })
end
