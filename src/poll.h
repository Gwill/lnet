/*
 *  Written by xphh 2015 with 'MIT License'
 */
#ifndef _POLL_H_
#define _POLL_H_

#include "src/socket.h"

#define READABLE 1
#define WRITABLE 2

C_API int socket_wait(int fd, int flag, int timeout);

typedef struct poll_t *poll_handle;

typedef struct 
{
	int fd;
	int flag;
} event_t;

C_API int check_poll(poll_handle);
C_API poll_handle poll_create(int size);
C_API void poll_destroy(poll_handle);
C_API int poll_control(poll_handle, const event_t *ev, int inthread);
C_API int poll_do(poll_handle, int timeout);
C_API void poll_event(poll_handle, int id, event_t *ev);

#endif
