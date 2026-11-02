--!strict
-- Small helpers shared by the project's Lune task scripts.

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Shell = {}

export type Step = {
	name: string,
	run: () -> boolean,
}

function Shell.heading(text: string)
	print(`{stdio.style("bold")}==> {text}{stdio.style("reset")}`)
end

function Shell.fail(text: string)
	stdio.ewrite(`{stdio.color("red")}{text}{stdio.color("reset")}\n`)
end

function Shell.success(text: string)
	print(`{stdio.color("green")}{text}{stdio.color("reset")}`)
end

-- Runs a program with its output forwarded to the terminal. Returns true on exit code 0.
function Shell.exec(program: string, args: { string }): boolean
	local result = process.exec(program, args, { stdio = "forward" })
	return result.ok
end

-- Runs steps in order and stops at the first failure, so the first real error is the one on screen.
function Shell.runSteps(title: string, steps: { Step })
	local started = os.clock()
	for _, step in steps do
		Shell.heading(step.name)
		if not step.run() then
			Shell.fail(`{title} failed at step: {step.name}`)
			process.exit(1)
		end
	end
	Shell.success(`{title} passed in {string.format("%.1f", os.clock() - started)}s`)
end

-- Fails early with a clear hint when `lune run install` has not been run yet.
function Shell.requireInstalled(paths: { string })
	for _, path in paths do
		if not (fs.isDir(path) or fs.isFile(path)) then
			Shell.fail(`Missing '{path}'. Run 'lune run install' first.`)
			process.exit(1)
		end
	end
end

return Shell
