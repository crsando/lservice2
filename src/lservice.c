#define LUA_LIB
#define LUAMOD_API LUALIB_API // back-port 5.1

#include <lua.h>
#include <lauxlib.h>
#include <stdbool.h>

#include "message.h"
#include "service.h"
#include "log.h"
#include "queue.h"
#include "lua-seri.h"

static int lservice_pool_new(lua_State *L) {
    service_pool_t * pool = service_pool_new();
    lua_pushlightuserdata(L, pool);
    return 1;
}

static int lservice_new(lua_State *L) {
    service_pool_t * pool = lua_touserdata(L, 1);
    const char * name = ( (lua_isnil(L,2)) ? NULL : luaL_checkstring(L, 2) );
	const char * source = luaL_checkstring(L, 3);
    void * config = lua_touserdata(L, 4);

    service_t * s = service_new(pool, name, source, config);
    lua_pushlightuserdata(L, s);
    return 1;
}

static int lservice_start(lua_State *L) {
    service_t * s = lua_touserdata(L, 1);
    int ret = service_start(s);
    lua_pushinteger(L, ret);
    return 1;
}

static int lservice_join(lua_State *L) {
    service_t * s = lua_touserdata(L, 1);
    int ret = service_join(s);
    lua_pushinteger(L, ret);
    return 1;
}

static int lservice_get_id(lua_State *L) {
    service_t * s = lua_touserdata(L, 1);
    lua_pushinteger(L, s->id);
    return 1;
}

static int lservice_get_pool(lua_State *L) {
    service_t * s = lua_touserdata(L, 1);
    lua_pushlightuserdata(L, s->pool);
    return 1;
}

static int lservice_get_cond(lua_State *L) {
    service_t * s = lua_touserdata(L, 1);
    lua_pushlightuserdata(L, s->c);
    return 1;
}

static int lservice_get_addr(lua_State *L) {
    service_t * s = lua_touserdata(L, 1);
    int service_id = luaL_checkinteger(L, 2);
    log_debug("lservice_get_addr %x %d", s, service_id);
    service_t * ret = service_pool_get_service(s->pool, service_id);
    lua_pushlightuserdata(L, ret);
    return 1;
}

// message related utilities

// from, to, session, type, msg, sz
static inline message_t * compose_message(lua_State *L) {
	struct message m;
	m.from = luaL_checkinteger(L, 2);
	m.to = luaL_checkinteger(L, 3);
	m.session = (session_t)luaL_checkinteger(L, 4);
	m.type = luaL_checkinteger(L, 5);
	if (lua_isnoneornil(L, 6)) {
		m.msg = NULL;
		m.sz = 0;
	} else {
		luaL_checktype(L, 6, LUA_TLIGHTUSERDATA);
		m.msg = lua_touserdata(L, 6);
		m.sz = (size_t)luaL_checkinteger(L, 7);
	}

	return message_new(&m);
}

/*
    lightuserdata pool
    integer from
	integer to
	integer session 
	integer type
	pointer message
	integer sz
 */
static int lservice_send_message(lua_State *L) {
	// if (!lua_isyieldable(L)) {
	// 	return luaL_error(L, "Can't send message in none-yieldable context");
	// }


    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    service_pool_t * pool = lua_touserdata(L, 1);

    // parse stack 2 -> 7
	message_t * msg = compose_message(L);
    service_t * to_addr = service_pool_get_service(pool, msg->to);

    service_send(to_addr, msg);

	return 0;
}

static int lservice_recv_message(lua_State *L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    service_t * s = lua_touserdata(L, 1);

    luaL_checktype(L, 2, LUA_TBOOLEAN);
    bool blocking = lua_toboolean(L, 2);

    message_t * msg = service_recv(s, blocking);

    if(msg) {
        lua_pushinteger(L, msg->from);
        lua_pushinteger(L, msg->to);
        lua_pushinteger(L, msg->session);
        lua_pushinteger(L, msg->type);
        lua_pushlightuserdata(L, msg->msg);
        lua_pushinteger(L, msg->sz);
        return 6;
    }
    else {
        return 0;
    }
}

static int
luaseri_remove(lua_State *L) {
	if (lua_isnoneornil(L, 1))
		return 0;
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	void * data = lua_touserdata(L, 1);
	size_t sz = luaL_checkinteger(L, 2);
	(void)sz;
	free(data);
	return 0;
}

// open lua library
LUAMOD_API int luaopen_lservice2_c(lua_State *L) {
	// luaL_checkversion(L);
	luaL_Reg l[] = {
        // pool
		{ "_pool_new", lservice_pool_new },
		{ "_get_pool", lservice_get_pool },
		{ "_get_cond", lservice_get_cond },
		{ "_get_addr", lservice_get_addr },

        // service
		{ "_new", lservice_new },
		{ "_start", lservice_start },
		{ "_join", lservice_join },
		{ "_get_id", lservice_get_id },
		{ "_send_message", lservice_send_message },
		{ "_recv_message", lservice_recv_message },

        // serialization components
		{ "remove", luaseri_remove },
		{ "pack", luaseri_pack },
		{ "unpack", luaseri_unpack },
		{ "unpack_remove", luaseri_unpack_remove },

        // end
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}