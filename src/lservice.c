#define LUA_LIB
#define LUAMOD_API LUALIB_API // back-port 5.1

#include <lua.h>
#include <lauxlib.h>

static int lservice_new(lua_State *L) {
    service_pool_t * pool = luaL_checkuserdata(L, 1);
    const char * name = luaL_checkstring(L, 2);
	const char * source = luaL_checkstring(L, 3);
    void * config = luaL_checkuserdata(L, 4);

    service_t * s = service_new(pool, name, source, config);
    lua_pushuserdata(L, s);
    return 1;
}

static int lservice_start(lua_State *L) {
    service_t * s = luaL_checkuserdata(L, 1);
    int ret = service_start(s);
    lua_pushinteger(L, ret);
    return 1;
}


// open lua library
LUAMOD_API int luaopen_lservice(lua_State *L) {
	// luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "pack", luaseri_pack },
		{ "unpack", luaseri_unpack },
		{ "unpack_remove", luaseri_unpack_remove },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}