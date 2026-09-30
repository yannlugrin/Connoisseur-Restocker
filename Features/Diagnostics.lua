local _, ns = ...

--------------------------------------------------------------------------------
-- Diagnostic Tools
--------------------------------------------------------------------------------

--[[
    Environment probing and state capture for bug reports, not unit tests. WoW's
    sandboxed Lua has no assertion runner, so everything here is read-only and
    side-effect free. The one exception is the explicit Taint Log button, which
    sets the taintLog CVar. Reports build only on a button press, never on load
    or panel open.
]]

local L = ns.L

--------------------------------------------------------------------------------
-- Runtime State
--------------------------------------------------------------------------------

--[[
    Runtime-only state. NOT a SavedVariable. File-scope init is correct here —
    the "initialize on PLAYER_LOGIN" rule applies only to SavedVariables, which
    don't exist until the client loads them. Core also initialises this table;
    the `or` keeps whichever ran first.
]]
ns.diagnostics = ns.diagnostics or { enabled = false, logging = false, log = nil }

--------------------------------------------------------------------------------
-- Strings
--------------------------------------------------------------------------------

--[[
    Diagnostics strings are intentionally NOT localized. They are
    developer-facing troubleshooting text; translating them is wasted effort for
    zero player value. Every diagnostics string lives here as plain English, in
    the diagnostics files only — never in Locales/. The one exception is the
    add-on's own display name, read from ns.L["ADDON_TITLE"], which is the add-on's
    identity, not a diagnostics string.
]]
ns.DiagnosticsStrings = {
	TAB = "Diagnostic Tools",
	WARNING = "These tools help diagnose problems and are meant for developers. While they are on, the Restock List also prints a step-by-step trace to chat during bank restocks, and their output includes technical details about your client and installed add-ons. Leave this off unless you're troubleshooting with someone.",
	ENABLE = "Enable Diagnostic Tools",
	ENABLE_DESCRIPTION = "Shows the diagnostic reports and the event log below, and turns on the Restock List's chat trace during bank restocks, until you log out or turn it off.",
	EVENT_LOG_TITLE = "Event Log",
	EVENT_LOG_START = "Start Event Log",
	EVENT_LOG_START_DESC = "Starts recording the events Connoisseur receives, replacing any earlier capture.",
	EVENT_LOG_STOP = "Stop Event Log",
	EVENT_LOG_STOP_DESC = "Stops recording and keeps what was captured.",
	EVENT_LOG_SHOW = "Show Captured Events",
	EVENT_LOG_SHOW_DESC = "Shows the captured events in the box below.",
	EVENT_LOG_HINT = "Captures the events the add-on registered for, with arguments, in the order they fired. The best tool for 'my macro didn't update' reports.",
	EVENTS_TITLE = "Event Registration",
	EVENTS_BUTTON = "Test Event Registration",
	EVENTS_BUTTON_DESC = "Checks that every event Connoisseur uses exists on this client.",
	API_TITLE = "API Endpoints",
	API_BUTTON = "Test WoW API Endpoints",
	API_BUTTON_DESC = "Checks that every game function Connoisseur uses exists on this client.",
	CONTEXT_TITLE = "Connoisseur Context",
	CONTEXT_BUTTON = "Show Connoisseur Context",
	CONTEXT_BUTTON_DESC = "Shows your character, the items Connoisseur last picked, the spells it checks and your display settings.",
	SELECTION_TITLE = "Item Selection",
	SELECTION_BUTTON = "Show Selection Report",
	SELECTION_BUTTON_DESC = "Shows what each macro picked and the ranking step that decided it.",
	READINESS_TITLE = "Readiness Report",
	READINESS_BUTTON = "Show Readiness Report",
	READINESS_BUTTON_DESC = "Shows what the Readiness Report would print right now.",
	READINESS_HINT = "Renders the Readiness Report as it would print right now, without waiting for a ready check. The tool for 'I turned a switch on and nothing happened': it tells a report that is quiet because you are ready apart from one that never ran, and lists which switches are on.",
	SELECTION_HINT = "Shows what each macro picked and which runners-up it beat, naming the ranking step that decided each one. The tool for 'why did it choose that item?' reports. Candidates are only kept while these tools are enabled, so trigger a rescan (loot something, or change zone) after turning them on.",
	ADDONS_TITLE = "Other Add-ons",
	ADDONS_BUTTON = "List Installed Add-ons",
	ADDONS_BUTTON_DESC = "Lists every installed add-on with its version and whether it is loaded.",
	SAVED_TITLE = "Saved Variables",
	SAVED_BUTTON = "Dump Saved Variables",
	SAVED_BUTTON_DESC = "Shows Connoisseur's saved settings, Restock Lists included.",
	LIBS_TITLE = "Library Versions",
	LIBS_BUTTON = "List Library Versions",
	LIBS_BUTTON_DESC = "Lists every loaded shared library and its version.",
	VALIDATE_TITLE = "Validate Data: %s/%s-%s.lua",
	VALIDATE_BUTTON = "Validate Data",
	VALIDATE_BUTTON_DESC = "Checks every id in %s/%s-%s.lua against this client and builds a report you can paste into a spreadsheet.",
	VALIDATE_PROGRESS = "Validated %s / %s IDs (batch %d of %d)...",
	TAINT_TITLE = "Taint Log",
	TAINT_STATE = "Taint logging is currently set to level %d (0 = off, 2 = verbose).",
	TAINT_ON = "Turn On Taint Log",
	TAINT_ON_DESC = "Starts writing taint details to Logs\\taint.log.",
	TAINT_OFF = "Turn Off Taint Log",
	TAINT_OFF_DESC = "Stops writing to the taint log.",
	TAINT_HINT = "Writes to Logs\\taint.log. The setting persists until turned off; reload your UI to capture taint from login onward.",
	TOOLS_TITLE = "External Tools",
	TOOLS_ERRORS = "Lua errors: install BugSack and !BugGrabber, or enable %s to surface them.",
	TOOLS_ETRACE = "Live event tracing: use %s.",
	-- The Restock List's bank trace (ns.RestockerDebug), printed while these tools are on.
	TRACE_PUT_CURSOR_ITEM = "PutCursorItem(%s) bag=%s slot=%s",
	TRACE_PUT_CURSOR_NO_SLOT = "PutCursorItem(%s) bag=%s -- no empty slot",
	TRACE_BANK_NO_ROOM = "PutItemInBank: no room to drop, clearing cursor",
	TRACE_BAG_NO_ROOM = "PutItemInPlayerBag: no room to drop, clearing cursor",
	TRACE_USE_FROM_BANK = "Use %s from bank, bag=%s, slot=%s",
	TRACE_OVERSHOOT_FROM_BANK = "Overshoot %s from bank (split not landing), bag=%s, slot=%s",
	TRACE_SPLIT_FROM_BANK = "Split %s from bank, bag=%s, slot=%s",
	TRACE_BEST_FIT_NO_STACKS = "BestFit: no existing stacks for merging %s x%s",
	TRACE_BEST_FIT_NO_CANDIDATES = "BestFit: found stacks but no candidates for merging %s x%s",
	TRACE_BEST_FIT_CANDIDATE = "BestFit: candidate for merging %s x%s is %s:%s",
	TRACE_CURSOR_FOREIGN_ITEM = "Cursor holds an item we do not maintain, waiting (%d/%d)",
	TRACE_TOO_MANY = "Too many %s in bag (%d need %d)",
	TRACE_TOO_FEW = "Too few %s in bag (%d need %d)",
	TRACE_CONSOLIDATE = "Consolidate %s: %d from %s:%s -> %s:%s",
	TRACE_TOP_OFF = "Top off %s: %d from %s:%s -> %s:%s",
	TRACE_MERCHANT_OPEN = "Merchant open -- aborting bank restock so UseContainerItem can never sell",
	TRACE_IN_TRANSIT = "%s in transit (bag+bank %d, was %d), waiting",
	TRACE_CREATE_COROUTINE = "Maintain: create coro",
	TRACE_COROUTINE_RUNNING = "Maintain: coro running",
}

--------------------------------------------------------------------------------
-- Enable Gate
--------------------------------------------------------------------------------

function ns.SetDiagnosticsEnabled(value)
	ns.diagnostics.enabled = value and true or false
	if not ns.diagnostics.enabled then
		ns.DiscardEventLog()
	end
end

--------------------------------------------------------------------------------
-- Report Header
--------------------------------------------------------------------------------

local function GetClientHeader()
	local version, build, _, tocVersion = GetBuildInfo()
	return string.format(
		"%s %s // Client %s // Build %s // TOC %s // Locale %s // Flavor %s // Data %s",
		L["ADDON_TITLE"],
		ns.Version,
		version,
		build,
		tocVersion,
		GetLocale(),
		tostring(ns.FLAVOR),
		tostring(ns.DATA_FOLDER)
	)
end

--------------------------------------------------------------------------------
-- Event Log
--------------------------------------------------------------------------------

local EVENT_LOG_SIZE = 500
local EVENT_LOG_MAX_ARGS = 8

--[[
    Per-argument byte cap. A single item link (|cff...|Hitem:...|h[Name]|h|r)
    runs past 80 bytes and a shorter cap cuts it mid-name; 255 holds a full item
    link while still bounding a runaway argument.
]]
local EVENT_LOG_MAX_ARG_LENGTH = 255

--[[
    Events the capture tap can only COUNT, never classify. They are kept out of
    the buffer and folded into the suppressed-traffic summary instead, so the
    report still proves the event fired and how often.

    UNIT_AURA is the one entry, and it is here for a narrow reason: it is a
    firehose whose signal firings cannot be told apart AT CAPTURE. ns.LogEvent
    runs from Core's dispatcher BEFORE the real handler, so at that moment
    nothing yet knows whether this particular aura change moved anything the
    add-on tracks. Its signal firings are therefore logged from the other end --
    ns.OnUnitAura (Features/Scanner-Auras.lua) calls ns.LogEventNow once
    it has decided something changed, so a stale-macro report shows the aura
    change that preceded the rebuild in full, with the rest of the traffic
    counted beneath it.

    Nothing else belongs here. An event whose firings can be classified at
    capture uses ns.MESSAGE_ID_FILTERED_EVENTS below, and an event with no
    firehose problem is simply logged. The log only sees events routed through
    Core's central dispatcher, so an event the add-on never registers can't
    appear here regardless.
]]
ns.DIAGNOSTIC_EVENT_EXCLUDE = {
	UNIT_AURA = true,
}

