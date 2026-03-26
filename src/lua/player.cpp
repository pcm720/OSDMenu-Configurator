#include "lua/player.h"
#include "devices/vfs.h"
#include "lua/system.h"
#include <kernel.h>
#include <malloc.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static lua_State *L;

static void append_error(char *dst, size_t dstSize, int *offset, const char *fmt, ...) {
  if (!dst || !offset || !fmt || dstSize == 0)
    return;
  if (*offset < 0)
    *offset = 0;
  if ((size_t)*offset >= dstSize)
    return;

  va_list args;
  va_start(args, fmt);
  int wrote = vsnprintf(dst + *offset, dstSize - (size_t)*offset, fmt, args);
  va_end(args);
  if (wrote < 0)
    return;

  if ((size_t)wrote >= dstSize - (size_t)*offset)
    *offset = (int)dstSize - 1;
  else
    *offset += wrote;
}

// Dofile wrapper: Lua's dofile() calls the C API luaL_loadfile directly, so we must replace dofile to intercept. Try VFS first, then original dofile.
static int vfs_dofile_wrapper(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  char path_copy[512];
  size_t plen = strlen(path);
  if (plen >= sizeof(path_copy))
    plen = sizeof(path_copy) - 1;
  memcpy(path_copy, path, plen);
  path_copy[plen] = '\0';
  path = path_copy;

  if (vfs_available()) {
    size_t sz = 0;
    const void *buf = vfs_get(path, &sz);
    if (buf && sz > 0) {
      int r = luaL_loadbuffer(L, (const char *)buf, sz, path);
      if (r == 0) {
        lua_remove(L, 1);  // remove path arg so chunk is at top
        lua_call(L, 0, LUA_MULTRET);
        return lua_gettop(L);
      }
      return lua_error(L);
    }
  }
  // Not in VFS: call original dofile(path)
  lua_pushvalue(L, lua_upvalueindex(1));
  lua_pushstring(L, path);
  lua_call(L, 1, LUA_MULTRET);
  return lua_gettop(L);
}

// Loadfile wrapper: try VFS first then real file, for code that calls loadfile() directly.
static int vfs_loadfile_wrapper(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  char path_copy[512];
  size_t plen = strlen(path);
  if (plen >= sizeof(path_copy))
    plen = sizeof(path_copy) - 1;
  memcpy(path_copy, path, plen);
  path_copy[plen] = '\0';
  path = path_copy;

  if (vfs_available()) {
    size_t sz = 0;
    const void *buf = vfs_get(path, &sz);
    if (buf && sz > 0) {
      int r = luaL_loadbuffer(L, (const char *)buf, sz, path);
      if (r == 0)
        return 1;
      lua_remove(L, 1);
      lua_pushnil(L);
      lua_insert(L, -2);
      return 2;
    }
  }
  int r = luaL_loadfile(L, path);
  if (r == 0)
    return 1;
  while (lua_gettop(L) > 1)
    lua_pop(L, 1);
  lua_pushvalue(L, lua_upvalueindex(1));
  lua_pushstring(L, path);
  lua_call(L, 1, 2);
  return 2;
}

const char *runScript(const char *script, bool isStringBuffer) {
  printf("lua_player: creating luaVM\n");

  L = luaL_newstate();

  // Init Standard libraries
  luaL_openlibs(L);

  // Replace dofile (Lua's dofile calls C luaL_loadfile directly) and loadfile so both use VFS.
  if (vfs_available()) {
    lua_getglobal(L, "dofile");
    lua_pushcclosure(L, vfs_dofile_wrapper, 1);
    lua_setglobal(L, "dofile");
    lua_getglobal(L, "loadfile");
    lua_pushcclosure(L, vfs_loadfile_wrapper, 1);
    lua_setglobal(L, "loadfile");
  }

  printf("lua_player: loading libs\n");

  // init graphics
  luaGraphics_init(L);
  luaControls_init(L);
  luaScreen_init(L);
  luaTimer_init(L);
  luaSystem_init(L);
  luaRender_init(L);

  printf("lua_player: done\n");

  if (!isStringBuffer) {
    printf("lua_player: loading script: %s\n", script);
  }

  int s = 0, l = 0;
  char *errMsg = (char *)malloc(sizeof(char) * 512);
  if (errMsg == NULL) {
    lua_close(L);
    return "lua_player: out of memory while formatting error.";
  }
  errMsg[0] = '\0';

  if (!isStringBuffer) {
    // Match dofile: try VFS first when available so behaviour is same in- or outside bin
    if (vfs_available()) {
      size_t sz = 0;
      const void *buf = vfs_get(script, &sz);
      if (buf && sz > 0)
        s = luaL_loadbuffer(L, (const char *)buf, sz, script);
    }
    if (s != 0) {
      lua_pop(L, 1);
      s = luaL_loadfile(L, script);
    }
  } else {
    s = luaL_loadbuffer(L, script, strlen(script), NULL);
  }

  if (s == 0)
    s = lua_pcall(L, 0, LUA_MULTRET, 0);

  if (s) {
    append_error(errMsg, 512, &l, "\t%s\n", lua_tostring(L, -1));
    printf("%s\n", lua_tostring(L, -1));
#ifndef LUAERROR_DONT_PRINT_STACK
    int n = lua_gettop(L);
    int i;

    if (n == 0) {
      append_error(errMsg, 512, &l, "Stack is empty.\n");
    }

    for (i = 1; i <= n; i++) {
      append_error(errMsg, 512, &l, "\tLUA Stack:\n");
      append_error(errMsg, 512, &l, "\t[%i]: ", i);
      switch (lua_type(L, i)) {
      case LUA_TNONE:
        append_error(errMsg, 512, &l, "Invalid");
        break;
      case LUA_TNIL:
        append_error(errMsg, 512, &l, "(Nil)");
        break;
      case LUA_TNUMBER:
        append_error(errMsg, 512, &l, "(Number) %f", lua_tonumber(L, i));
        break;
      case LUA_TBOOLEAN:
        append_error(errMsg, 512, &l, "(Bool)   %s", (lua_toboolean(L, i) ? "true" : "false"));
        break;
      case LUA_TSTRING:
        append_error(errMsg, 512, &l, "(String) %s", lua_tostring(L, i));
        break;
      case LUA_TTABLE:
        append_error(errMsg, 512, &l, "(Table)");
        break;
      case LUA_TFUNCTION:
        append_error(errMsg, 512, &l, "(Function)");
        break;
      default:
        append_error(errMsg, 512, &l, "Unknown");
      }

      append_error(errMsg, 512, &l, "\n");
    }
#endif

    lua_pop(L, 1); // remove error message
  }
  lua_close(L);

  return (const char *)errMsg;
}
