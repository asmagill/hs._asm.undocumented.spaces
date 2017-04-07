@import Cocoa ;
@import LuaSkin ;
#import "CGSSpace.h"

extern CGSConnectionID _CGSDefaultConnection(void);
#define CGSDefaultConnection _CGSDefaultConnection()

static int refTable ;

#pragma mark - Support Functions

BOOL isScreenUUIDValid(NSString *theDisplay) {
    BOOL isValid = NO ;
    for (NSScreen *screen in [NSScreen screens]) {
        CGDirectDisplayID cgID = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue] ;
        CFUUIDRef   theUUID    = CGDisplayCreateUUIDFromDisplayID(cgID) ;
        if (theUUID) {
            CFStringRef UUIDString = CFUUIDCreateString(kCFAllocatorDefault, theUUID) ;
            if (CFStringCompare((__bridge CFStringRef)theDisplay, UUIDString, kCFCompareCaseInsensitive) == kCFCompareEqualTo)
                isValid = YES ;
            CFRelease(UUIDString) ;
            CFRelease(theUUID) ;
            if (isValid) break ;
        }
    }
    return isValid ;
}

NSArray *getArrayFromNumberOrArray(lua_State *L, int idx) {
    NSMutableArray *theArray = [[NSMutableArray alloc] init] ;
    if (lua_type(L, idx) == LUA_TNUMBER)
        [theArray addObject:[NSNumber numberWithUnsignedLong:(CGSSpaceID)luaL_checkinteger(L, idx)]] ;
    else {
        for (int i = 0 ; i < luaL_len(L, idx) ; i++) {
            lua_rawgeti(L, idx, i + 1) ;
            [theArray addObject:[NSNumber numberWithUnsignedLong:(CGSSpaceID)luaL_checkinteger(L, -1)]] ;
            lua_pop(L, 1) ;
        }
    }
    return theArray ;
}

static int CGSRegionRefToLua(lua_State *L, CGSRegionRef theRegion) {
    if (theRegion) {
        lua_newtable(L) ;
          lua_pushboolean(L, CGSRegionIsEmpty(theRegion)) ;       lua_setfield(L, -2, "isEmpty") ;
          lua_pushboolean(L, CGSRegionIsRectangular(theRegion)) ; lua_setfield(L, -2, "isRect") ;
          CGRect theRect ;
//           if (CGSRegionIsRectangular(theRegion)) {
              CGError state = CGSGetRegionBounds(theRegion, &theRect) ;
              if (state != kCGErrorSuccess) {
                  lua_pushinteger(L, state) ; lua_setfield(L, -2, "error") ;
              } else {
                  lua_newtable(L) ;
                    lua_pushnumber(L, theRect.origin.x) ;    lua_setfield(L, -2, "x") ;
                    lua_pushnumber(L, theRect.origin.y) ;    lua_setfield(L, -2, "y") ;
                    lua_pushnumber(L, theRect.size.height) ; lua_setfield(L, -2, "h") ;
                    lua_pushnumber(L, theRect.size.width) ;  lua_setfield(L, -2, "w") ;
                  lua_setfield(L, -2, "bounds") ;
              }
//           }
          CGSRegionEnumeratorRef enumerator = CGSRegionEnumerator(theRegion) ;
          lua_newtable(L) ;
            if (enumerator) {
                CGRect *rectRef = NULL ;
                while((rectRef = CGSNextRect(enumerator))) {
                    lua_newtable(L) ;
                      lua_pushnumber(L, rectRef->origin.x) ;    lua_setfield(L, -2, "x") ;
                      lua_pushnumber(L, rectRef->origin.y) ;    lua_setfield(L, -2, "y") ;
                      lua_pushnumber(L, rectRef->size.height) ; lua_setfield(L, -2, "h") ;
                      lua_pushnumber(L, rectRef->size.width) ;  lua_setfield(L, -2, "w") ;
                    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
                }
                CGSReleaseRegionEnumerator(enumerator) ;
            }
          lua_setfield(L, -2, "rectangles") ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Functions

static int changeToSpace(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER, LS_TBREAK] ;
// Moved to lua for more flexibility
//     CGSHideSpaces(CGSDefaultConnection, (__bridge CFArrayRef)(@[@(CGSGetActiveSpace(CGSDefaultConnection))]));
//     CGSShowSpaces(CGSDefaultConnection, (__bridge CFArrayRef)(@[@(luaL_checkinteger(L, 1))]));
    CFStringRef display = CGSCopyManagedDisplayForSpace(CGSDefaultConnection, (CGSSpaceID)lua_tointeger(L, 1));
    CGSManagedDisplaySetCurrentSpace(CGSDefaultConnection, display, (CGSSpaceID)lua_tointeger(L, 1));
    CFRelease(display) ;
    return 0 ;
}

static int disableUpdates(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    NSDisableScreenUpdates() ;
    return 0 ;
}

static int enableUpdates(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    NSEnableScreenUpdates() ;
    return 0 ;
}

/// hs._asm.undocumented.spaces.screensHaveSeparateSpaces() -> bool
/// Function
/// Determine if the user has enabled the "Displays Have Separate Spaces" option within Mission Control.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true or false representing the status of the "Displays Have Separate Spaces" option within Mission Control.
///
/// Notes:
///  * This function uses standard OS X APIs and is not likely to be affected by updates or patches.
static int screensHaveSeparateSpaces(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    lua_pushboolean(L, [NSScreen screensHaveSeparateSpaces]) ;
    return 1 ;
}

static int screenUUID(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, "hs.screen", LS_TBREAK] ;
    NSScreen *screen = (__bridge NSScreen*)*((void**)luaL_checkudata(L, 1, "hs.screen")) ;
    CGDirectDisplayID cgID = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue] ;
    CFUUIDRef   theUUID    = CGDisplayCreateUUIDFromDisplayID(cgID) ;
    if (theUUID) {
        CFStringRef UUIDString = CFUUIDCreateString(kCFAllocatorDefault, theUUID) ;
        [[LuaSkin shared] pushNSObject:(__bridge_transfer NSString *)UUIDString] ;
        CFRelease(theUUID) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int spaceOwners(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER, LS_TBREAK] ;
    CFArrayRef CGspaceOwners = CGSSpaceCopyOwners(CGSDefaultConnection, (CGSSpaceID)lua_tointeger(L, 1));
    [[LuaSkin shared] pushNSObject:(__bridge_transfer NSArray *)CGspaceOwners] ;
    return 1 ;
}

