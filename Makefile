CFLAGS=-g -Wall
# CFLAGS+=-DDEBUGLOG

PREFIX=/usr/local/

# LUAINC?=-I/usr/local/include
LUAINC?=-I/usr/local/include/luajit-2.1
SHARED=--shared -fPIC
SO=so
LIBS=-lpthread -lluajit-5.1

all : lservice2_c.so

SRCS=\
 src/lservice.c \
 src/service.c \
 src/queue.c \
 src/registry.c \
 src/util.c \
 src/message.c \
 src/lua-seri.c \
 src/log.c

lservice2_c.so : $(SRCS)
	$(CC) $(CFLAGS) $(SHARED) $(LUAINC) -Isrc -o $@ $^ $(LIBS)

install:
	cp lservice2_c.so $(PREFIX)/lib/lua/5.1/
	cp lua/lservice2.lua $(PREFIX)/share/lua/5.1/

clean :
	rm -rf *.$(SO)