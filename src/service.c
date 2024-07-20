#include "service.h"

#include "log.h"
#include <assert.h>
#include <stdlib.h>
#include "message.h"

#define _SERVICE_MQ_DEF_SIZE_ 1024

service_pool_t * service_pool_new() {
    service_pool_t * pool = NULL;
    pool = (service_pool_t *)malloc(sizeof(service_pool_t));
    memset(pool, 0, sizeof(service_pool_t));
	pthread_mutex_init(&pool->lock, NULL);
    return pool;
}

service_t * service_pool_query_service(service_pool_t * pool, const char * key) {
    service_t * s = NULL;
    pthread_mutex_lock(&pool->lock);
    registry_t * r = registry_get(&pool->services, key);
    s = (service_t*)( r ? r->ptr : NULL );
    pthread_mutex_unlock(&pool->lock);
    return s;
}

void * service_pool_registry(service_pool_t * pool, const char * key, void * ptr) {
    if(ptr) {
        pthread_mutex_lock(&pool->lock);
        registry_put(&pool->variables, key, ptr);
        pthread_mutex_unlock(&pool->lock);
        return ptr;
    }
    else {
        void * data = NULL;
        // get registry
        log_debug("lock pool->lock");
        pthread_mutex_lock(&pool->lock);
        if(! pool->variables ) {
            // log_debug("pool->variables == NULL");
            data = NULL;
        }
        else {
            registry_t * r = registry_get(&pool->variables, key);
            data = ( r ? r->ptr : NULL );
        }
        pthread_mutex_unlock(&pool->lock);
        return data;
    }
}

int service_init_lua(service_t * s) {
    lua_State * L;
	L = luaL_newstate();
    s->L = L;

    if(!L) {
		log_error("THREAD FATAL ERROR: could not create lua state");
		return -1;
	}

	luaL_openlibs(L);

    if(luaL_loadstring(L, s->code)) {
        log_error("FATAL THREAD PANIC: (loadstring) %s", lua_tolstring(L, -1, NULL));
		lua_close(L);
		return -1; 
    }

    int n_args = 0;
    // push pointer to self
    lua_pushlightuserdata(L, s);
    n_args ++;

    // push lightuserdata (config)
    if(s->config) {
        lua_pushlightuserdata(L, s->config);
        n_args ++;
    }


    // run the lua code
    // 2 input expect (service, config), no output
	if(lua_pcall(L, n_args, 0, 0)) {
		log_error("FATAL THREAD PANIC: (pcall) %s", lua_tolstring(L, -1, NULL));
		lua_close(L);
		return -1;
	}


    return 0; // no error
}

service_t * service_new(service_pool_t * pool, const char * name, const char * code, void * config) {
    service_t * s;

    s = (service_t *)malloc(sizeof(service_t));
    memset(s, 0, sizeof(service_t));

    if(pool) {
        s->pool = pool;
        assert(name && (strlen(name) <= 30));
        strcpy(s->name, name);

        pthread_mutex_lock(&pool->lock);
        registry_put(&pool->services, name, s);
        pthread_mutex_unlock(&pool->lock);
    }

    assert(code != NULL);
    s->code = (char *)malloc(sizeof(char) * (strlen(code) + 1));
    strcpy(s->code, code);
    s->config = config;

    s->q = queue_new_ptr(_SERVICE_MQ_DEF_SIZE_);
    s->c = (struct cond *)malloc(sizeof(struct cond));
    cond_create(s->c);

    return s;
}

// entry fro pthread_create
void * service_routine_wrap(void * arg) {
    void * msg;
    service_t * s = (service_t *)arg;

    service_init_lua(s);

    assert(s->L != NULL);
}

int service_start(service_t * s) {
    pthread_t th;
    int ret = pthread_create(&th, NULL, service_routine_wrap, s);
    s->thread = th;
    return ret;
}

int service_send(service_t * s, message_t * msg) {
    cond_trigger_begin(s->c);
    queue_push_ptr(s->q, msg);
    cond_trigger_end(s->c, 1);
    return 1;
}

message_t * service_recv(service_t * s, bool blocking) {
    message_t * msg;
    if(blocking) {
        cond_wait_begin(s->c);
        while( queue_length(s->q) == 0 )
            cond_wait(s->c);
        msg = queue_pop_ptr(s->q);
        cond_wait_end(s->c);
    }
    else {
        msg = queue_pop_ptr(s->q);
    }
    return msg;
}

int service_free(service_t * s) {
    lua_close(s->L);
    queue_delete(s->q);
    cond_release(s->c);
    return 1;
}