static int spaceType(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER, LS_TBREAK] ;
    lua_pushinteger(L, CGSSpaceGetType(CGSDefaultConnection, (CGSSpaceID)lua_tointeger(L, 1))) ;
    return 1 ;
}

static int spaceName(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER, LS_TBREAK] ;
    CFStringRef CGname = CGSSpaceCopyName(CGSDefaultConnection, (CGSSpaceID)lua_tointeger(L, 1));
    [[LuaSkin shared] pushNSObject:(__bridge_transfer NSString *)CGname] ;
    return 1 ;
}

static int spaceValues(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER, LS_TBREAK] ;
    CFDictionaryRef CGspaceValues = CGSSpaceCopyValues(CGSDefaultConnection, (CGSSpaceID)lua_tointeger(L, 1));
    [[LuaSkin shared] pushNSObject:(__bridge_transfer NSDictionary *)CGspaceValues] ;
    return 1 ;
}

static int spacesMasksTable(lua_State *L) {
    lua_newtable(L) ;
//       lua_pushinteger(L, CGSSpaceIncludesCurrent) ;  lua_setfield(L, -2, "CGSSpaceIncludesCurrent") ;
//       lua_pushinteger(L, CGSSpaceIncludesOthers) ;   lua_setfield(L, -2, "CGSSpaceIncludesOthers") ;
//       lua_pushinteger(L, CGSSpaceIncludesUser) ;     lua_setfield(L, -2, "CGSSpaceIncludesUser") ;
//       lua_pushinteger(L, CGSSpaceIncludesOS) ;       lua_setfield(L, -2, "CGSSpaceIncludesOS") ;
//       lua_pushinteger(L, CGSSpaceVisible) ;          lua_setfield(L, -2, "CGSSpaceVisible") ;
      lua_pushinteger(L, kCGSCurrentSpacesMask) ;    lua_setfield(L, -2, "currentSpaces") ;
      lua_pushinteger(L, kCGSOtherSpacesMask) ;      lua_setfield(L, -2, "otherSpaces") ;
      lua_pushinteger(L, kCGSAllSpacesMask) ;        lua_setfield(L, -2, "allSpaces") ;
      lua_pushinteger(L, kCGSCurrentOSSpacesMask) ;  lua_setfield(L, -2, "currentOSSpaces") ;
      lua_pushinteger(L, kCGSOtherOSSpacesMask) ;    lua_setfield(L, -2, "otherOSSpaces") ;
      lua_pushinteger(L, kCGSAllOSSpacesMask) ;      lua_setfield(L, -2, "allOSSpaces") ;
//       lua_pushinteger(L, kCGSAllVisibleSpacesMask) ; lua_setfield(L, -2, "kCGSAllVisibleSpacesMask") ;
    return 1 ;
}