--------------------------------------------------------------------------------
-- Event Log Noise
--------------------------------------------------------------------------------

--[[
    UI_ERROR_MESSAGE is a firehose the add-on genuinely acts on some of the time,
    so it is never excluded wholesale: the client raises it for every red combat
    error, and against a 500-entry buffer that traffic silently evicts the
    entries the log exists to carry -- the report comes back looking complete
    while the signal has already been trimmed away.

    The value is the argument position carrying the field the filter classifies
    by. UI_ERROR_MESSAGE fires as (messageID, message); this add-on's handlers
    all correlate on the message TEXT rather than the numeric id, so position 2
    is the field the filter has to read to classify the same way they do.
]]
ns.MESSAGE_ID_FILTERED_EVENTS = {
	UI_ERROR_MESSAGE = 2,
}

--[[
    The log's allowlist: the messages this add-on actually acts on. Every entry
    is the exact global its live handler compares against -- ERR_ITEM_WRONG_ZONE
    (ns.OnMacroUiErrorMessage, Macros/Runtime.lua), SPELL_FAILED_TARGETS_DEAD
    (ns.OnHunterUiErrorMessage, Macros/Tools-Hunters.lua), and ERR_INV_FULL /
    ERR_BANK_FULL (ns.OnRestockerUiErrorMessage, Restocker/Restocker-Events.lua) -- read
    live on every call and never persisted, so the filter cannot drift from the
    handlers and start making the log lie about what fired.

    Never invert this into a denylist of noise: noise is unbounded, varies by
    class and activity, and renumbers across client patches. The allowlist is
    finite and already in the code.
]]
local function IsCorrelatedMessage(text)
	return text == ERR_ITEM_WRONG_ZONE
		or text == SPELL_FAILED_TARGETS_DEAD
		or text == ERR_INV_FULL
		or text == ERR_BANK_FULL
end

--[[
    Fold one firing into the suppressed-traffic tally, keyed by event plus the
    text that distinguishes firings worth telling apart. Shared by both routes
    into the summary: the excluded firehoses above, and the uncorrelated messages
    below.
]]
local function CountSuppressed(event, text)
	local suppressed = ns.diagnostics.suppressed
	if not suppressed then
		suppressed = {}
		ns.diagnostics.suppressed = suppressed
	end

	local key = event .. "\0" .. text
	local entry = suppressed[key]
	if entry then
		entry.count = entry.count + 1
	else
		suppressed[key] = { event = event, text = text, count = 1 }
	end
end

--[[
    Decides, per firing, whether the entry is logged in full or folded into a
    counter. Suppressed traffic aggregates per message text (first-seen text plus
    a count) and renders as one compact block at the end of the report, so the
    report still proves what fired and how often -- and a tester can spot a
    message the add-on should be correlating and isn't.
]]
function ns.SuppressUncorrelatedMessage(event, ...)
	local position = ns.MESSAGE_ID_FILTERED_EVENTS[event]
	if not position then
		return false
	end

	--[[
	    Unclassifiable is signal: a firing that doesn't carry the field we
	    classify by is exactly the unexpected shape a bug report needs to show,
	    so it is logged verbatim rather than suppressed.
	]]
	local text = select(position, ...)
	if type(text) ~= "string" then
		return false
	end

	if IsCorrelatedMessage(text) then
		return false
	end

	CountSuppressed(event, text)

	return true
end

function ns.StartEventLog()
	ns.diagnostics.log = {}
	ns.diagnostics.suppressed = {}
	ns.diagnostics.logging = true
end

--[[
    Stops capturing but KEEPS what was captured. The panel's buttons read Start,
    Stop, Show, so the obvious way to use them is start, reproduce the problem,
    stop, then read the report -- which only works if stopping keeps the buffer.

    Nothing leaks by holding it: Start replaces the buffer, and switching
    diagnostics off entirely releases it through ns.DiscardEventLog.
]]
function ns.StopEventLog()
	ns.diagnostics.logging = false
end

-- Stop and release the buffer, for when diagnostics is switched off altogether.
function ns.DiscardEventLog()
	ns.diagnostics.logging = false
	ns.diagnostics.log = nil
	ns.diagnostics.suppressed = nil
end

