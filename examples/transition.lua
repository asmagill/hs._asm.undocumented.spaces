--[[

    DO NOT USE THIS BEFORE READING THE README.md and RawAccess.md FILES.

    If you just want an example of things that can be done with this module,
    the `init.lua` file of this module is a better, safer file to examine first.
    This example can easily make your display very weird and hard to view if
    modified incorrectly.

    This is an example of using the space transformation function for animating
    space changes.  The transform function use matrix based math for handling
    the space animation.  A full treatment of Matrix mathematics is beyond the
    scope of this example or documentation.  A quick google search for "2D
    transformation matrix" will provide many examples, if you are new to the
    concept.  Also check out Apple's CGAffineTransform Reference, at
    https://developer.apple.com/library/mac/documentation/GraphicsImaging/Reference/CGAffineTransform/
    especially the section about the CGAffineTransform data type.

    This is quick and dirty... I suspect it could be made cleaner and/or
    smoother.

    I do not know why some windows don't seem to fully behave until
    the space is at least a certain size -- perhaps its a limitation of windows
    with a minimum sized bounding box.

    I don't know why windows which are not normal in some way (hs.drawing
    window behaviors of canJoinAllSpaces or moveToActiveSpace especially) behave
    oddly -- perhaps like the Dock and Notification center, they exist in a
    "different space".

    That's what experimentation and the raw function access is for -- trying to
    figure out together that which Apple doesn't want to fully explain or
    document.

    I have not (yet) tested this on a multi monitor setup yet, but I have tried to
    make it safe for multi-monitor setups.  I *think* the only portion which
    *might* be wrong is the calculation of the translation portion of the matrix
    transform but you have been warned.

    For this example, pass in up to two arguments:  the space ID to transition
    to and an optional boolean argument indicating whether or not to reset the
    Dock after completing the transformation to make the change "stick". Defaults
    to true.  See the documentation for hs._asm.undocumented.spaces for an
    explanation of the reason for this argument.

    Usage -- Copy this file into your ~/.hammerspoon folder and then:
    > t = dofile("transition.lua")
    > t.transition(spaceID [, toggle]) -- change to the specified spaceID
    > t.reset() -- reset to a (presumably) safe state if something goes wrong

--]]

-- we get the internal, "raw" functions so we can bypass the need for the user
-- to have previously enabled them.  Check out the RawAccess.md file for more
-- information
local s = require("hs._asm.undocumented.spaces")
local si = require("hs._asm.undocumented.spaces.internal")


local fnutils = require("hs.fnutils")
local timer   = require("hs.timer")
local screen  = require("hs.screen")

local module = {}

module.transition = function(spaceID, reset)
    if type(reset) ~= "boolean" then reset = true end
    if spaceID == nil then
        error("You must specify a spaceID to transition to", 2)
    end

    -- keep it at least a little safe...
    if not fnutils.find(s.query(), function(_) return _ == spaceID end) then
        error("You can only change to a user accessible space", 2)
    end

    local targetScreenUUID = s.spaceScreenUUID(spaceID)
    local startingSpace = -1
    for i,v in ipairs(s.query(s.masks.currentSpaces)) do
        if s.spaceScreenUUID(v) == targetScreenUUID then
            startingSpace = v
            break
        end
    end
    if startingSpace == -1 then
        error("Unable to determine active space for the destination specified", 2)
    end
    if startingSpace == spaceID then
        error("Already on the destination space", 2)
    end

    local targetScreen = nil
    for i,v in ipairs(screen.allScreens()) do
        if v:spacesUUID() == targetScreenUUID then
            targetScreen = v
            break
        end
    end
    if not targetScreen then
        error("Unable to get screen object for destination specified", 2)
    end

    if si.screenUUIDisAnimating(targetScreenUUID) then
        error("Specified screen is already in an animation sequence", 2)
    end

    -- Begin actual space animation stuff.  We're attempting to "shrink" the active
    -- space into the upper left corner, and "grow" the new space from the lower
    -- right one... it seemed simpler than dealing with rotation and the matrix
    -- math that implies, but different enough from the "stock" animation to
    -- show what can be done.

    local state = 1
    local screenFrame = targetScreen:fullFrame()
--     print(spaceID, startingSpace)

    si.showSpaces({spaceID, startingSpace})
    si.setScreenUUIDisAnimating(targetScreenUUID, true)
    module.activeTimer = timer.new(0.1, function()
        if state == 10 then
            module.activeTimer:stop()
            module.activeTimer = nil
            si.spaceTransform(startingSpace, nil)
            si.hideSpaces(startingSpace)
            si.spaceTransform(spaceID, nil)
            si._changeToSpace(spaceID) -- has an implicit show
            si.setScreenUUIDisAnimating(targetScreenUUID, false)
            if reset then hs.execute("killall Dock") end
        else
            local hDelta = -1 * screenFrame.h * (10 - state)
            local wDelta = -1 * screenFrame.w * (10 - state)
--             print(screenFrame.h, screenFrame.w, hDelta,wDelta)
            si.spaceTransform(spaceID, { 11 - state, 0, 0, 11 - state, wDelta, hDelta })
            si.spaceTransform(startingSpace, { state + 1, 0, 0, state + 1, 0, 0 })
        end
        state = state + 1
    end):start()
    return module.activeTimer
end

-- attempt to reset into a "stable" state if things go awry. We pick an
-- arbitrary user space on each monitor, show them, hide all others, reset
-- transforms to the identity matrix, toggle the animation flag to off
-- and reset the dock.
module.reset = function()
    for k,v in pairs(s.spacesByScreenUUID()) do
        local first = true
        for a,b in ipairs(v) do
            if first and si.spaceType(b) == s.types.user then
                si.showSpaces(b)
                si._changeToSpace(b)
                first = false
            else
                si.hideSpaces(b)
            end
            si.spaceTransform(b, nil)
        end
        si.setScreenUUIDisAnimating(k, false)
    end
    hs.execute("killall Dock")
end

return module
