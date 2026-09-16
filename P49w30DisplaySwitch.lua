-- Hammerspoon/BetterDisplay switch for the ThinkVision P49w-30.
-- Ctrl+Command+Shift+D hands the monitor's RIGHT PBP window to the other machine or takes it
-- back, and restores this machine's LEFT window when undocking knocks it off USB-C.
--
-- VCP 0x60 is 16-bit and holds one input per PBP window:
--   low byte  49 (USB-C/Thunderbolt) — left window, always this machine
--   high byte 15 (DisplayPort via the OWC hub) — right window kept by this machine
--   high byte 17 (HDMI 1)                      — right window handed to the other machine
-- The DisplayPort link stays trained after the hand-off, so macOS keeps enumerating a half it
-- can no longer show and windows strand on it. tools/pane-connect follows every write to disable
-- or re-enable that half in macOS.

local M = {}

local MODIFIERS = {"ctrl", "cmd", "shift"}
local BETTERDISPLAY = "/opt/homebrew/bin/betterdisplaycli"
-- BetterDisplay's own -connected switch is Pro-only (the trial ran out 2026-09-14); this helper
-- does the same CGS call for free. Build: swiftc -O -o tools/pane-connect tools/pane-connect.swift
local PANE_CONNECT = debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") .. "/tools/pane-connect"
local MONITOR_NAME = "P49w-30"
local MAC_INPUT_BYTE = 49 -- USB-C — this machine's LEFT pane, never toggled
local PANE_MINE_BYTE = 0x0F -- DisplayPort — right pane stays with this machine
local PANE_OTHER_BYTE = 0x11 -- HDMI 1 — right pane goes to the other machine
local HDMI1_VALUE = MAC_INPUT_BYTE + PANE_OTHER_BYTE * 256 -- 4401
local DISPLAYPORT_VALUE = MAC_INPUT_BYTE + PANE_MINE_BYTE * 256 -- 3889
local STABILITY_WAIT_SECONDS = 6
local PANE_ID_KEY = "P49w30DisplaySwitch.rightPaneID"
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

local function decodeBytes(value)
    return value % 256, math.floor(value / 256)
end

local function isValidLaptopByte(highByte)
    return highByte == PANE_MINE_BYTE or highByte == PANE_OTHER_BYTE
end

local function parseRawValue(output)
    local first = tonumber((output or ""):match("^%s*(%d+)"))
    if not first then return nil end

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
    local nextHighByte = highByte == PANE_OTHER_BYTE and PANE_MINE_BYTE or PANE_OTHER_BYTE
    return lowByte + nextHighByte * 256
end

function M.restoreMacPane(value)
    local lowByte, highByte = decodeBytes(value)
    if lowByte == MAC_INPUT_BYTE or not isValidLaptopByte(highByte) then
        return nil
    end
    local restored = MAC_INPUT_BYTE + highByte * 256
    if not KNOWN_VALUES[restored] then return nil end
    return restored
end

-- Which macOS connection state the right pane should have once `value` is live.
function M.paneConnectionState(value)
    if not value or value < 0 or value > 65535 then return nil end
    local highByte = math.floor(value / 256)
    if highByte == PANE_MINE_BYTE then return "on" end
    if highByte == PANE_OTHER_BYTE then return "off" end
    return nil
end

-- The right pane disappears from allScreens() once disconnected, so only learn its display ID
-- while both halves are enumerated; otherwise trust the cached one.
local function rightPaneID()
    local halves = {}
    for _, screen in ipairs(hs.screen.allScreens()) do
        if screen:name():find(MONITOR_NAME, 1, true) then
            halves[#halves + 1] = screen
        end
    end
    if #halves >= 2 then
        table.sort(halves, function(a, b) return a:fullFrame().x > b:fullFrame().x end)
        hs.settings.set(PANE_ID_KEY, halves[1]:id())
    end
    return hs.settings.get(PANE_ID_KEY)
end

-- Returns action ("toggle" | "restore"), nextValue, and a short description.
function M.planAction(value)
    if not value or value < 0 or value > 65535 then return nil end

    local lowByte, highByte = decodeBytes(value)
    if not isValidLaptopByte(highByte) then return nil end

    if lowByte == MAC_INPUT_BYTE then
        if not KNOWN_VALUES[value] then return nil end
        local nextValue = M.toggleValue(value)
        if not nextValue then return nil end
        local destination = nextValue == DISPLAYPORT_VALUE and "DisplayPort" or "HDMI 1"
        local owner = nextValue == DISPLAYPORT_VALUE and "this Mac" or "the other machine"
        return "toggle", nextValue, string.format("Right pane -> %s (%s)", destination, owner)
    end

    local restored = M.restoreMacPane(value)
    if not restored then return nil end
    return "restore", restored, "Left pane restored to USB-C; right pane unchanged"
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

-- Follow the DDC write: drop our half from macOS when the monitor hands it away, bring it back
-- when we take it. Never fatal — the register is already correct by this point — but the
-- callback receives a warning string so the user learns when the half was left stranded.
local function applyPaneConnection(value, callback)
    local state = M.paneConnectionState(value)
    local id = state and rightPaneID()
    if not id then
        callback(state and "Right pane display ID unknown; macOS connection unchanged.")
        return
    end
    if not hs.fs.attributes(PANE_CONNECT) then
        callback("tools/pane-connect is missing; macOS connection unchanged.")
        return
    end
    M.task = hs.task.new(PANE_CONNECT, function(exitCode, _, stdErr)
        M.task = nil
        if exitCode ~= 0 then
            callback("pane-connect failed: " .. (stdErr or ""):gsub("%s+$", ""))
        else
            callback()
        end
    end, { tostring(id), state })
    if not M.task or not M.task:start() then
        M.task = nil
        callback("pane-connect could not start.")
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
        callback(parseRawValue(output), "")
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

                local action, nextValue, successMessage = M.planAction(secondValue)
                if not action or not nextValue then
                    local lowByte, highByte = decodeBytes(secondValue)
                    finishWithError(string.format(
                        "Unsafe DDC bytes (Mac=%d, laptop=%d).",
                        lowByte,
                        highByte
                    ))
                    return
                end

                runBetterDisplay({
                    "set",
                    "-name=" .. MONITOR_NAME,
                    "-feature=ddc",
                    "-vcp=0x60",
                    "-value=" .. tostring(nextValue),
                }, function(exitCode, _, errorOutput)
                    if exitCode ~= 0 then
                        M.busy = false
                        notify("BetterDisplay write failed: " .. errorOutput)
                        return
                    end
                    applyPaneConnection(nextValue, function(warning)
                        M.busy = false
                        notify(warning and (successMessage .. " WARNING: " .. warning) or successMessage)
                    end)
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
