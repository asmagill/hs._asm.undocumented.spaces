Raw Access to the Spaces API
============================

This document describes the low level functions defined within this module.  These functions are (mostly) not wrapped and can modify your running system in ways that are unexpected and/or unusable.  They are disabled (hidden) by default.

As always, I make no claims of usability, safety, success, or general usefulness of these functions.  I am not responsible for anything that does or does not happen to you, your computer, your family dog, your home, or anything at all, really, caused or not caused by the use or non-use of these functions.

In my experimentation, I was always able to return to a usable state by the following steps:
1. Change to another space by one of the "normal" methods (either the keyboard shortcuts, CTRL-#, or trackpad gestures.)
2. `hs.execute('killall Dock')`

You can also add the following to your `init.lua` file as a "safety" reset, which seems to work well for me if you can get to the console or a terminal and use the `hs` command... it basically picks an arbitrary space for each monitor, shows it, hides the others, resets all transforms, and restarts the Dock.

~~~lua
resetSpaces = function()
    local s = require("hs._asm.undocumented.spaces")
    -- bypass check for raw function access
    local si = require("hs._asm.undocumented.spaces.internal")
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
~~~

If that wasn't sufficient, logging out and/or rebooting the computer always work.

As freaky and odd as some of the results of these functions are, I decided to include them, rather than leave them solely in the Objective-C portion of the module or undefined at all because I believe in experimentation, and because they suggest some interesting possibilities, such as translating spaces in odd ways (rotation, inversion, etc.) and rendering multiple spaces on the screen at the same time (e.g. replicating *Mission Control*).

Ultimately if/how you use them is your responsibility, and make no promises, but I would love to see your work, so leave feedback!

### Enabling Raw Functions

To enable access from Hammerspoon to these functions, use the following code snippit:

~~~lua
hs.settings.set("_ASMundocumentedSpacesRaw", true)
spaces = require("hs._asm.undocumented.spaces")
~~~

You can disable access by setting `_ASMundocumentedSpacesRaw` to false or clearing it entirely and reloading/restarting Hammerspoon.

### Sub-Module functions

By default the module provides functions which I *mostly* understand and have found to be useful and/or usable.  This list contains functions which are... less clear.  I have included what thoughts or notes I have discovered, but you are on your own -- I know very little about these that isn't described in this document, and while I'm willing to help and test things out as you experiment, I do not work for Apple and have no hidden insights!  I would love to here about what you do discover, however, so feel free to post issues to this repository.

There are a few functions which have a corresponding set API function which has not yet been added.  Mostly this was due to laziness or not coming up with even a theoretical reason they might be useful.  However, I will note such in the documentation; it should be fairly straightforward to add such functionality if a use is discovered.

- - -

~~~lua
spaces.raw.activeSpace() -> spaceID
~~~
Same as `spaces.activeSpace()`.

- - -

~~~lua
spaces.raw._changeToSpace(spaceID) -> None
~~~
Changes to the specified `spaceID`.  *Any* spaceID.  No check is done to ensure that the space is one the user can usually access or even that the space exists (i.e. has been specifically designated for use by the system in some way -- see `query`).  This function seems to show the specified space (but does not hide the current one first) and make it active in the sense that it takes mouse and keyboard events, generating a window list via `hs.window.allWindows` seems to be limited to windows on *all* spaces or that space specifically, etc.

Various system items, such as the Dock, Exposé, etc. seem to use spaces for some of their elements, but this is poorly understood.

Does not take a boolean flag to reset the Dock for you.

- - -

~~~lua
spaces.raw.createSpace([screenUUID]) -> spaceID
~~~
Similar to `spaces.createSpace` except that it can't restart the Dock process for you.  The Objective-C definition for this function is hard coded to set the type to a user accessible type... it would be simple to modify this to take a parameter indicating the space type, but didn't see a reason to at the time.

The `screenUUID` is verified to be accurate because if it isn't, the dictionary defining the space type and spaceUUID is ignored if it isn't; however, I have not yet been able to cause this to make a new space on a monitor which isn't currently the primary display, so I'm not sure *why* it requires a valid screenUUID -- as long as the screenUUID is valid, a new user space is created on the primary monitor, even if the UUID is for a different monitor.

- - -

~~~lua
spaces.raw.details() -> table
~~~
Similar to `spaces.debug.layout()` except that it returns its results as a table.

- - -

~~~lua
spaces.raw.disableUpdates() -> None
~~~
Tells the window server to pause updating the display for up to one second, or until a `spaces.raw.enableUpdates()` command is issued, whichever comes first.  This is used to try and make multiple changes appear as one by keeping the system from updating the screen until all of the changes are completed.  If you do not pair this with `spaces.raw.enableUpdates()` or take longer than a second before issuing the followup command, the Console application will contain messages indicating such.

I may ultimately add this to `hs.drawing` as it could have uses there as well.

- - -

~~~lua
spaces.raw.enableUpdates() -> None
~~~
Tells the window server to resume its normal update processes. See `spaces.raw.disableUpdates`.

- - -

~~~lua
spaces.raw.hideSpaces(spaceID | table) -> None
~~~
Takes a spaceID or table containing spaceIDs and stops displaying them.  If a space is not currently being displayed, this has no effect on it.

- - -

~~~lua
spaces.raw.mainScreenUUID() -> string
~~~
Returns the screenUUID for the primary display.  In single monitor setups, this may return a more descriptive string than a traditional UUID, but since this "shorter" value isn't accepted as a valid argument by the createSpace function, it is wrapped in the companion version at `spaces.mainScreenUUID` to ensure its value is always valid.

- - -

~~~lua
spaces.raw.query(mask) -> table
~~~
Similar to `spaces.query` but without the default mask or boolean flag for predefined values.

- - -

~~~lua
spaces.raw._removeSpace(spaceID) -> None
~~~
Similar to `spaces.removeSpace` but isn't wrapped to limit removal to non-active and user spaces and doesn't accept a boolean flag to reset the Dock for you.

- - -

~~~lua
spaces.raw.screensHaveSeparateSpaces() -> boolean
~~~
Similar to `spaces.screensHaveSeparateSpaces`

- - -

~~~lua
spaces.raw.screenUUIDisAnimating(screenUUID) -> boolean
~~~
Returns whether the display specified by the given screenUUID is currently undergoing space-change animation.  Because this will crash Hammerspoon if an incorrect UUID is provided, it does check to make sure that the UUID is valid first.

- - -

~~~lua
spaces.raw.setScreenUUIDisAnimating(screenUUID, flag) -> boolean
~~~
Sets the flag indicating whether or not the specified screen is currently animating.  No check is done on whether or not animation is really occurring, so this is primarily so you can "play nice" and "do the right thing" when writing your own animation sequences with `spaces.raw.spaceTransform` and the like.

Returns whether the display specified by the given screenUUID is currently undergoing space-change animation so you can verify (if desired) that the flag change has taken effect.

- - -

~~~lua
spaces.raw.showSpaces(spaceID | table) -> None
~~~
Makes the specified spaces visible.  Note that while multiple spaces can be made visible, there is still only one active space (the space returned by `activeSpace`, and if you haven't changed the space levels with `spaces.raw.spaceLevel` or moved them in some way with `spaces.raw.spaceTransform`, the other spaces may not actually be visible to the user.

`spaces.query(spaces.masks.current)` will include all spaces which are made visible by this function.

- - -

~~~lua
spaces.raw.spaceCompatID(spaceID) -> integer
~~~
Returns the spaces value for `compatID`.  Uncertain purpose or use.

The API also provides a function for setting this value, but it has not been implemented in this module at present.  It would not be difficult to do so, but I've seen no reason at present.

- - -

~~~lua
spaces.raw.spaceLevel(spaceID, [level]) -> level
~~~
Get or set the spaces level relative to other spaces.  Returns the (possibly changed) current level.  Use this when displaying multiple spaces or when you wish to hide a space change (see the code for `spaces.changeToSpace` in `init.lua`) in the background.  Note that this can cause the space to appear above some system elements.

- - -

~~~lua
spaces.raw.spaceManagedShape(spaceID) -> table | nil
~~~
Uncertain purpose or use.  Always returns the dimensions of the monitor on which the space is displayed on my machine.

Unlike `spaces.raw.spaceShape`, this does not appear to have a set function defined in the API, unless the two are related in a way not understood at present.

See the `CGSRegion.h` file for more details about the data structure returned.

- - -

~~~lua
spaces.raw.spaceName(spaceID) -> spaceUUID
~~~
Same as `spaces.spaceName`.

The API also provides a function for setting this value, but it has not been implemented in this module at present.  It would not be difficult to do so, but I've seen no reason at present, as this name change does not appear to affect anything (certainly not the space name displayed in Mission Control).

- - -

~~~lua
spaces.raw.spaceOwners(spaceID) -> table
~~~
Same as `spaces.spaceOwners`.

- - -

~~~lua
spaces.raw.spaceScreenUUID(spaceID) -> screenUUID
~~~
Same as `spaces.spaceScreenUUID`.

- - -

~~~lua
spaces.raw.spaceShape(spaceID) -> table | nil
~~~
Uncertain purpose or use.  Always returns nil on my machine.

The API also provides a function for setting this value, but it has not been implemented in this module at present.  It would not be difficult to do so, but I've seen no reason at present.

See also `spaces.raw.spaceManagedShape`.

- - -

~~~lua
spaces.raw.spaceType(spaceID) -> integer
~~~
Same as `spaces.spaceType`.

- - -

~~~lua
spaces.raw.spaceTransform(spaceID, [table | nil ]) -> table
~~~
Gets or sets the CGAffineTransform for the specified space.  If the second value is nil, resets the space's transform to the identity (i.e. returns it to its normal position and orientation).

To set the table's transform, provide the 6 elements require for CGAffineTransform in the table.  The six elements of the table { a, b, c, d, tx, ty } correspond to the following in *Matrix-transform-speak*:

    [ a  b  0 ]
    [ c  d  0 ]
    [ tx ty 1 ]

You can resize, move, and rotate a space by using the appropriate Matrix transformation algorithms on these values.  A discussion of this is outside the scope of this document.  Check out Google and Apple's documentation at https://developer.apple.com/library/mac/documentation/GraphicsImaging/Reference/CGAffineTransform/, especially the section about [the CGAffineTransform data type](https://developer.apple.com/library/mac/documentation/GraphicsImaging/Reference/CGAffineTransform/#//apple_ref/c/tdef/CGAffineTransform).

- - -

~~~lua
spaces.raw.spaceValues(spaceID) -> table
~~~
Gets the defined values for the space and returns them in a table.  Most of these can also be retrieved via other functions, but occasionally you'll see something new or unexpected.

The API also provides a function for setting these values, but it has not been implemented in this module at present.  It would not be difficult to do so, but I've seen no reason at present.

- - -

~~~lua
spaces.raw.UUIDforScreen(hs.screen object) -> screenUUID
~~~
Used as the helper function for the `hs.screen:spacesUUID` addition.

- - -

~~~lua
spaces.raw.windowsAddTo(windowID, spaceID) -> None
~~~
Puts the window(s) specified by the windowID (or table of windowIDs) onto the space(s) specified by the spaceID (or table of spaceIDs).

The `spaces.moveWindowToSpace` wraps this to allow you to specify only one space, but in theory, a window can be placed on some, but not all spaces.  I do not know what affect this might have on the functions and methods within `hs.window` or the system in general.

- - -

~~~lua
spaces.raw.windowsOnSpaces(windowID) -> table
~~~
Returns an array of spaces on which any of the windowIDs specified are found on.  `windowID` can be a number or an array of windowIDs.  Note that a space which contains any of the specified windowIDs will be included... it is not possible to determine which windowID caused which spaceID to be included, which is why the wrapped version `spaces.windowOnSpaces` limits you to one windowID.

- - -

~~~lua
spaces.raw.windowsRemoveFrom(windowID, spaceID) -> None
~~~
Removes the window(s) specified by the windowID (or table of windowIDs) from the space(s) specified by the spaceID (or table of spaceIDs).

I do not know what affect removing a window from *all* spaces will have on the functions and methods within `hs.window` or the system in general, but it is possible.

- - -

### License

> Released under MIT license.
>
> Copyright (c) 2015 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
