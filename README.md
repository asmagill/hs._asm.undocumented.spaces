_asm.undocumented.spaces
========================

This module provides Hammerspoon with access to the undocumented Spaces API.  For backwards compatibility, it replicates the original legacy functions from the Hammerspoon precursors, [Hydra and Mjolnir](https://www.github.com/sdegutis)'s module of the same name, but also provides more direct access to the available functions.

Most of the Spaces API detail in this module comes from [NUIKit/CGSInternal](https://github.com/NUIKit/CGSInternal) with a few changes made to include some functions found in previous incarnations of this module and other Google searches.

I make no promises that these will work for you or work at all with any, past, current, or future versions of OS X.  I can confirm only that they didn't crash my machine during testing under 10.11. You have been warned.

### Installation

Compiled versions of this module can be found in the releases.  You can download the release and install it by expanding it in your `~/.hammerspoon/` directory (or any other directory in your `package.path` and `package.cpath` search paths):

~~~sh
cd ~/.hammerspoon
tar -xzf ~/Downloads/spaces-vX.Y.tar.gz # or wherever your downloads are saved
~~~

If this doesn't work for you, or you want to build the latest and greatest, follow the directions below:

This does require that you have XCode or the XCode Command Line Tools installed.  See the App Store application or https://developer.apple.com to install these if necessary.

~~~sh
$ git clone https://github.com/asmagill/hs._asm.undocumented.spaces spaces
$ cd spaces
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make install
~~~

If Hammerspoon.app is in your /Applications folder, you may leave `HS_APPLICATION=/Applications` out and if you are fine with the module being installed in your Hammerspoon configuration directory, you may leave `PREFIX=~/.hammerspoon` out as well.  For most people, it will probably be sufficient to just type `make install`.

In either case, if you are upgrading over a previous installation of this module, you must completely quit and restart Hammerspoon before the new version will be fully recognized.

### Require

~~~lua
spaces = require("hs._asm.undocumented.spaces")
~~~

### Module Functions

- - -

~~~lua
spaces.activeSpace() -> spaceID
~~~
Returns the ID of the currently active space.

Parameters:
 * None

Returns:
 * the numeric ID of the currently active space

Notes:
 * In a multi-monitor setup, this will return the ID of the active space on the primary screen.

- - -

~~~lua
spaces.allWindowsForSpace(spaceID) -> windowObjectArray
~~~
Returns an array of the `hs.window` objects for each window on the specified space.

Parameters:
 * spaceID - the ID of the space to check

Returns:
 * an array of the `hs.window` objects for windows found on the specified space

Notes:
 * This function works by silently changing to the specified space and looking at the windows which are present.  This will trigger any space watcher you may have in effect with `hs.screen.watcher`.

- - -

~~~lua
spaces.changeToSpace(spaceID, [resetDock]) -> spacesIDArray
~~~
Change to the space specified.

Parameters:
 * spaceID - the ID of the space to change to
 * resetDock - an optional boolean flag which indicates whether or not the Dock should be reset after performing the space change.  Defaults to true.

Returns:
 * an array of the space IDs currently being displayed.

Notes:
 * If you do not reset the dock, subsequent attempts to change the space using keyboard shortcuts, trackpad gestures, etc. will cause the same behavior observed with the deprecated `hs._asm.undocumented.spaces.moveToSpace`.  However, it may be more convienent to hold off on this under certain circumstances, like changing the space for multiple displays.

- - -

~~~lua
spaces.createSpace([screenUUID], [resetDock]) -> spaceID
~~~
Creates a new user space.

***NOTE: This isn't currently working correctly with multi-monitor setups under OS X 10.11 -- no matter which UUID you provide, it only creates new spaces on the currently active display.  I would appreciate any feedback for 10.10 or earlier. I hope to have a fix or work-around soon.***

Parameters:
 * screenUUID - an options string specifying the UUID of the monitor/screen on which the new space should be created.  Defaults to the current primary screen.
 * resetDock - an optional boolean flag which indicates whether or not the Dock should be reset after adding the new space.  Defaults to true.

Returns:
 * the ID of the new space created

Notes:
 * If you do not reset the dock, the new spaces will not be accessible.  However, it may be more convienent to hold off on this under certain circumstances, like creating multiple spaces.

- - -

~~~lua
spaces.isAnimating([screen]) -> bool
~~~
Returns the state of space changing animation for the specified monitor, or for any monitor if no parameter is specified.

Parameters:
 * screen - an optional `hs.screen` object specifying the specific monitor to check the animation status for.

Returns:
 * a boolean value indicating whether or not a space changing animation is currently active.

Notes:
 * This function can be used in `hs.eventtap` based space changing functions to determine when to release the mouse and key events.
 * This function is also added to the `hs.screen` object metatable so that you can check a specific screen's animation status with `hs.screen:spacesAnimating()`.

- - -

~~~lua
spaces.layout() -> table
~~~
Returns a table of the user accessible spaces for, separated by Screen (Display), in order.

Parameters:
 * None

Returns:
 * a table whose keys are the screenUUID of the available screens.  Each key's value is an array of the spaces on that display, list in the order in which they are currently arranged.

Notes:
 * to determine which spaces are currently visible on each screen, use `hs._asm.undocumented.spaces.query(hs._asm.undocumented.spaces.masks.currentSpaces)`.
- - -

~~~lua
spaces.mainScreenUUID() -> UUIDString
~~~
Returns the UUID for the primary monitor/screen.

Parameters:
 * None

Returns:
 * the UUIDString for the primary monitor/screen.

- - -

~~~lua
spaces.moveWindowToSpace(windowID, spaceID) -> spaceID
~~~
Moves the specified window to the specified space.

Parameters:
 * windowID - the window ID to move
 * spaceID the ID of the space to move the window to

Returns:
 * the spaceID where the window currently is.

Notes:
 * You can only move windows which are only on one space.
 * You can only move a window to a user space.
 * The location of the window on the screen is not affected -- if your displays have separate spaces and you move a window to a space on another monitor, you will need to also reposition it with `hs.window:setTopLeft` or it will be offscreen.
 * This function is also added to the `hs.window` object metatable so that you can move a window with `hs.window:spacesMoveTo(spaceID)`, except that the return value is the windowObject to facilitate method chaining.

- - -

~~~lua
spaces.query([mask], [flatten]) -> spacesIDArray
~~~
Returns an array of screen IDs which match the provided mask.

Parameters:
 * mask - a numeric mask from the flags in `hs._asm.undocumented.spaces.masks` indicating the spaces to return IDs for.  Defaults to `hs._asm.undocumented.spaces.masks.allSpaces`.
 * flatten - optional boolean indicating whether duplicate space IDs should be removed.  Defaults to true.

Returns:
 * an array of space IDs which match the provided mask.

Notes:
 * Fullscreen/Tiled spaces may appear multiple times in the list if you set `flatten` to false.
 * Internally, OS X uses spaces for some UI elements, like the Dock, Expose, the Notification Center, etc.  Because manipulating these directly can have unexpected results, these functions attempt to prevent access to these spaces.  It is possible to find them with this query, however.

- - -

~~~lua
spaces.removeSpace(spaceID, [resetDock]) -> none
~~~
Removes a user space.

Parameters:
 * spaceID - the ID of the space to remove
 * resetDock - an optional boolean flag which indicates whether or not the Dock should be reset after removing the space.  Defaults to true.

Returns:
 * None

Notes:
 * You can only remove user spaces, not full screen applications or system spaces.
 * Windows that only appear on the window to be removed will be silently moved to the currently visible space of the relevant display (screen).
 * If you do not reset the dock, the space will not be removed from Mission Control. This may cause unexpected behavior as the internal type of the space will have changed. However, it may be more convienent to hold off on this under certain circumstances, like removing multiple spaces.

- - -

~~~lua
spaces.screensHaveSeparateSpaces() -> boolean
~~~
Determine if the user has enabled the "Displays Have Separate Spaces" option within Mission Control.

Parameters:
 * None

Returns:
 * a boolean value indicating the status of the "Displays Have Separate Spaces" checkbox in Mission Control.

Notes:
 * This function uses standard OS X APIs and is not likely to be affected by updates or patches.

- - -

~~~lua
spaces.spaceName(spaceID) -> spaceName
~~~
Returns the UUID or name of the specified space.

Parameters:
 * spaceID - the space whose name you wish to get

Returns:
 * the internal name for the space, usually in the form of a UUID string.

- - -

~~~lua
spaces.spaceOwners(spaceID) -> ownersArray
~~~
Returns an array of the process IDs of any application(s) which own the space.  A space is "owned" if it is a fullscreen application space or a tiled space.

Paramters:
 * spaceID - the space you wish to get the owners of.

Returns:
 * an array of owner process IDs

Notes:
 * This will be an empty array for user spaces.

- - -

~~~lua
spaces.spaceScreenUUID(spaceID) -> UUIDString
~~~
Returns the UUID of the screen the specified space belongs to.

Parameters:
 * spaceID - the ID of the space you wish to get the screen UUID for.

Returns:
 * the UUID of the screen for the specified space

- - -

~~~lua
spaces.spaceType(ID) -> screenType
~~~
Returns the type of the space.

Parameters:
 * spaceID - the space whose type you wish to get

Returns:
 * the type of the space as a number which can be looked up in `hs._asm.undocumented.spaces.types`

- - -

~~~lua
spaces.spacesByScreenUUID([mask]) -> table
~~~
Returns a table of the specified spaces, separated by Screen (Display).

Parameters:
 * mask - an optional mask indicating the types of spaces to include in the results.  Defaults to `hs._asm.undocumented.spaces.types.allSpaces`.

Returns:
 * a table whose keys are the screenUUID of the available screens.  Each key's value is an array of the spaces on that display.

- - -

~~~lua
spaces.windowOnSpaces(windowID) -> spacesArray
~~~
Returns an array of the spaceIDs the specified window ID is shown on.

Parameters:
 * the windowID of the window to return spaces for

Returns:
 * an array containing the space IDs that the specified window is shown on.

Notes:
 * This function is also added to the `hs.window` object metatable so that you can get the array of spaces with `hs.window:spaces()`.

### Module Constants

- - -

~~~lua
spaces.masks
~~~
Contains pre-defined masks for identifying space types for use with `hs._asm.undocumented.spaces.query`.

| Key             | Purpose                                           |
|:----------------|:--------------------------------------------------|
| allSpaces       | all user accessible spaces                        |
| currentSpaces   | the currently active user spaces                  |
| otherSpaces     | user spaces which are currently not active        |
|                 |                                                   |
| allOSSpaces     | spaces used by OS X for things like Exposé, etc.  |
| currentOSSpaces | OS X on-screen spaces (Notification Center, etc.) |
| otherOSSpaces   | other OS X spaces                                 |

The OS spaces are not directly accessible to these functions, but they are used internally.

- - -

~~~lua
spaces.types
~~~
Contains the currently known space types, which are returned by `hs._asm.undocumented.spaces.spaceType`.

| Key        | Purpose                                         |
|:-----------|:------------------------------------------------|
| fullscreen | Full screen application space                   |
| user       | User spaces                                     |
| system     | Spaces managed by the OS, including Dashboard   |
| tiled      | Tiled fullscreen application space              |
| unknown    | Un-identified system use space (deleted space?) |

OS X El Capitan uses the `tiled` type for both single application fullscreen application spaces and for split fullscreen application spaces.  I am not sure what OS X Yosemite uses.

Other space types have also been seen, but I have not had a chance to identify what they are yet.  I suspect at least 2 of them have to do with split screen tiling under OS X El Capitan.

* * *

#### Additions to other modules

~~~lua
hs.screen:spaces() -> spacesArray
~~~
A Convienence method added to the `hs.screen` object metatable to get the IDs of all spaces on the screen represented by the `hs.screen` object.

~~~lua
hs.screen:spacesUUID() -> screenUUID
~~~
A Convienence method added to the `hs.screen` object metatable to get the UUID string of the screen specified by the `hs.screen` object.

~~~lua
hs.screen:spacesAnimating() -> boolean
~~~
A Convienence method added to the `hs.screen` object metatable which returns a boolean indicating whether or not space change animation is occuring on the screen specified by the `hs.screen` object.

~~~lua
hs.window:spaces() -> spacesArray
~~~
A Convienence method added to the `hs.window` object metatable to get the IDs of all spaces the window represented by the `hs.window` object is shown on.

~~~lua
hs.window:spacesMoveTo(spaceID) -> windowObject
~~~
A Convienence method using `hs._asm.spaces.moveWindowToSpace` added to the `hs.window` object metatable to move the window specified by the `hs.window` object to the specified space.

* * *

### Sub-Modules

#### `spaces.debug`

This sub module contains functions which report a lot of detail about the spaces on your system.  It is probably not that useful in a production environment, but may be helpfull when trying to extend this module or troubleshooting when things don't work.

If you do submit an issue to this repository, I may ask for information provided by one or more of these functions.  Feel free to review the output and replace anything you think might be sensitive such as file paths or usernames with something like `*********`.

- - -

~~~lua
spaces.debug.layout() -> string
~~~
Returns some layout information about the user accessible spaces.

Parameters:
 * None

Returns:
 * The layout information

- - -

~~~lua
spaces.debug.report([mask]) -> string
~~~
Returns a full report for the spaces identified by the provided mask.

Parameters:
 * mask - an optional mask identifying the types of spaces to include in the report.  Defaults to all user accessible windows.

Returns:
 * The report

Notes:
 * If you provide a `mask` of `true`, instead of a number, it will use the mask value currently believed to include all user and system spaces.
 * If you provide a `mask` of `false`, instead of a number, it will use the mask value currently believed to have every possible bit flag enabled that doesn't supress, rather than include, spaces.

- - -

~~~lua
spaces.debug.spaceInfo(spaceID) -> string
~~~
Returns information about the specified space.

Parameters:
 * spaceID - the id of the space

Returns:
 * The details for the specified space.


* * *

#### `spaces.raw`

The functions described thus far in this document include protections to hopefully prevent anything unexpected or unstable from occuring.  The raw submodule provides direct access to the internal functions and should probably not be used unless you are working to extend this module.  Inclusion of these functions is disabled by default.

Documentation on these additional functions can be found in the `RawAccess.md` file.

* * *

### Legacy Functions

These functions are provide solely for backwards compatibility for those who were willing to use them, despite their problems.  These functions may disappear in the future (they were actually all broken in subtle ways from the get-go), and you are encouraged to move to the functions described above.

~~~lua
spaces.count() -> number
~~~
The number of spaces you currently have.

Notes:
 * this function may go away in a future update
 * this functions is included for backwards compatibility.  It is not recommended because it worked by indexing the spaces ignoring that fullscreen applications are included in the list twice, and only worked with one monitor.  Use `hs._asm.undocumented.spaces.query` or `hs._asm.undocumented.spaces.spacesByScreenUUID`.

~~~lua
spaces.currentSpace() -> number
~~~
The index of the space you're currently on, 1-indexed (as usual).

Notes:
 * this function may go away in a future update
 * this functions is included for backwards compatibility.  It is not recommended because it worked by indexing the spaces, which can be rearranged by the operating system anyways.  Use `hs._asm.undocumented.spaces.query` or `hs._asm.undocumented.spaces.spacesByScreenUUID`.

~~~lua
spaces.moveToSpace(number)
~~~
Switches to the space at the given index, 1-indexed (as usual).

Notes:
 * this function may go away in a future update
 * While this function will switch the visible space, attempts to change the space again via other methods (Keyboard shortcuts, Trackpad gestures, etc.) will immediately revert to the previous space (before this function was invoked) before acting on the new space change.  This can be mitigated by issuing `hs.execute("killall Dock")` after this function.  `hs._asm.undocumented.spaces.changeToSpace` takes an optional boolean flag to perform this Dock reset for you.
 * this functions is included for backwards compatibility.  It is not recommended because it was never really reliable and worked by indexing the spaces, which can be rearranged by the operating system anyways.  Use `hs._asm.undocumented.spaces.changeToSpace`.

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
