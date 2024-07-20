#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h> // bool type

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "registry.h"
#include "queue.h"
#include "cond.h"
#include "message.h"

typedef unsigned int service_id;

#define MAX_SERVICES (32)

struct service;
struct service_pool;
typedef struct service service_t;
typedef struct service_pool service_pool_t;

struct service_pool {
    pthread_mutex_t lock;
    service_t * services[MAX_SERVICES+1];
    service_id id; // next id to assign
    // registry_t * services;
    registry_t * variables;
};

struct service {
    service_pool_t * pool;

    // service id and name
    service_id id;
    char name[32];

    // init params
    char * code;
    void * config;

    // multi-thread utilities
    pthread_t thread;

    // message queue (i.e. inbox)
    struct queue * q;
    struct cond * c;


    lua_State * L;
    // int lua_func_ref;
};

service_pool_t * service_pool_new();
void * service_pool_registry(service_pool_t * pool, const char * key, void * ptr);
// service_t * service_pool_query_service(service_pool_t * pool, const char * key);
service_t * service_pool_get_service(service_pool_t * pool, service_id id);

// service_t * service_new(service_pool_t * pool, const char * name);
service_t * service_new(service_pool_t * pool, const char * name, const char * code, void * config);

// int service_init_lua(service_t * s, const char * code, void * config);
int service_init_lua(service_t * s);
int service_start(service_t * s);

int service_send(service_t * s, message_t * msg);
message_t * service_recv(service_t * s, bool blocking);

int service_free(service_t * s);