static int spacesTypesTable(lua_State *L) {
    lua_newtable(L) ;
      lua_pushinteger(L, kCGSSpaceUser) ;       lua_setfield(L, -2, "user") ;
      lua_pushinteger(L, kCGSSpaceFullscreen) ; lua_setfield(L, -2, "fullscreen") ;
      lua_pushinteger(L, kCGSSpaceSystem) ;     lua_setfield(L, -2, "system") ;
      lua_pushinteger(L, kCGSSpaceUnknown) ;    lua_setfield(L, -2, "unknown") ;
      lua_pushinteger(L, kCGSSpaceTiled) ;      lua_setfield(L, -2, "tiled") ;
    return 1 ;
}

static int activeSpace(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    lua_pushinteger(L, (lua_Integer)CGSGetActiveSpace(CGSDefaultConnection)) ;
    return 1 ;
}

static int querySpaces(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER, LS_TBREAK] ;
    CFArrayRef CGspaces = CGSCopySpaces(CGSDefaultConnection, (CGSSpaceMask)(lua_tointeger(L, 1)));
    [[LuaSkin shared] pushNSObject:(__bridge_transfer NSArray *)CGspaces] ;
    return 1 ;
}

static int fullDetails(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    CFArrayRef CGmanagedDisplaySpaces = CGSCopyManagedDisplaySpaces(CGSDefaultConnection);
    [[LuaSkin shared] pushNSObject:(__bridge_transfer NSArray *)CGmanagedDisplaySpaces] ;
    return 1 ;
}

static int spaceScreenUUID(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER, LS_TBREAK] ;
    CFStringRef display = CGSCopyManagedDisplayForSpace(CGSDefaultConnection, (CGSSpaceID)lua_tointeger(L, 1));
    [[LuaSkin shared] pushNSObject:(__bridge_transfer NSArray *)display] ;
    return 1 ;
}

static int screenUUIDisAnimating(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *theDisplay = [[LuaSkin shared] toNSObjectAtIndex:1] ;
    BOOL isValid = isScreenUUIDValid(theDisplay) ;

    if (isValid)
        lua_pushboolean(L, CGSManagedDisplayIsAnimating(CGSDefaultConnection, (__bridge CFStringRef)theDisplay)) ;
    else
        luaL_error(L, "screenUUIDisAnimating: invalid screen UUID") ;
    return 1 ;
}

static int setScreenUUIDisAnimating(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TSTRING, LS_TBOOLEAN, LS_TBREAK] ;
    NSString *theDisplay = [[LuaSkin shared] toNSObjectAtIndex:1] ;
    BOOL isValid = isScreenUUIDValid(theDisplay) ;

    if (isValid) {
        CGSManagedDisplaySetIsAnimating(CGSDefaultConnection, (__bridge CFStringRef)theDisplay, lua_toboolean(L, 2)) ;

        lua_pushboolean(L, CGSManagedDisplayIsAnimating(CGSDefaultConnection, (__bridge CFStringRef)theDisplay)) ;
    } else {
        luaL_error(L, "setScreenUUIDisAnimating: invalid screen UUID") ;
    }
    return 1 ;
}

static int mainScreenUUID(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    [[LuaSkin shared] pushNSObject:(__bridge NSString *) kCGSPackagesMainDisplayIdentifier] ;
    return 1 ;
}

