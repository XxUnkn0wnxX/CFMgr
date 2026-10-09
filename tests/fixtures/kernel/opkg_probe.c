/* Trusted static version-only stand-in; never real opkg or router code. */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

extern char **environ;

int main(int argc, char **argv) {
    if (argc != 2 || strcmp(argv[0], "/opt/bin/opkg") || strcmp(argv[1], "--version")) return 120;
    /* Observe inherited descriptors before opening the retained marker. */
    for (int fd = 3; fd <= 63; fd++) {
        errno = 0;
        if (fcntl(fd, F_GETFD) != -1 || errno != EBADF) return 121;
    }
    char cwd[2];
    if (!getcwd(cwd, sizeof(cwd)) || strcmp(cwd, "/")) return 122;
    const char *allowed[] = {
        "PATH=/sbin:/bin:/usr/sbin:/usr/bin", "LC_ALL=C",
        "HOME=/tmp/cfmgr-home", "TMPDIR=/tmp", "PWD=/", "SHLVL=1"
    };
    unsigned seen = 0;
    for (char **entry = environ; *entry; entry++) {
        unsigned index;
        for (index = 0; index < sizeof(allowed) / sizeof(allowed[0]); index++) {
            if (!strcmp(*entry, allowed[index])) break;
        }
        if (index == sizeof(allowed) / sizeof(allowed[0]) || (seen & (1U << index))) return 123;
        seen |= 1U << index;
    }
    if ((seen & 15U) != 15U) return 124;
    const char expected[] = "anchored\n";
    char retained[sizeof(expected)], extra;
    int marker = open("/opt/anchored", O_RDONLY | O_CLOEXEC);
    if (marker < 0) return 125;
    ssize_t length = read(marker, retained, sizeof(expected) - 1);
    ssize_t remaining = read(marker, &extra, 1);
    int closed = close(marker);
    if (length != (ssize_t)(sizeof(expected) - 1) || remaining != 0 || closed ||
        memcmp(retained, expected, sizeof(expected) - 1)) return 126;
    const char response[] =
        "opkg version 80503d94e356476250adaf1f669ee955ec26de76 (2025-11-05)\n";
    if (write(STDOUT_FILENO, response, sizeof(response) - 1) != (ssize_t)(sizeof(response) - 1)) return 127;
    return 0;
}
