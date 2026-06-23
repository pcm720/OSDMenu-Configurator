#ifndef LUA_PLAYER_H
#define LUA_PLAYER_H

#include <debug.h>

extern "C" {
#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"
}

const char *runScript(const char *script, bool isStringBuffer);

void luaControls_init(lua_State *L);
void luaGraphics_init(lua_State *L);
void luaScreen_init(lua_State *L);
void luaTimer_init(lua_State *L);
void luaSystem_init(lua_State *L);
void luaRender_init(lua_State *L);

#endif
