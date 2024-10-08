
#include <stdio.h>
#include <stdlib.h>
#include <libpq-fe.h>

int main() {
    // Connect to the PostgreSQL database
    PGconn *conn = PQconnectdb("host=localhost user=postgres password=development dbname=postgres port=5432 sslmode=disable");

    // Check the connection status
    if (PQstatus(conn) != CONNECTION_OK) {
        fprintf(stderr, "Connection to database failed: %s\n", PQerrorMessage(conn));
        PQfinish(conn);
        exit(1);
    }

    // Execute an SQL query
    PGresult *res = PQexec(conn, "SELECT version();");

    // Check for successful result
    if (PQresultStatus(res) != PGRES_TUPLES_OK) {
        fprintf(stderr, "SELECT failed: %s\n", PQerrorMessage(conn));
        PQclear(res);
        PQfinish(conn);
        exit(1);
    }

    // Print the result of the query
    printf("PostgreSQL version: %s\n", PQgetvalue(res, 0, 0));

    // Clean up
    PQclear(res);
    PQfinish(conn);

    return 0;
}