--[[
    Called by Core's dispatcher for every event while logging is active.
    Snapshots arguments to strings immediately — never retain references, since
    some events carry frames or tables that would leak memory or go stale. Caps
    the arg count and string length so a single entry can't run away.

    Pipes are escaped (| -> ||) AFTER the length cut so each argument shows
    verbatim in the report editbox rather than rendering as a clickable item
    swatch. Escaping last also means the cut can never leave a dangling pipe that
    would eat the following ", " separator.

    A secret argument (Forever, while the client restricts the data, e.g. a
    cast's spell ID mid-fight) is written as <secret> before any string work
    touches it: this tap runs ahead of every handler, and string work on a
    secret value can throw or hand back another secret.
]]
local function AppendLogEntry(event, ...)
	local log = ns.diagnostics.log
	if not log then
		return
	end
	local parts = {}
	for index = 1, select("#", ...) do
		if index > EVENT_LOG_MAX_ARGS then
			break
		end
		local value = (select(index, ...))
		if ns.IsSecretValue(value) then
			parts[index] = "<secret>"
		else
			local raw = string.sub(tostring(value), 1, EVENT_LOG_MAX_ARG_LENGTH)
			parts[index] = (raw:gsub("|", "||"))
		end
	end
	log[#log + 1] = string.format("%.3f %s(%s)", GetTime(), event, table.concat(parts, ", "))
	if #log > EVENT_LOG_SIZE then
		table.remove(log, 1)
	end
end

function ns.LogEvent(event, ...)
	if ns.DIAGNOSTIC_EVENT_EXCLUDE[event] then
		--[[
		    Counted, not dropped: the first argument is what distinguishes these
		    firings from each other (UNIT_AURA's unit), so it is what the tally is
		    keyed by -- "UNIT_AURA(player) x319". The handler writes the full line
		    for the firings that mattered; see ns.LogEventNow.
		]]
		local first = select("#", ...) > 0 and tostring((select(1, ...))) or ""
		CountSuppressed(event, first)
		return
	end
	--[[
	    Filtered at capture, never at render: folding the spam only at display
	    time would still let it push the add-on's own events out of the bounded
	    buffer, and the report would come back clean and empty.
	]]
	if ns.SuppressUncorrelatedMessage(event, ...) then
		return
	end
	AppendLogEntry(event, ...)
end

--[[
    Write a full log line from inside a handler, for an event ns.LogEvent can
    only count because the capture tap runs before the handler and so cannot yet
    tell signal from noise (ns.DIAGNOSTIC_EVENT_EXCLUDE).

    The classification therefore comes from the handler that already made the
    decision, never from a second copy of its logic -- which is what stops the
    log from disagreeing with the code about what the add-on acted on. Call it
    only on firings the handler actually acted on; everything else is already in
    the suppressed tally.
]]
function ns.LogEventNow(event, ...)
	if not ns.diagnostics.logging then
		return
	end
	AppendLogEntry(event, ...)
end

--[[
    The suppressed-traffic block, appended after the log itself: one line per
    folded message, biggest offender first. Pipes are escaped here for the same
    reason the log entries escape them -- so the text shows verbatim in the
    report editbox instead of rendering as an escape.
]]
local function AppendSuppressedSummary(lines)
	local suppressed = ns.diagnostics.suppressed
	if not suppressed then
		return
	end

	local rows = {}
	for _, entry in pairs(suppressed) do
		rows[#rows + 1] = entry
	end
	if #rows == 0 then
		return
	end

	table.sort(rows, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.text < b.text
	end)

	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- Suppressed (uncorrelated) traffic --"
	for _, entry in ipairs(rows) do
		lines[#lines + 1] = string.format("%s(%s) x%d", entry.event, (entry.text:gsub("|", "||")), entry.count)
	end
end

function ns.BuildEventLogReport()
	local lines = { GetClientHeader(), "" }
	local log = ns.diagnostics.log
	if not log or #log == 0 then
		lines[#lines + 1] = "(no events captured)"
	else
		for _, entry in ipairs(log) do
			lines[#lines + 1] = entry
		end
	end
	AppendSuppressedSummary(lines)
	return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Event Registration
--------------------------------------------------------------------------------

--[[
    For every event the add-on registers (ns.EVENT_NAMES, exported by Core.lua),
    report whether it is valid on this client (C_EventUtils.IsEventValid) and
    whether RegisterEvent succeeds. The probe frame registers then immediately
    unregisters each event with no handler attached, so nothing is ever
    processed. The list is sourced from Core so it can never drift from the
    events the add-on actually uses.
]]

local probeFrame

local function GetProbeFrame()
	if not probeFrame then
		probeFrame = CreateFrame("Frame")
	end
	return probeFrame
end

function ns.RunEventChecks()
	local lines = { GetClientHeader(), "" }
	local hasIsEventValid = type(C_EventUtils) == "table" and type(C_EventUtils.IsEventValid) == "function"
	local probe = GetProbeFrame()
	local failures = 0
	for _, event in ipairs(ns.EVENT_NAMES or {}) do
		local valid = "n/a"
		if hasIsEventValid then
			valid = C_EventUtils.IsEventValid(event) and "valid" or "INVALID"
		end
		local ok = pcall(probe.RegisterEvent, probe, event)
		if ok then
			probe:UnregisterEvent(event)
		else
			failures = failures + 1
		end
		lines[#lines + 1] = string.format("[%s] %s (IsEventValid: %s)", ok and "PASS" or "FAIL", event, valid)
	end
	lines[#lines + 1] = ""
	if failures == 0 then
		lines[#lines + 1] = "All events register on this client."
	else
		lines[#lines + 1] = string.format("%d event(s) failed to register.", failures)
	end
	return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- API Endpoints
--------------------------------------------------------------------------------

--[[
    Existence and shape checks only: read-only, no side effects, no protected
    calls. One row per WoW API the add-on depends on, scanned from across
    Features/ and Options/. Every API the code guards for existence (e.g.
    C_Bank.FetchPurchasedBankTabIDs) or reaches through a modern->legacy fallback gets a
    row of its own — modern and legacy listed separately — so the manifest stays
    one-to-one with the code's guards and the report shows exactly what each
    client provides.
]]
ns.DIAGNOSTIC_API_CHECKS = {
	-- { label, testFunction }
	{
		"C_AddOns.GetAddOnMetadata",
		function()
			return type(C_AddOns) == "table" and type(C_AddOns.GetAddOnMetadata) == "function"
		end,
	},
	{
		"C_AddOns.GetAddOnInfo",
		function()
			return type(C_AddOns) == "table" and type(C_AddOns.GetAddOnInfo) == "function"
		end,
	},
	{
		"C_AddOns.GetNumAddOns",
		function()
			return type(C_AddOns) == "table" and type(C_AddOns.GetNumAddOns) == "function"
		end,
	},
	{
		"C_AddOns.IsAddOnLoaded",
		function()
			return type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function"
		end,
	},
	-- Decides Season of Discovery's data folder (Data/Flavor.lua), which is only ever asked on Classic Era.
	{
		"C_Seasons.GetActiveSeason (Classic Era only)",
		function()
			return type(C_Seasons) == "table" and type(C_Seasons.GetActiveSeason) == "function"
		end,
	},
	--[[
	    C_Container is the container surface on all three target clients, so both
	    readers are probed there and nowhere else. Neither carries a legacy
	    fallback nor may be given one, so there is no legacy row to pair with
	    either.
	]]
	{
		"C_Container.GetContainerNumSlots",
		function()
			return type(C_Container) == "table" and type(C_Container.GetContainerNumSlots) == "function"
		end,
	},
	{
		"C_Container.GetContainerItemInfo",
		function()
			return type(C_Container) == "table" and type(C_Container.GetContainerItemInfo) == "function"
		end,
	},
	{
		"C_Map.GetBestMapForUnit",
		function()
			return type(C_Map) == "table" and type(C_Map.GetBestMapForUnit) == "function"
		end,
	},
	--[[
	    The route ns.OpenOptionsPanel docks the panel with
	    (Options/Options.lua). A client that does not provide it falls through
	    to AceConfigDialog, which opens a standalone floating window instead of
	    docking -- so a report where this row FAILs is the one that explains a
	    panel the player says opened in the wrong place.
	]]
	{
		"Settings.OpenToCategory",
		function()
			return type(Settings) == "table" and type(Settings.OpenToCategory) == "function"
		end,
	},
	--[[
	    A frame method, read off UIParent because every frame shares one
	    metatable. The Restocker window calls SetResizeBounds unconditionally as
	    it is built, so a FAIL here means that window errors when it opens.
	]]
	{
		"Frame:SetResizeBounds",
		function()
			return type(UIParent.SetResizeBounds) == "function"
		end,
	},
	{
		"IsInInstance",
		function()
			return type(IsInInstance) == "function"
		end,
	},
	--[[
	    All three load-bearing for the Restocker's entering-town reminder:
	    IsResting is the signal it keys off, UnitOnTaxi is what keeps a flight
	    path over a town from counting as arriving in one, and PlaySoundFile
	    plays the optional alert.
	]]
	{
		"IsResting",
		function()
			return type(IsResting) == "function"
		end,
	},
	{
		"UnitOnTaxi",
		function()
			return type(UnitOnTaxi) == "function"
		end,
	},
	{
		"PlaySoundFile",
		function()
			return type(PlaySoundFile) == "function"
		end,
	},
	{
		"C_Item.GetItemCount",
		function()
			return type(C_Item) == "table" and type(C_Item.GetItemCount) == "function"
		end,
	},
	{
		"C_Item.GetItemIconByID",
		function()
			return type(C_Item) == "table" and type(C_Item.GetItemIconByID) == "function"
		end,
	},
	{
		"C_Item.GetItemInfo",
		function()
			return type(C_Item) == "table" and type(C_Item.GetItemInfo) == "function"
		end,
	},
	{
		"C_Item.GetItemQualityColor",
		function()
			return type(C_Item) == "table" and type(C_Item.GetItemQualityColor) == "function"
		end,
	},
	-- Validate Data: item existence, and the instant fields every item row carries.
	{
		"C_Item.DoesItemExistByID",
		function()
			return type(C_Item) == "table" and type(C_Item.DoesItemExistByID) == "function"
		end,
	},
	{
		"C_Item.GetItemInfoInstant",
		function()
			return type(C_Item) == "table" and type(C_Item.GetItemInfoInstant) == "function"
		end,
	},
	--[[
	    Called by ns.WarmItemCache (Options/Options-Utilities.lua): without it an
	    options item list can only show ids the client already cached, so the
	    rows sit on their loading text until something else pulls the data.
	]]
	{
		"C_Item.RequestLoadItemDataByID",
		function()
			return type(C_Item) == "table" and type(C_Item.RequestLoadItemDataByID) == "function"
		end,
	},
	-- Validate Data's other item columns.
	{
		"C_Item.GetItemSpell",
		function()
			return type(C_Item) == "table" and type(C_Item.GetItemSpell) == "function"
		end,
	},
	{
		"C_Item.GetItemInventoryTypeByID",
		function()
			return type(C_Item) == "table" and type(C_Item.GetItemInventoryTypeByID) == "function"
		end,
	},
	{
		"C_Item.GetItemUniquenessByID",
		function()
			return type(C_Item) == "table" and type(C_Item.GetItemUniquenessByID) == "function"
		end,
	},
	{
		"C_Item.GetDetailedItemLevelInfo",
		function()
			return type(C_Item) == "table" and type(C_Item.GetDetailedItemLevelInfo) == "function"
		end,
	},
	{
		"C_Item.GetItemSetInfo",
		function()
			return type(C_Item) == "table" and type(C_Item.GetItemSetInfo) == "function"
		end,
	},
	{
		"C_Item.IsConsumableItem",
		function()
			return type(C_Item) == "table" and type(C_Item.IsConsumableItem) == "function"
		end,
	},
	{
		"C_Item.IsEquippableItem",
		function()
			return type(C_Item) == "table" and type(C_Item.IsEquippableItem) == "function"
		end,
	},
	{
		"C_Item.IsHelpfulItem",
		function()
			return type(C_Item) == "table" and type(C_Item.IsHelpfulItem) == "function"
		end,
	},
	{
		"C_Item.IsHarmfulItem",
		function()
			return type(C_Item) == "table" and type(C_Item.IsHarmfulItem) == "function"
		end,
	},
	{
		"C_Item.ItemHasRange",
		function()
			return type(C_Item) == "table" and type(C_Item.ItemHasRange) == "function"
		end,
	},
	{
		"C_Item.IsUsableItem",
		function()
			return type(C_Item) == "table" and type(C_Item.IsUsableItem) == "function"
		end,
	},
	{
		"GetMacroIndexByName",
		function()
			return type(GetMacroIndexByName) == "function"
		end,
	},
	{
		"CreateMacro",
		function()
			return type(CreateMacro) == "function"
		end,
	},
	{
		"EditMacro",
		function()
			return type(EditMacro) == "function"
		end,
	},
	{
		"DeleteMacro",
		function()
			return type(DeleteMacro) == "function"
		end,
	},
	{
		"GetMacroBody",
		function()
			return type(GetMacroBody) == "function"
		end,
	},
	{
		"GetNumMacros",
		function()
			return type(GetNumMacros) == "function"
		end,
	},
	--[[
	    The shims in Utilities that Forever needs: each client should PASS
	    exactly one side of every pair -- the namespaced reader on Forever, the
	    legacy global on Era and TBC.
	]]
	{
		"C_PetInfo.GetPetFoodTypes",
		function()
			return type(C_PetInfo) == "table" and type(C_PetInfo.GetPetFoodTypes) == "function"
		end,
	},
	{
		"GetPetFoodTypes (legacy)",
		function()
			return type(GetPetFoodTypes) == "function"
		end,
	},
	{
		"C_SkillInfo.GetNumSkillLines",
		function()
			return type(C_SkillInfo) == "table" and type(C_SkillInfo.GetNumSkillLines) == "function"
		end,
	},
	{
		"C_SkillInfo.GetSkillLineInfo",
		function()
			return type(C_SkillInfo) == "table" and type(C_SkillInfo.GetSkillLineInfo) == "function"
		end,
	},
	{
		"GetNumSkillLines (legacy)",
		function()
			return type(GetNumSkillLines) == "function"
		end,
	},
	{
		"GetSkillLineInfo (legacy)",
		function()
			return type(GetSkillLineInfo) == "function"
		end,
	},
	{
		"C_QuestLog.GetNumQuestLogEntries",
		function()
			return type(C_QuestLog) == "table" and type(C_QuestLog.GetNumQuestLogEntries) == "function"
		end,
	},
	{
		"C_QuestLog.GetInfo",
		function()
			return type(C_QuestLog) == "table" and type(C_QuestLog.GetInfo) == "function"
		end,
	},
	{
		"GetNumQuestLogEntries (legacy)",
		function()
			return type(GetNumQuestLogEntries) == "function"
		end,
	},
	{
		"GetQuestLogTitle (legacy)",
		function()
			return type(GetQuestLogTitle) == "function"
		end,
	},
	{
		"C_MerchantFrame.GetItemInfo",
		function()
			return type(C_MerchantFrame) == "table" and type(C_MerchantFrame.GetItemInfo) == "function"
		end,
	},
	{
		"GetMerchantItemInfo (legacy)",
		function()
			return type(GetMerchantItemInfo) == "function"
		end,
	},
	--[[
	    The level cap behind the Leveling and Max Level modes (ns.GetMaxPlayerLevel
	    in Utilities), the smaller of these two, which all three clients ship.
	    Show Connoisseur Context prints what each one answers.
	]]
	{
		"GetMaxPlayerLevel",
		function()
			return type(GetMaxPlayerLevel) == "function"
		end,
	},
	{
		"GetMaxLevelForPlayerExpansion",
		function()
			return type(GetMaxLevelForPlayerExpansion) == "function"
		end,
	},
	-- Forever's bank is its purchased tabs; Era and TBC read BANK_CONTAINER and the bank bags instead.
	{
		"C_Bank.FetchPurchasedBankTabIDs",
		function()
			return type(C_Bank) == "table" and type(C_Bank.FetchPurchasedBankTabIDs) == "function"
		end,
	},
	{
		"BANK_CONTAINER (legacy)",
		function()
			return type(BANK_CONTAINER) == "number"
		end,
	},
	{
		"C_UnitAuras.GetBuffDataByIndex",
		function()
			return type(C_UnitAuras) == "table" and type(C_UnitAuras.GetBuffDataByIndex) == "function"
		end,
	},
	{
		"C_Secrets.ShouldAurasBeSecret",
		function()
			return type(C_Secrets) == "table" and type(C_Secrets.ShouldAurasBeSecret) == "function"
		end,
	},
	{
		"C_Secrets.CanCompareUnitTokens",
		function()
			return type(C_Secrets) == "table" and type(C_Secrets.CanCompareUnitTokens) == "function"
		end,
	},
	{
		"C_Secrets.ShouldCooldownsBeSecret",
		function()
			return type(C_Secrets) == "table" and type(C_Secrets.ShouldCooldownsBeSecret) == "function"
		end,
	},
	-- Behind ns.IsSecretValue, which answers false where it FAILs (Era and TBC).
	{
		"issecretvalue",
		function()
			return type(issecretvalue) == "function"
		end,
	},
	--[[
	    Behind ns.GetPlayerFullName, which a character is saved and shown under.
	    RegionalUniqueNamesEnabled is Forever's alone: where it FAILs (Era and
	    TBC) a character has the one name and UnitNameUnmodified is never asked.
	    A FAIL on Forever means characters are keyed by first name only again.
	]]
	{
		"RegionalUniqueNamesEnabled",
		function()
			return type(RegionalUniqueNamesEnabled) == "function"
		end,
	},
	{
		"UnitNameUnmodified",
		function()
			return type(UnitNameUnmodified) == "function"
		end,
	},
	--[[
	    The Readiness Report's surface. Every one of these is reached only when
	    its own switch is on, and nothing isolates a probe, so a missing one
	    stops the whole report -- and does it silently, since a client with
	    scriptErrors off swallows the error. A FAIL here is the fastest
	    explanation for "I turned that on and the report went quiet". The
	    exceptions are GetNumTalentTabs and UnitCharacterPoints, which the
	    probes reach through ns accessors that answer nil where the client lacks
	    them: they FAIL on Forever as expected, and their lines never show there.
	]]
	{
		"GetWeaponEnchantInfo",
		function()
			return type(GetWeaponEnchantInfo) == "function"
		end,
	},
	{
		"GetInventoryItemDurability",
		function()
			return type(GetInventoryItemDurability) == "function"
		end,
	},
	{
		"GetInventoryItemLink",
		function()
			return type(GetInventoryItemLink) == "function"
		end,
	},
	{
		"GetNumTalentTabs",
		function()
			return type(GetNumTalentTabs) == "function"
		end,
	},
	{
		"C_SpecializationInfo.GetSpecializationInfo",
		function()
			return type(C_SpecializationInfo) == "table"
				and type(C_SpecializationInfo.GetSpecializationInfo) == "function"
		end,
	},
	{
		"UnitCharacterPoints",
		function()
			return type(UnitCharacterPoints) == "function"
		end,
	},
	{
		"UnitIsPVP",
		function()
			return type(UnitIsPVP) == "function"
		end,
	},
	{
		"C_Container.GetItemCooldown",
		function()
			return type(C_Container) == "table" and type(C_Container.GetItemCooldown) == "function"
		end,
	},
	-- Not the report's alone: every feature reads spell names through this.
	{
		"C_Spell.GetSpellName",
		function()
			return type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function"
		end,
	},
	-- The profession readers name their skill lines through this.
	{
		"C_TradeSkillUI.GetTradeSkillDisplayName",
		function()
			return type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetTradeSkillDisplayName) == "function"
		end,
	},
	-- Validate Data reads spells through these.
	{
		"C_Spell.GetSpellInfo",
		function()
			return type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function"
		end,
	},
	{
		"C_Spell.GetSpellSubtext",
		function()
			return type(C_Spell) == "table" and type(C_Spell.GetSpellSubtext) == "function"
		end,
	},
	{
		"C_Spell.DoesSpellExist",
		function()
			return type(C_Spell) == "table" and type(C_Spell.DoesSpellExist) == "function"
		end,
	},
	{
		"C_Spell.RequestLoadSpellData",
		function()
			return type(C_Spell) == "table" and type(C_Spell.RequestLoadSpellData) == "function"
		end,
	},
	{
		"C_Spell.GetSpellDescription",
		function()
			return type(C_Spell) == "table" and type(C_Spell.GetSpellDescription) == "function"
		end,
	},
	{
		"C_Spell.GetSpellPowerCost",
		function()
			return type(C_Spell) == "table" and type(C_Spell.GetSpellPowerCost) == "function"
		end,
	},
	{
		"C_Spell.GetSpellLink",
		function()
			return type(C_Spell) == "table" and type(C_Spell.GetSpellLink) == "function"
		end,
	},
	{
		"C_Spell.GetSpellLevelLearned",
		function()
			return type(C_Spell) == "table" and type(C_Spell.GetSpellLevelLearned) == "function"
		end,
	},
	{
		"C_Spell.GetSpellMaxCumulativeAuraApplications",
		function()
			return type(C_Spell) == "table" and type(C_Spell.GetSpellMaxCumulativeAuraApplications) == "function"
		end,
	},
	{
		"C_Spell.IsSpellPassive",
		function()
			return type(C_Spell) == "table" and type(C_Spell.IsSpellPassive) == "function"
		end,
	},
	{
		"C_Spell.IsSpellHelpful",
		function()
			return type(C_Spell) == "table" and type(C_Spell.IsSpellHelpful) == "function"
		end,
	},
	{
		"C_Spell.IsSpellHarmful",
		function()
			return type(C_Spell) == "table" and type(C_Spell.IsSpellHarmful) == "function"
		end,
	},
	{
		"C_Spell.SpellHasRange",
		function()
			return type(C_Spell) == "table" and type(C_Spell.SpellHasRange) == "function"
		end,
	},
	{
		"C_Spell.IsSelfBuff",
		function()
			return type(C_Spell) == "table" and type(C_Spell.IsSelfBuff) == "function"
		end,
	},
	{
		"C_Spell.IsConsumableSpell",
		function()
			return type(C_Spell) == "table" and type(C_Spell.IsConsumableSpell) == "function"
		end,
	},
	--[[
	    Validate Data's tooltip text (ns.GetItemTooltipLines and
	    ns.GetSpellTooltipLines in Utilities): Forever reads the C_TooltipInfo
	    pair, and Era and TBC the hidden tooltip's setters, read off
	    GameTooltip. Forever passes both, since its tooltips are built from
	    that same data.
	]]
	{
		"C_TooltipInfo.GetItemByID",
		function()
			return type(C_TooltipInfo) == "table" and type(C_TooltipInfo.GetItemByID) == "function"
		end,
	},
	{
		"C_TooltipInfo.GetSpellByID",
		function()
			return type(C_TooltipInfo) == "table" and type(C_TooltipInfo.GetSpellByID) == "function"
		end,
	},
	{
		"GameTooltip:SetItemByID",
		function()
			return type(GameTooltip.SetItemByID) == "function"
		end,
	},
	{
		"GameTooltip:SetSpellByID",
		function()
			return type(GameTooltip.SetSpellByID) == "function"
		end,
	},
	{
		"C_SpellBook.IsSpellInSpellBook",
		function()
			return type(C_SpellBook) == "table" and type(C_SpellBook.IsSpellInSpellBook) == "function"
		end,
	},
	{
		"C_SpellBook.IsSpellKnown",
		function()
			return type(C_SpellBook) == "table" and type(C_SpellBook.IsSpellKnown) == "function"
		end,
	},
	{
		"SecureCmdOptionParse",
		function()
			return type(SecureCmdOptionParse) == "function"
		end,
	},
	{
		"C_Timer.After",
		function()
			return type(C_Timer) == "table" and type(C_Timer.After) == "function"
		end,
	},
	{
		"C_EventUtils.IsEventValid",
		function()
			return type(C_EventUtils) == "table" and type(C_EventUtils.IsEventValid) == "function"
		end,
	},
	-- Restocker's load-bearing surface (merchant buying and bank restocking).
	{
		"GetMerchantNumItems",
		function()
			return type(GetMerchantNumItems) == "function"
		end,
	},
	{
		"GetMerchantItemLink",
		function()
			return type(GetMerchantItemLink) == "function"
		end,
	},
	{
		"BuyMerchantItem",
		function()
			return type(BuyMerchantItem) == "function"
		end,
	},
	{
		"UnitReaction",
		function()
			return type(UnitReaction) == "function"
		end,
	},
	{
		"GetNetStats",
		function()
			return type(GetNetStats) == "function"
		end,
	},
	{
		"C_Item.GetItemFamily",
		function()
			return type(C_Item) == "table" and type(C_Item.GetItemFamily) == "function"
		end,
	},
	{
		"C_Container.GetContainerNumFreeSlots",
		function()
			return type(C_Container) == "table" and type(C_Container.GetContainerNumFreeSlots) == "function"
		end,
	},
	{
		"C_Container.PickupContainerItem",
		function()
			return type(C_Container) == "table" and type(C_Container.PickupContainerItem) == "function"
		end,
	},
	{
		"C_Container.SplitContainerItem",
		function()
			return type(C_Container) == "table" and type(C_Container.SplitContainerItem) == "function"
		end,
	},
	{
		"C_Container.UseContainerItem",
		function()
			return type(C_Container) == "table" and type(C_Container.UseContainerItem) == "function"
		end,
	},
	{
		"GetCVar",
		function()
			return type(GetCVar) == "function"
		end,
	},
	{
		"SetCVar",
		function()
			return type(SetCVar) == "function"
		end,
	},
}

function ns.RunApiChecks()
	local lines = { GetClientHeader(), "" }
	for _, check in ipairs(ns.DIAGNOSTIC_API_CHECKS) do
		local ok, result = pcall(check[2])
		lines[#lines + 1] = ((ok and result) and "[PASS] " or "[FAIL] ") .. check[1]
	end
	return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Connoisseur Context
--------------------------------------------------------------------------------

--[[
    Existence/value reads only (same read-only contract as the API checks). The
    add-on-specific probe for "nothing shows up" reports: the spells the add-on
    gates on, the current best-item selections, and — because the add-on draws a
    minimap button — the display context behind off-screen / wrong-scale reports.
]]
ns.DIAGNOSTIC_SPELLS = {
	-- { spellID, label }
	{ ns.MISSING_SPELL_MESSAGE_IDS.noConjureFood, "Conjure Food (Rank 1)" },
	{ ns.MISSING_SPELL_MESSAGE_IDS.noConjureWater, "Conjure Water (Rank 1)" },
	{ ns.MISSING_SPELL_MESSAGE_IDS.noConjureManaGem, "Conjure Mana Agate" },
	{ ns.MISSING_SPELL_MESSAGE_IDS.noRitualOfRefreshment, "Ritual of Refreshment" },
	{ ns.MISSING_SPELL_MESSAGE_IDS.noCreateHealthstone, "Create Healthstone (Minor)" },
	{ ns.MISSING_SPELL_MESSAGE_IDS.noCreateSoulstone, "Create Soulstone (Minor)" },
	{ ns.MISSING_SPELL_MESSAGE_IDS.noRitualOfSouls, "Ritual of Souls" },
	{ ns.CALL_PET_SPELL_ID, "Call Pet" },
	{ ns.FEED_PET_SPELL_ID, "Feed Pet" },
	{ ns.MEND_PET_SPELL_ID, "Mend Pet" },
	{ ns.REVIVE_PET_SPELL_ID, "Revive Pet" },
	{ ns.DISMISS_PET_SPELL_ID, "Dismiss Pet" },
	{ ns.SHADOWMELD_SPELL_ID, "Shadowmeld" },
	{ ns.POISONS_SPELL_ID, "Poisons" },
	{ ns.STEALTH_SPELL_ID, "Stealth" },
	{ ns.GOBLIN_ENGINEER_SPELL_ID, "Goblin Engineer" },
}

function ns.BuildContextReport()
	local lines = { GetClientHeader(), "" }

	local _, classToken = UnitClass("player")
	lines[#lines + 1] = string.format(
		"Class: %s // Level: %s // Cached level: %s // Cached map: %s",
		tostring(classToken),
		tostring(UnitLevel("player")),
		tostring(ns.cachedPlayerLevel),
		tostring(ns.cachedMapID)
	)

	-- The cap the Leveling and Max Level modes compare against, and what each reader answers.
	lines[#lines + 1] = string.format(
		"Max level: %s // GetMaxPlayerLevel: %s // GetMaxLevelForPlayerExpansion: %s",
		tostring(ns.GetMaxPlayerLevel()),
		tostring(GetMaxPlayerLevel and GetMaxPlayerLevel()),
		tostring(GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion())
	)

	-- The profession ranks the scanner's usability gates read (0 = unlearned).
	lines[#lines + 1] = string.format(
		"Skills: First Aid %s // Alchemy %s // Engineering %s",
		tostring(ns.currentFirstAidSkill),
		tostring(ns.currentAlchemySkill),
		tostring(ns.currentEngineeringSkill)
	)

	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- Best-item selection --"
	lines[#lines + 1] = string.format("bestFoodID: %s", tostring(ns.bestFoodID))
	lines[#lines + 1] = string.format("bestPetFoodID: %s", tostring(ns.bestPetFoodID))
	if ns.scrollOverrideIDs and #ns.scrollOverrideIDs > 0 then
		lines[#lines + 1] = "scrollOverrideIDs: " .. table.concat(ns.scrollOverrideIDs, ", ")
	else
		lines[#lines + 1] = "scrollOverrideIDs: (none)"
	end
	lines[#lines + 1] = string.format("petBuffOverrideID: %s", tostring(ns.petBuffOverrideID))

	--[[
	    Per-category winners from the last ScanBags pass (ns.bestSelection is
	    the scanner's live best table). The read-out for "category X didn't
	    update" reports: it shows exactly what the scanner picked plus the
	    tiebreak inputs (value/price/count) the comparison ladder ordered on,
	    and the ranked topIDs for multi-use types — none of which bestFoodID
	    alone can reveal.
	]]
	local selection = ns.bestSelection
	if selection then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Best by category (last scan) --"
		local categories = {}
		for typeName in pairs(selection) do
			categories[#categories + 1] = typeName
		end
		table.sort(categories)
		for _, typeName in ipairs(categories) do
			local entry = selection[typeName]
			local detail = string.format(
				"id=%s value=%s price=%s count=%s",
				tostring(entry.id),
				tostring(entry.value),
				tostring(entry.price),
				tostring(entry.count)
			)
			if entry.topIDs and #entry.topIDs > 0 then
				detail = detail .. " topIDs=" .. table.concat(entry.topIDs, ",")
			end
			lines[#lines + 1] = string.format("%s: %s", typeName, detail)
		end
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- Spell knowledge --"
	for _, entry in ipairs(ns.DIAGNOSTIC_SPELLS) do
		local spellID, label = entry[1], entry[2]
		-- A spell this client's data folder doesn't carry has a nil ID and gets no line.
		if spellID then
			local known = ns.IsSpellKnown(spellID) or ns.IsPlayerSpell(spellID)
			local name = C_Spell.GetSpellName(spellID)
			lines[#lines + 1] = string.format(
				"[%s] %s (%d)%s",
				known and "KNOWN" or "  -  ",
				label,
				spellID,
				name and (" = " .. name) or " (no name on this client)"
			)
		end
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- Display context --"
	local physicalWidth, physicalHeight = GetPhysicalScreenSize()
	lines[#lines + 1] = string.format("PhysicalScreenSize: %s x %s", tostring(physicalWidth), tostring(physicalHeight))
	lines[#lines + 1] = string.format("UIParent scale: %s", tostring(UIParent and UIParent:GetScale()))
	lines[#lines + 1] = string.format("uiScale CVar: %s", tostring(GetCVar("uiScale")))

	return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Item Selection
--------------------------------------------------------------------------------

--[[
    The "why did it pick that?" read-out. For every category that goes through
    the scanner's ranking ladder, prints the winner and the runners-up it beat,
    each tagged with the RANKING_PRIORITY field that decided the pair (see
    Features/Scanner-Inventory.lua). Reads only what the last scan left behind;
    it never rescans, so the report can never disagree with the macros the
    player is actually looking at.
]]

local function DescribeItem(itemID)
	if not itemID then
		return "(none)"
	end
	local name = C_Item.GetItemInfo(itemID)
	if name then
		return string.format("%d (%s)", itemID, name)
	end
	return string.format("%d (name not cached)", itemID)
end

local function AppendCategoryLines(lines, typeName, entry, candidates)
	lines[#lines + 1] = string.format("%s: %s", typeName, DescribeItem(entry and entry.id))

	if entry and entry.id then
		lines[#lines + 1] = string.format(
			"    won with value=%s price=%s count=%s",
			tostring(entry.value),
			tostring(entry.price),
			tostring(entry.count)
		)
	end

	if entry and entry.topIDs and #entry.topIDs > 0 then
		lines[#lines + 1] = "    stacked /use order: " .. table.concat(entry.topIDs, ", ")
	end

	if not candidates or #candidates < 2 then
		return
	end

	for i = 2, #candidates do
		local candidate = candidates[i]
		lines[#lines + 1] = string.format(
			"    beat %s on %s (value=%s price=%s count=%s)",
			DescribeItem(candidate.id),
			candidate.decidedBy or "nothing (identical record)",
			tostring(candidate.value),
			tostring(candidate.price),
			tostring(candidate.count)
		)
	end
end

function ns.BuildSelectionReport()
	local lines = { GetClientHeader(), "" }

	local selection = ns.bestSelection
	local candidates = ns.diagnosticCandidates

	if not selection then
		lines[#lines + 1] = "No scan has completed yet. Trigger one by looting an item or changing zone."
		return table.concat(lines, "\n")
	end

	--[[
	    Candidate retention starts when the tools are enabled, so a report run
	    before the next scan has winners but no runners-up. Say so rather than
	    letting an empty list read as "nothing else was in the running."
	]]
	local retained = false
	for _, list in pairs(candidates) do
		if #list > 0 then
			retained = true
			break
		end
	end

	lines[#lines + 1] = string.format("allowBuffFood (live scan preference): %s", tostring(ns.allowBuffFood))
	lines[#lines + 1] = string.format("allowConjuredFirst (live scan preference): %s", tostring(ns.allowConjuredFirst))
	if not retained then
		lines[#lines + 1] = ""
		lines[#lines + 1] =
			"No candidates were retained: the last scan ran before these tools were enabled. Trigger a rescan (loot something, or change zone) and run this again to see the runners-up."
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- Ranked by the selection ladder --"

	local typeNames = {}
	for _, definition in ipairs(ns.REGISTERED_MACRO_DEFINITIONS or {}) do
		if definition.itemTypes then
			typeNames[#typeNames + 1] = definition.typeName
		end
	end
	table.sort(typeNames)

	for _, typeName in ipairs(typeNames) do
		AppendCategoryLines(lines, typeName, selection[typeName], candidates[typeName])
	end

	--[[
	    The custom definitions own their whole update and resolve their item
	    outside the ladder (the Hunter pet-food scan, the Rogue poison walk),
	    so they have no candidate list to show. Naming them keeps the report
	    honest about what it does and does not cover.
	]]
	local customNames = {}
	for _, definition in ipairs(ns.REGISTERED_CUSTOM_MACRO_DEFINITIONS or {}) do
		customNames[#customNames + 1] = definition.typeName
	end
	table.sort(customNames)

	if #customNames > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Resolved outside the ladder (no candidate ranking) --"
		for _, typeName in ipairs(customNames) do
			lines[#lines + 1] = string.format("%s: resolved by its own builder at macro-update time", typeName)
		end
		lines[#lines + 1] = string.format("Feed Pet current pick: %s", DescribeItem(ns.bestPetFoodID))
	end

	return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Readiness Report
--------------------------------------------------------------------------------

--[[
    The Readiness Report as it would print RIGHT NOW, without waiting for a ready
    check. Read-only: it asks the same probes the report asks and prints nothing
    to chat.

    This exists because the report has two silences that look identical from a
    chat window -- "you are ready" and "it never ran" -- and only one of them is
    a bug. Rendering it on demand separates them in one button press, and the
    switch states below say which lines were even eligible to speak.

    Colour escapes are stripped: reports are plain text, and a |cff pasted into
    a bug report is noise.
]]
local READINESS_SWITCHES = {
	"readinessFlask",
	"readinessWellFed",
	"readinessPetWellFed",
	"readinessScrolls",
	"readinessSoulstone",
	"readinessMainHandBuff",
	"readinessOffHandBuff",
	"readinessExpiring",
	"readinessHealthstone",
	"readinessManaGem",
	"readinessHealingPotion",
	"readinessManaPotion",
	"readinessBandages",
	"readinessDurability",
	"readinessSpec",
	"readinessPvP",
	"readinessQuestionableGear",
}

function ns.BuildReadinessDiagnosticReport()
	local lines = { GetClientHeader(), "" }

	local reports = ns.db and ns.db.global
	if not reports then
		lines[#lines + 1] = "Saved variables are not loaded yet."
		return table.concat(lines, "\n")
	end

	lines[#lines + 1] = string.format("Report enabled: %s", tostring(reports.readinessReportEnabled))
	lines[#lines + 1] = string.format("Instance type: %s", tostring(select(2, IsInInstance())))
	lines[#lines + 1] = string.format("In group: %s", tostring(IsInGroup()))

	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- What it would print now --"

	-- The report walks auras, and on Forever a restricted aura read throws.
	if C_Secrets.ShouldAurasBeSecret() then
		lines[#lines + 1] = "(aura data is restricted right now -- run this report again out of combat)"
	else
		-- A probe that throws must still leave a report, or this button shows nothing at all.
		local ok, body = pcall(ns.BuildReadinessLines, select(2, IsInInstance()) == "arena")
		if not ok then
			lines[#lines + 1] = "ERROR: " .. tostring(body)
		elseif not body then
			lines[#lines + 1] = "(nothing -- this character has nothing the report would name)"
		else
			lines[#lines + 1] = ns.L["READINESS_TITLE"]
			for _, line in ipairs(body) do
				lines[#lines + 1] = line
			end
		end
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- Category switches --"
	for _, key in ipairs(READINESS_SWITCHES) do
		lines[#lines + 1] = string.format("[%s] %s", reports[key] and "ON " or "   ", key)
	end

	local text = table.concat(lines, "\n")
	-- Item links (Damaged / Non-Combat Gear) survive the color strip; escaping them makes the paste plain text.
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "||"))
end

--------------------------------------------------------------------------------
-- Other Add-ons
--------------------------------------------------------------------------------

function ns.BuildAddOnReport()
	local lines = { GetClientHeader(), "" }
	local getInfo = C_AddOns.GetAddOnInfo
	local getMetadata = C_AddOns.GetAddOnMetadata
	local count = C_AddOns.GetNumAddOns()
	for index = 1, count do
		local name, _, _, loadable = getInfo(index)
		local version = getMetadata(index, "Version") or "?"
		lines[#lines + 1] = string.format(
			"%s v%s [%s, %s]",
			name,
			version,
			loadable and "loadable" or "disabled",
			C_AddOns.IsAddOnLoaded(name) and "loaded" or "not loaded"
		)
	end
	return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Saved Variables
--------------------------------------------------------------------------------

--[[
    Every row the player can edit prints in full, since those rows are what
    explain a bug. Only what the add-on fills in itself is counted instead:
    itemCache, the derived consumable cache, matched by key at any depth, since
    under AceDB it moves around with the active profile.
]]
local SUMMARIZED_BY_KEY = {
	itemCache = "cached items",
}

local function CountEntries(value)
	local count = 0
	for _ in pairs(value) do
		count = count + 1
	end
	return count
end

local function DumpTable(value, indent, depth, lines)
	if depth > 8 then
		lines[#lines + 1] = indent .. "<max depth>"
		return
	end
	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, key in ipairs(keys) do
		local entry = value[key]
		local noun = type(entry) == "table" and SUMMARIZED_BY_KEY[key]
		if type(entry) ~= "table" then
			lines[#lines + 1] = indent .. tostring(key) .. " = " .. tostring(entry)
		elseif noun then
			lines[#lines + 1] = indent .. tostring(key) .. string.format(" = <%d %s>", CountEntries(entry), noun)
		else
			lines[#lines + 1] = indent .. tostring(key) .. " = {"
			DumpTable(entry, indent .. "    ", depth + 1, lines)
			lines[#lines + 1] = indent .. "}"
		end
	end
end

function ns.BuildSavedVariablesReport()
	local lines = { GetClientHeader(), "" }

	--[[
	    Dump the single AceDB-managed SavedVariable in its real on-disk shape
	    (profiles / global / profileKeys). Everything the add-on saves is in
	    here, the Restock Lists included, row by row. DumpTable counts only the
	    derived itemCache rather than printing it, and it never writes.
	]]
	lines[#lines + 1] = "ConnoisseurDB = {"
	DumpTable(ConnoisseurDB or {}, "    ", 1, lines)
	lines[#lines + 1] = "}"

	return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Library Versions
--------------------------------------------------------------------------------

function ns.BuildLibraryReport()
	local lines = { GetClientHeader(), "" }
	local names = {}
	for name in LibStub:IterateLibraries() do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		lines[#lines + 1] = string.format("%s (minor %s)", name, tostring(LibStub.minors[name]))
	end
	return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Validate Data
--------------------------------------------------------------------------------

local function Keys(source)
	local ids = {}
	for id in pairs(source) do
		ids[#ids + 1] = id
	end
	return ids
end

local function Values(source)
	local ids = {}
	for _, id in pairs(source) do
		ids[#ids + 1] = id
	end
	return ids
end

-- A single-ID constant: the value on ns is the ID itself.
local function Self(id)
	return { id }
end

-- One field of every row, by index for row arrays and by name for keyed rows.
local function Column(field)
	return function(source)
		local ids = {}
		for _, row in pairs(source) do
			ids[#ids + 1] = row[field]
		end
		return ids
	end
end

-- Every ID in a table whose values are lists of IDs.
local function ListValues(source)
	local ids = {}
	for _, list in pairs(source) do
		for _, id in ipairs(list) do
			ids[#ids + 1] = id
		end
	end
	return ids
end

local function UpgradeTierItems(chains)
	local ids = {}
	for _, chain in ipairs(chains) do
		for _, tier in ipairs(chain.tiers) do
			ids[#ids + 1] = tier[2]
		end
	end
	return ids
end

local function RecipeReagents(recipes)
	local ids = {}
	for _, recipe in ipairs(recipes) do
		for _, reagent in ipairs(recipe[2]) do
			ids[#ids + 1] = reagent[1]
		end
	end
	return ids
end

local function ScrollColumn(index)
	return function(scrollData)
		local ids = {}
		for _, scrollType in pairs(scrollData) do
			for _, row in ipairs(scrollType.items) do
				ids[#ids + 1] = row[index]
			end
		end
		return ids
	end
end

local function ScrollConflictSpells(scrollData)
	local ids = {}
	for _, scrollType in pairs(scrollData) do
		for spellID in pairs(scrollType.conflictSpells) do
			ids[#ids + 1] = spellID
		end
	end
	return ids
end

local function ConjureSpellIDs(conjureSpells)
	local ids = {}
	for _, spellList in pairs(conjureSpells) do
		for _, entry in ipairs(spellList) do
			ids[#ids + 1] = entry[1]
		end
	end
	return ids
end

--[[
    One entry per file in the flavor folders, labeled by the table part of its
    file name; the panel titles each section with the folder this client loaded
    (ns.DATA_FOLDER). Every table is named by its key on ns, never held as a
    reference, so a table this client's folder never built reports TABLE MISSING
    instead of throwing. kind is "spell" or "item" for IDs the client can look
    up, or "other" for IDs no client API reads, which report their row count;
    idsOf returns the IDs to validate. A folder file missing from here is one
    the validator never checks.
]]
ns.DIAGNOSTIC_DATA_SOURCES = {
	-- { label, tables = { { table = <key on ns>, kind, idsOf } } }
	{
		label = "Bandages",
		tables = {
			{ table = "BANDAGES", kind = "item", idsOf = Keys },
		},
	},
	{
		label = "Conjure-Spells",
		tables = {
			{ table = "CONJURE_SPELLS", kind = "spell", idsOf = ConjureSpellIDs },
			{ table = "MISSING_SPELL_MESSAGE_IDS", kind = "spell", idsOf = Values },
		},
	},
	{
		label = "Conjured-Items",
		tables = {
			{ table = "CONJURED_ITEM_IDS_BY_SPELL", kind = "spell", idsOf = Keys },
			{ table = "CONJURED_ITEM_IDS_BY_SPELL", kind = "item", idsOf = ListValues },
		},
	},
	{
		label = "Consumable-Upgrade-Paths",
		tables = {
			{ table = "CONSUMABLE_UPGRADE_CHAINS", kind = "item", idsOf = UpgradeTierItems },
		},
	},
	{
		label = "Elixirs",
		tables = {
			{ table = "FLASK_BUFF_IDS", kind = "spell", idsOf = Keys },
			{ table = "ELIXIR_BUFF_IDS", kind = "spell", idsOf = Keys },
		},
	},
	{
		label = "Explosives",
		tables = {
			{ table = "EXPLOSIVES", kind = "item", idsOf = Keys },
			{ table = "EXPLOSIVES", kind = "spell", idsOf = Column(4) },
		},
	},
	{
		label = "Food-and-Water",
		tables = {
			{ table = "FOOD_AND_WATER", kind = "item", idsOf = Keys },
		},
	},
	{
		label = "Game-IDs",
		tables = {
			{ table = "CALL_PET_SPELL_ID", kind = "spell", idsOf = Self },
			{ table = "DISMISS_PET_SPELL_ID", kind = "spell", idsOf = Self },
			{ table = "DRUID_BEAR_FORM_SPELL_ID", kind = "spell", idsOf = Self },
			{ table = "DRUID_CAT_FORM_SPELL_ID", kind = "spell", idsOf = Self },
			{ table = "DRUID_DIRE_BEAR_FORM_SPELL_ID", kind = "spell", idsOf = Self },
			{ table = "FEED_PET_SPELL_ID", kind = "spell", idsOf = Self },
			{ table = "GOBLIN_ENGINEER_SPELL_ID", kind = "spell", idsOf = Self },
			{ table = "MEND_PET_SPELL_ID", kind = "spell", idsOf = Self },
			{ table = "PET_BUFF_FOODS", kind = "spell", idsOf = Column(1) },
			{ table = "POISONS_SPELL_ID", kind = "spell", idsOf = Self },
			{ table = "REVIVE_PET_SPELL_ID", kind = "spell", idsOf = Self },
			{ table = "SHADOWMELD_SPELL_ID", kind = "spell", idsOf = Self },
			{ table = "STEALTH_SPELL_ID", kind = "spell", idsOf = Self },
			{ table = "PET_BUFF_FOODS", kind = "item", idsOf = Keys },
		},
	},
	{
		label = "Healthstones",
		tables = {
			{ table = "HEALTHSTONES", kind = "item", idsOf = Keys },
		},
	},
	{
		label = "Macro-Default-Items",
		tables = {
			{ table = "MACRO_DEFAULT_ITEM_IDS", kind = "item", idsOf = Values },
		},
	},
	{
		label = "Mana-Gems",
		tables = {
			{ table = "MANA_GEMS", kind = "item", idsOf = Keys },
			{ table = "MANA_RUNES", kind = "item", idsOf = Keys },
		},
	},
	{
		label = "Pet-Foods",
		tables = {
			{ table = "PET_FOOD_DATA", kind = "item", idsOf = Keys },
		},
	},
	{
		label = "Poison-Recipes",
		tables = {
			{ table = "POISON_RECIPES", kind = "item", idsOf = Column(1) },
			{ table = "POISON_RECIPES", kind = "item", idsOf = RecipeReagents },
		},
	},
	{
		label = "Poisons",
		tables = {
			{ table = "POISON_DATA", kind = "item", idsOf = Keys },
			{ table = "POISON_GROUP_BASE_ITEMS", kind = "item", idsOf = Values },
		},
	},
	{
		label = "Potions",
		tables = {
			{ table = "POTIONS", kind = "item", idsOf = Keys },
		},
	},
	{
		label = "Questionable-Equipment",
		tables = {
			{ table = "QUESTIONABLE_EQUIPMENT", kind = "item", idsOf = Keys },
		},
	},
	{
		label = "Scrolls",
		tables = {
			{ table = "SCROLL_DATA", kind = "item", idsOf = ScrollColumn(1) },
			{ table = "SCROLL_DATA", kind = "spell", idsOf = ScrollColumn(2) },
			{ table = "SCROLL_DATA", kind = "spell", idsOf = ScrollConflictSpells },
		},
	},
	{
		label = "Soulstones",
		tables = {
			{ table = "SOULSTONES", kind = "item", idsOf = Keys },
			{ table = "SOULSTONE_BUFF_SPELL_IDS", kind = "spell", idsOf = Values },
		},
	},
	{
		label = "Well-Fed-Buffs",
		tables = {
			{ table = "WELL_FED_BUFF_IDS", kind = "spell", idsOf = Keys },
			{ table = "WELL_FED_ICON_IDS", kind = "other", idsOf = Keys },
		},
	},
}

-- In SpellCells' order.
local SPELL_COLUMNS = {
	"STATUS",
	"Spell ID",
	"Source",
	"Name",
	"Subtext",
	"Description",
	"Tooltip",
	"Icon",
	"Original Icon",
	"Cast Time",
	"Min Range",
	"Max Range",
	"Power Cost",
	"Link",
	"Level Learned",
	"Max Stacks",
	"IsSpellPassive",
	"IsSpellHelpful",
	"IsSpellHarmful",
	"SpellHasRange",
	"IsSelfBuff",
	"IsConsumableSpell",
	"IsPlayerSpell",
	"IsSpellKnown",
}

--[[
    In ItemCells' order: C_Item.GetItemInfo's eighteen returns, the item's
    spell and that spell's text, the tooltip, C_Item.GetItemInfoInstant's
    fields after the ID it repeats, then the remaining readers' columns, one or
    more per reader.
]]
local ITEM_COLUMNS = {
	"STATUS",
	"Item ID",
	"Source",
	"Name",
	"Link",
	"Quality",
	"Item Level",
	"Min Level",
	"Type",
	"Subtype",
	"Stack Count",
	"Equip Location",
	"Texture",
	"Sell Price",
	"Class ID",
	"Subclass ID",
	"Bind Type",
	"Expansion ID",
	"Set ID",
	"Crafting Reagent",
	"Item Description",
	"Item Spell",
	"Item Spell ID",
	"Item Spell Description",
	"Tooltip",
	"Instant Type",
	"Instant Subtype",
	"Instant Equip Location",
	"Instant Icon",
	"Instant Class ID",
	"Instant Subclass ID",
	"Inventory Type",
	"Item Family",
	"Unique",
	"Limit Category",
	"Limit Category Count",
	"Limit Category ID",
	"Actual Item Level",
	"Preview Item Level",
	"Sparse Item Level",
	"Set Name",
	"IsConsumableItem",
	"IsEquippableItem",
	"IsHelpfulItem",
	"IsHarmfulItem",
	"ItemHasRange",
	"IsUsableItem",
	"No Mana",
	"Count In Bags",
}
local ITEM_INFO_RETURNS = 18

-- An "other" table reports how many rows it holds, since no client API reads its IDs.
local OTHER_COLUMNS = {
	"STATUS",
	"Source",
	"Rows",
}

local VALIDATE_BATCH_SIZE = 100
local VALIDATE_POLL_SECONDS = 0.2

-- A repaint rebuilds the whole panel, every finished report box included, so progress redraws at most this often.
local VALIDATE_REPAINT_SECONDS = 1

--[[
    Polls that settled nothing new before a batch's stragglers are flagged.
    Counting idle polls rather than all of them means a slow load that is still
    moving is never cut off.
]]
local VALIDATE_MAX_IDLE_POLLS = 25

-- Idle polls between asking again for a batch's stragglers, in case a load request went unanswered.
local VALIDATE_RETRY_POLLS = 5

-- Tabs and newlines would split the TSV, and a raw pipe would render as an escape.
local function Cell(value)
	if value == nil then
		return ""
	end
	return (tostring(value):gsub("[\t\r\n]", " "):gsub("|", "||"))
end

local function WithCommas(number)
	local text = tostring(number)
	local replaced
	repeat
		text, replaced = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
	until replaced == 0
	return text
end

--[[
    A table this client's folder never built settles as one TABLE MISSING row
    before the run starts, so the rest of the entry still validates, and an
    "other" table settles there as its row count.
]]
local function CollectValidationRows(entry)
	local rowsByKind = { spell = {}, item = {}, other = {} }
	for _, dataTable in ipairs(entry.tables) do
		local name = "ns." .. dataTable.table
		local source = ns[dataTable.table]
		local rows = rowsByKind[dataTable.kind]
		if source == nil then
			rows[#rows + 1] = {
				cells = dataTable.kind == "other" and { "TABLE MISSING", Cell(name) }
					or { "TABLE MISSING", "", Cell(name) },
			}
		elseif dataTable.kind == "other" then
			rows[#rows + 1] = { cells = { "OK", Cell(name), Cell(#dataTable.idsOf(source)) } }
		else
			local seen, ids = {}, {}
			for _, id in ipairs(dataTable.idsOf(source)) do
				if not seen[id] then
					seen[id] = true
					ids[#ids + 1] = id
				end
			end
			table.sort(ids)
			for _, id in ipairs(ids) do
				rows[#rows + 1] = { id = id, source = name, kind = dataTable.kind }
			end
		end
	end
	return rowsByKind.spell, rowsByKind.item, rowsByKind.other
end

-- A whole tooltip in one cell: " // " between lines, " >> " before a line's right-hand text.
local function TooltipText(lines)
	local parts = {}
	for _, line in ipairs(lines or {}) do
		local left, right = line[1] or "", line[2]
		if right and right ~= "" then
			parts[#parts + 1] = left .. " >> " .. right
		elseif left ~= "" then
			parts[#parts + 1] = left
		end
	end
	return table.concat(parts, " // ")
end

-- Each cost a spell carries: its power token and amount, then whatever else about it is set.
local function PowerCostText(costs)
	local parts = {}
	for _, cost in ipairs(costs or {}) do
		local text = tostring(cost.name) .. " " .. tostring(cost.cost)
		if cost.minCost and cost.minCost ~= cost.cost then
			text = text .. " min " .. cost.minCost
		end
		if (cost.costPercent or 0) > 0 then
			text = text .. " " .. cost.costPercent .. "%"
		end
		if (cost.costPerSec or 0) > 0 then
			text = text .. " " .. cost.costPerSec .. "/sec"
		end
		if (cost.requiredAuraID or 0) > 0 then
			text = text .. " aura " .. cost.requiredAuraID
		end
		parts[#parts + 1] = text
	end
	return table.concat(parts, "; ")
end

-- Exactly count cells from a call's returns, so a call that returns nothing still fills its columns.
local function Append(cells, count, ...)
	for position = 1, count do
		cells[#cells + 1] = Cell((select(position, ...)))
	end
end

local function SpellCells(row)
	local id = row.id
	local info = C_Spell.GetSpellInfo(id) or {}
	return {
		row.status,
		Cell(id),
		Cell(row.source),
		Cell(info.name),
		Cell(C_Spell.GetSpellSubtext(id)),
		Cell(C_Spell.GetSpellDescription(id)),
		Cell(TooltipText(row.tooltip)),
		Cell(info.iconID),
		Cell(info.originalIconID),
		Cell(info.castTime),
		Cell(info.minRange),
		Cell(info.maxRange),
		Cell(PowerCostText(C_Spell.GetSpellPowerCost(id))),
		Cell(C_Spell.GetSpellLink(id)),
		Cell(C_Spell.GetSpellLevelLearned(id)),
		Cell(C_Spell.GetSpellMaxCumulativeAuraApplications(id)),
		Cell(C_Spell.IsSpellPassive(id)),
		Cell(C_Spell.IsSpellHelpful(id)),
		Cell(C_Spell.IsSpellHarmful(id)),
		Cell(C_Spell.SpellHasRange(id)),
		Cell(C_Spell.IsSelfBuff(id)),
		Cell(C_Spell.IsConsumableSpell(id)),
		Cell(ns.IsPlayerSpell(id)),
		Cell(ns.IsSpellKnown(id)),
	}
end

local function ItemCells(row)
	local id = row.id
	local cells = { row.status, Cell(id), Cell(row.source) }
	local _, spellID = C_Item.GetItemSpell(id)
	local setID = select(16, C_Item.GetItemInfo(id))
	Append(cells, ITEM_INFO_RETURNS, C_Item.GetItemInfo(id))
	Append(cells, 2, C_Item.GetItemSpell(id))
	Append(cells, 1, spellID and C_Spell.GetSpellDescription(spellID))
	Append(cells, 1, TooltipText(row.tooltip))
	Append(cells, 6, select(2, C_Item.GetItemInfoInstant(id)))
	Append(cells, 1, C_Item.GetItemInventoryTypeByID(id))
	Append(cells, 1, C_Item.GetItemFamily(id))
	Append(cells, 4, C_Item.GetItemUniquenessByID(id))
	Append(cells, 3, C_Item.GetDetailedItemLevelInfo(id))
	Append(cells, 1, setID and C_Item.GetItemSetInfo(setID))
	Append(cells, 1, C_Item.IsConsumableItem(id))
	Append(cells, 1, C_Item.IsEquippableItem(id))
	Append(cells, 1, C_Item.IsHelpfulItem(id))
	Append(cells, 1, C_Item.IsHarmfulItem(id))
	Append(cells, 1, C_Item.ItemHasRange(id))
	Append(cells, 2, C_Item.IsUsableItem(id))
	Append(cells, 1, C_Item.GetItemCount(id))
	return cells
end

-- A read that threw settles its row with the error where the name goes, and the run carries on.
local function ErrorCells(row, message)
	return { "ERROR", Cell(row.id), Cell(row.source), Cell(message) }
end

local function SettleRow(row, status)
	row.status = status
	local ok, cells = pcall(row.kind == "spell" and SpellCells or ItemCells, row)
	if ok then
		row.cells = cells
	elseif status == "NOT ON CLIENT" then
		-- A reader may throw on an ID the client doesn't know; the status is the finding.
		row.cells = { status, Cell(row.id), Cell(row.source) }
	else
		row.cells = ErrorCells(row, cells)
	end
end

local function RequestRowData(row)
	if row.kind == "spell" then
		C_Spell.RequestLoadSpellData(row.id)
	else
		C_Item.RequestLoadItemDataByID(row.id)
		row.spellRequested = nil
	end
end

--[[
    Only the text counts: on WoW Forever C_Spell.IsSpellDataCached turns true
    before the description has any, and the description is nil, not "", until
    the spell loads.
]]
local function IsSpellTextLoaded(spellID)
	local text = C_Spell.GetSpellDescription(spellID)
	return text ~= nil and text ~= ""
end

-- A tooltip whose item is still loading shows only the retrieving line.
local function IsTooltipLoaded(lines)
	local first = lines and lines[1] and lines[1][1]
	return first ~= nil and first ~= "" and first ~= RETRIEVING_ITEM_INFO
end

--[[
    One poll of an unsettled row, returning the status to settle it with or nil
    to keep waiting. The first poll asks whether the client knows the ID and
    requests its data. A row is complete once everything its cells read has
    loaded: the spell or item, its text (an item's through its spell) and its
    tooltip. The tooltip is read as soon as the spell or item loads, so a row
    that times out still shows how far it got.
]]
local function PollRow(row)
	local id = row.id
	if not row.requested then
		row.requested = true
		local exists
		if row.kind == "spell" then
			exists = C_Spell.DoesSpellExist(id)
		else
			exists = C_Item.DoesItemExistByID(id)
		end
		if not exists then
			return "NOT ON CLIENT"
		end
		RequestRowData(row)
	end

	if row.kind == "spell" then
		if not C_Spell.GetSpellInfo(id) then
			return nil
		end
		row.tooltip = ns.GetSpellTooltipLines(id)
		if not IsSpellTextLoaded(id) then
			return nil
		end
	else
		if not C_Item.GetItemInfo(id) then
			return nil
		end
		row.tooltip = ns.GetItemTooltipLines(id)
		local _, spellID = C_Item.GetItemSpell(id)
		if spellID and not IsSpellTextLoaded(spellID) then
			if row.spellRequested ~= spellID then
				row.spellRequested = spellID
				C_Spell.RequestLoadSpellData(spellID)
			end
			return nil
		end
	end
	return IsTooltipLoaded(row.tooltip) and "OK" or nil
end

local function BuildValidationReport(spellRows, itemRows, otherRows)
	local lines = { GetClientHeader(), "" }
	local blocks = { { SPELL_COLUMNS, spellRows }, { ITEM_COLUMNS, itemRows }, { OTHER_COLUMNS, otherRows } }
	for _, block in ipairs(blocks) do
		local columns, rows = block[1], block[2]
		if #rows > 0 then
			if #lines > 2 then
				lines[#lines + 1] = ""
			end
			lines[#lines + 1] = table.concat(columns, "\t")
			for _, row in ipairs(rows) do
				lines[#lines + 1] = table.concat(row.cells, "\t")
			end
		end
	end
	return table.concat(lines, "\n")
end

--[[
    Validates one ns.DIAGNOSTIC_DATA_SOURCES entry into ns.diagnostics[field],
    calling onUpdate so the panel redraws: for the progress line at most every
    VALIDATE_REPAINT_SECONDS, and always for the finished report. Spell and item
    data load asynchronously, so the IDs go through in batches of a hundred:
    each batch is requested, then polled until every row in it has settled,
    and only then does the next one start. A progress line stands in until the
    finished TSV replaces it. A second press restarts the section, and turning
    the tools off stops it and clears its progress line.
]]
function ns.RunDataValidation(index, field, onUpdate)
	local spellRows, itemRows, otherRows = CollectValidationRows(ns.DIAGNOSTIC_DATA_SOURCES[index])

	ns.diagnostics.validationRuns = ns.diagnostics.validationRuns or {}
	local runs = ns.diagnostics.validationRuns
	local run = {}
	runs[index] = run

	local queue = {}
	for _, rows in ipairs({ spellRows, itemRows }) do
		for _, row in ipairs(rows) do
			queue[#queue + 1] = row
		end
	end
	local batches = math.ceil(#queue / VALIDATE_BATCH_SIZE)
	local first, idlePolls = 1, 0
	local lastPaint

	local function Step()
		if runs[index] ~= run then
			return
		end
		if not ns.diagnostics.enabled then
			runs[index] = nil
			ns.diagnostics[field] = nil
			return
		end

		local last = math.min(first + VALIDATE_BATCH_SIZE - 1, #queue)
		local pending, settledAny = 0, false
		for position = first, last do
			local row = queue[position]
			if not row.cells then
				local ok, status = pcall(PollRow, row)
				if not ok then
					row.cells = ErrorCells(row, status)
				elseif status then
					SettleRow(row, status)
				end
				if row.cells then
					settledAny = true
				else
					pending = pending + 1
				end
			end
		end

		if pending > 0 then
			idlePolls = settledAny and 0 or idlePolls + 1
			if idlePolls >= VALIDATE_MAX_IDLE_POLLS then
				-- A straggler that loaded far enough to draw a tooltip is incomplete; one that never loaded is missing.
				for position = first, last do
					local row = queue[position]
					if not row.cells then
						SettleRow(row, row.tooltip and "INCOMPLETE" or "NOT ON CLIENT")
					end
				end
				pending = 0
			elseif idlePolls > 0 and idlePolls % VALIDATE_RETRY_POLLS == 0 then
				for position = first, last do
					if not queue[position].cells then
						pcall(RequestRowData, queue[position])
					end
				end
			end
		end

		if pending == 0 then
			first, idlePolls = last + 1, 0
			if first > #queue then
				runs[index] = nil
				ns.diagnostics[field] = BuildValidationReport(spellRows, itemRows, otherRows)
				onUpdate()
				return
			end
		end

		ns.diagnostics[field] = GetClientHeader()
			.. "\n\n"
			.. string.format(
				ns.DiagnosticsStrings.VALIDATE_PROGRESS,
				WithCommas(last - pending),
				WithCommas(#queue),
				math.ceil(first / VALIDATE_BATCH_SIZE),
				batches
			)
		local now = GetTime()
		if not lastPaint or now - lastPaint >= VALIDATE_REPAINT_SECONDS then
			lastPaint = now
			onUpdate()
		end
		C_Timer.After(pending == 0 and 0 or VALIDATE_POLL_SECONDS, Step)
	end

	Step()
end

--------------------------------------------------------------------------------
-- Taint Log
--------------------------------------------------------------------------------

--[[
    The taintLog CVar controls UI taint logging to Logs\taint.log. Level 2 logs
    both blocked actions and accesses to tainted globals; 0 is off. This is the
    only state the diagnostics panel ever writes.
]]

function ns.GetTaintLogState()
	return tonumber(GetCVar("taintLog")) or 0
end

function ns.SetTaintLog(enabled)
	SetCVar("taintLog", enabled and 2 or 0)
end