static int spaceLevel(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_type(L, 2) != LUA_TNONE) {
        CGSSpaceSetAbsoluteLevel(CGSDefaultConnection, (CGSSpaceID)lua_tointeger(L, 1), (int)lua_tointeger(L, 2)) ;
    }

    lua_pushinteger(L, CGSSpaceGetAbsoluteLevel(CGSDefaultConnection, (CGSSpaceID)lua_tointeger(L, 1))) ;
    return 1 ;
}

static int spaceCompatID(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER, LS_TBREAK] ;
    lua_pushinteger(L, CGSSpaceGetCompatID(CGSDefaultConnection, (CGSSpaceID)lua_tointeger(L, 1))) ;
    return 1 ;
}

static int spaceTransform(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER,
                                LS_TTABLE | LS_TNIL | LS_TOPTIONAL,
                                LS_TBREAK] ;

    if (lua_type(L, 2) != LUA_TNONE) {
        CGAffineTransform trans = CGAffineTransformMakeScale(1, 1) ;

        if (lua_type(L, 2) == LUA_TTABLE) {
            if (lua_rawgeti(L, 2, 1) == LUA_TNUMBER) trans.a  = lua_tonumber(L, -1) ; lua_pop(L, 1) ;
            if (lua_rawgeti(L, 2, 2) == LUA_TNUMBER) trans.b  = lua_tonumber(L, -1) ; lua_pop(L, 1) ;
            if (lua_rawgeti(L, 2, 3) == LUA_TNUMBER) trans.c  = lua_tonumber(L, -1) ; lua_pop(L, 1) ;
            if (lua_rawgeti(L, 2, 4) == LUA_TNUMBER) trans.d  = lua_tonumber(L, -1) ; lua_pop(L, 1) ;
            if (lua_rawgeti(L, 2, 5) == LUA_TNUMBER) trans.tx = lua_tonumber(L, -1) ; lua_pop(L, 1) ;
            if (lua_rawgeti(L, 2, 6) == LUA_TNUMBER) trans.ty = lua_tonumber(L, -1) ; lua_pop(L, 1) ;
        }

        CGSSpaceSetTransform(CGSDefaultConnection, (CGSSpaceID)luaL_checkinteger(L, 1), trans);
    }

    CGAffineTransform trans = CGSSpaceGetTransform(CGSDefaultConnection, (CGSSpaceID)luaL_checkinteger(L, 1)) ;
    lua_newtable(L) ;
      lua_pushnumber(L, trans.a) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushnumber(L, trans.b) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushnumber(L, trans.c) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushnumber(L, trans.d) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushnumber(L, trans.tx) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
      lua_pushnumber(L, trans.ty) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

static int showSpaces(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER | LS_TTABLE, LS_TBREAK] ;
    NSArray *theSpaces = getArrayFromNumberOrArray(L, 1) ;
    CGSShowSpaces(CGSDefaultConnection, (__bridge CFArrayRef)theSpaces) ;
    return 0 ;
}

static int hideSpaces(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER | LS_TTABLE, LS_TBREAK] ;
    NSArray *theSpaces = getArrayFromNumberOrArray(L, 1) ;
    CGSHideSpaces(CGSDefaultConnection, (__bridge CFArrayRef)theSpaces) ;
    return 0 ;
}

static int createSpace(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSDictionary *stuff = @{@"type":@(kCGSSpaceUser), @"uuid":[[NSUUID UUID] UUIDString]} ;
    NSString *theDisplay = [[LuaSkin shared] toNSObjectAtIndex:1] ;
    BOOL isValid = isScreenUUIDValid(theDisplay) ;

    if (isValid) {
        lua_pushboolean(L, CGSManagedDisplayIsAnimating(CGSDefaultConnection, (__bridge CFStringRef)theDisplay)) ;
        CGSSpaceID theSpace = CGSSpaceCreate(CGSDefaultConnection, (__bridge void *)theDisplay, (__bridge CFDictionaryRef)stuff) ;
        CGSSpaceSetType(CGSDefaultConnection, theSpace, kCGSSpaceUser) ;
        lua_pushinteger(L, (lua_Integer)theSpace) ;
        return 1 ;
    } else {
        return luaL_error(L, "createSpace: invalid screen UUID") ;
    }
}

static int removeSpace(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER, LS_TBREAK] ;
    CGSSpaceDestroy(CGSDefaultConnection, (CGSSpaceID)luaL_checkinteger(L, 1)) ;
    return 0 ;
}

