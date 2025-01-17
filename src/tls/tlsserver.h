#ifndef TLSSERVER_H
#define TLSSERVER_H 

#include <openssl/ssl.h>

int start_tls_server(int);
SSL* accept_connection(void);

#endif
