-- Hammerspoon/BetterDisplay switch for the ThinkVision P49w-30 laptop/right pane.
-- Ctrl+Command+Shift+D toggles the verified 16-bit VCP 0x60 values.

local M = {}

local MODIFIERS = {"ctrl", "cmd", "shift"}
local BETTERDISPLAY = "/opt/homebrew/bin/betterdisplaycli"
local MONITOR_NAME = "P49w-30"
local HDMI1_VALUE = 4401
local DISPLAYPORT_VALUE = 3889
local STABILITY_WAIT_SECONDS = 6
local KNOWN_VALUES = {
    [HDMI1_VALUE] = true,
    [DISPLAYPORT_VALUE] = true,
}

M.busy = false
M.task = nil
M.timer = nil

local function notify(message)
    hs.notify.new({ title = "P49w-30", informativeText = message }):send()
end

local function parseValue(output)
    local first = tonumber((output or ""):match("^%s*(%d+)"))
    if not first or not KNOWN_VALUES[first] then return nil end

    -- BetterDisplay may repeat the value for multiple matching display records.
    -- Every returned number must agree; mixed output is ambiguous and unsafe.
    local count = 0
    for token in (output or ""):gmatch("%d+") do
        count = count + 1
        if tonumber(token) ~= first then return nil end
    end
    return count > 0 and first or nil
end

function M.toggleValue(value)
    if not KNOWN_VALUES[value] then return nil end
    local lowByte = value % 256
    local highByte = math.floor(value / 256)
    local nextHighByte = highByte == 0x11 and 0x0F or 0x11
    return lowByte + nextHighByte * 256
end

local function runBetterDisplay(arguments, callback)
    M.task = hs.task.new(BETTERDISPLAY, function(exitCode, stdOut, stdErr)
        M.task = nil
        callback(exitCode, stdOut or "", stdErr or "")
    end, arguments)

    if not M.task or not M.task:start() then
        M.task = nil
        callback(-1, "", "BetterDisplay CLI could not start")
    end
end

local function readValue(callback)
    runBetterDisplay({
        "get",
        "-name=" .. MONITOR_NAME,
        "-feature=ddc",
        "-vcp=0x60",
        "-value",
    }, function(exitCode, output, errorOutput)
        if exitCode ~= 0 then
            callback(nil, errorOutput)
            return
        end
        callback(parseValue(output), "")
    end)
end

local function finishWithError(message)
    M.busy = false
    notify(message .. " No write was made.")
end

function M.toggle()
    if M.busy then
        notify("A display safety check is already running.")
        return
    end
    if not hs.fs.attributes(BETTERDISPLAY) then
        finishWithError("BetterDisplay CLI was not found.")
        return
    end

    M.busy = true
    readValue(function(firstValue)
        if not firstValue then
            finishWithError("Unsafe or invalid first DDC read.")
            return
        end

        M.timer = hs.timer.doAfter(STABILITY_WAIT_SECONDS, function()
            M.timer = nil
            readValue(function(secondValue)
                if not secondValue or secondValue ~= firstValue then
                    finishWithError("DDC value changed during the safety window.")
                    return
                end

                local nextValue = M.toggleValue(secondValue)
                if not nextValue then
                    finishWithError("Unexpected DDC value.")
                    return
                end

                runBetterDisplay({
                    "set",
                    "-name=" .. MONITOR_NAME,
                    "-feature=ddc",
                    "-vcp=0x60",
                    "-value=" .. tostring(nextValue),
                }, function(exitCode, _, errorOutput)
                    M.busy = false
                    if exitCode ~= 0 then
                        notify("BetterDisplay write failed: " .. errorOutput)
                        return
                    end
                    local destination = nextValue == DISPLAYPORT_VALUE and "DisplayPort" or "HDMI 1"
                    notify("Laptop pane switch requested: " .. destination)
                end)
            end)
        end)
    end)
end

if _G.P49w30DisplaySwitch and _G.P49w30DisplaySwitch.hotkey then
    _G.P49w30DisplaySwitch.hotkey:delete()
end
M.hotkey = hs.hotkey.bind(MODIFIERS, "d", M.toggle)
_G.P49w30DisplaySwitch = M

return M