static int windowsAddTo(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER | LS_TTABLE, LS_TNUMBER | LS_TTABLE, LS_TBREAK] ;
    NSArray *theWindows = getArrayFromNumberOrArray(L, 1) ;
    NSArray *theSpaces  = getArrayFromNumberOrArray(L, 2) ;
    CGSAddWindowsToSpaces(CGSDefaultConnection, (__bridge CFArrayRef)theWindows, (__bridge CFArrayRef)theSpaces);
    return 0 ;
}

static int windowsRemoveFrom(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER | LS_TTABLE, LS_TNUMBER | LS_TTABLE, LS_TBREAK] ;
    NSArray *theWindows = getArrayFromNumberOrArray(L, 1) ;
    NSArray *theSpaces  = getArrayFromNumberOrArray(L, 2) ;
    CGSRemoveWindowsFromSpaces(CGSDefaultConnection, (__bridge CFArrayRef)theWindows, (__bridge CFArrayRef)theSpaces);
    return 0 ;
}

static int windowsOnSpaces(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER | LS_TTABLE, LS_TBREAK] ;
    NSArray *theWindows = getArrayFromNumberOrArray(L, 1) ;
    NSArray *results = (__bridge_transfer NSArray *)CGSCopySpacesForWindows(CGSDefaultConnection, kCGSAllSpacesMask, (__bridge CFArrayRef)theWindows) ;
    [[LuaSkin shared] pushNSObject:results] ;
    return 1 ;
}

static int spaceShape(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER, LS_TBREAK] ;
    CGSRegionRef theRegion = CGSSpaceCopyShape(CGSDefaultConnection, (CGSSpaceID)luaL_checkinteger(L, 1)) ;
    CGSRegionRefToLua(L, theRegion) ;
    if (theRegion) CGSReleaseRegion(theRegion) ;
    return 1 ;
}

static int spaceManagedShape(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TNUMBER, LS_TBREAK] ;
    CGSRegionRef theRegion = CGSSpaceCopyManagedShape(CGSDefaultConnection, (CGSSpaceID)luaL_checkinteger(L, 1)) ;
    CGSRegionRefToLua(L, theRegion) ;
    if (theRegion) CGSReleaseRegion(theRegion) ;
    return 1 ;
}

#pragma mark - Lua Infrastructure

static luaL_Reg moduleLib[] = {
    {"screensHaveSeparateSpaces", screensHaveSeparateSpaces},
    {"activeSpace",               activeSpace},

    {"spaceType",                 spaceType},         //
    {"spaceName",                 spaceName},
    {"spaceLevel",                spaceLevel},        //
    {"spaceCompatID",             spaceCompatID},     //
    {"spaceOwners",               spaceOwners},       //
    {"spaceValues",               spaceValues},       //
    {"spaceScreenUUID",           spaceScreenUUID},   //
    {"spaceTransform",            spaceTransform},    //
    {"spaceShape",                spaceShape},        //
    {"spaceManagedShape",         spaceManagedShape}, //

    {"query",                     querySpaces},
    {"details",                   fullDetails},

    {"mainScreenUUID",            mainScreenUUID},
    {"UUIDforScreen",             screenUUID},
    {"screenUUIDisAnimating",     screenUUIDisAnimating},
    {"setScreenUUIDisAnimating",  setScreenUUIDisAnimating},

    {"showSpaces",                showSpaces},
    {"hideSpaces",                hideSpaces},

// wrapped in init.lua
    {"_changeToSpace",            changeToSpace},
    {"createSpace",               createSpace},
    {"_removeSpace",              removeSpace},

    {"enableUpdates",             enableUpdates},
    {"disableUpdates",            disableUpdates},

    {"windowsOnSpaces",           windowsOnSpaces},
    {"windowsAddTo",              windowsAddTo},
    {"windowsRemoveFrom",         windowsRemoveFrom},

    {NULL, NULL},
};

int luaopen_hs__asm_undocumented_spaces_internal(lua_State* L) {
    refTable = [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:nil] ;

    spacesMasksTable(L) ; lua_setfield(L, -2, "masks") ;
    spacesTypesTable(L) ; lua_setfield(L, -2, "types") ;

    return 1;
}
