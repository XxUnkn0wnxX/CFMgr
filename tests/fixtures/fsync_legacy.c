/* Developer-only fault fixture; never built or installed on a router.
 * The legacy failure contract was reviewed at Merlin source pins
 * 433fc608f5fc1689f3d3c3ab5cd2a7d57102260f and
 * 69838e4a60564e5550e97f11d8a8cf2c6260c4f0, both at
 * release/src/router/busybox/coreutils/fsync.c, lines 33-47:
 * an open failure returns nonzero; an fsync failure diagnoses errno but leaves
 * status zero. This independently written small fixture preserves that behavior
 * with injected faults. It uses inherited fd 3 for portable host tests rather
 * than reproducing Linux /proc pathname reopening. Real Linux applet tests are
 * separate. Successful cases actually call fsync(2), including on directories.
 */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    const char *mode = getenv("CFMGR_FSYNC_FAULT");
    const char *locale = getenv("LC_ALL");
    const char *language = getenv("LANGUAGE");
    int flags = fcntl(3, F_GETFL);

    if (argc != 2 || strcmp(argv[1], "/proc/self/fd/3") != 0 ||
        !locale || strcmp(locale, "C") != 0 || !language || *language ||
        flags == -1 || (flags & O_ACCMODE) != O_RDONLY)
        return 2;
    if (getenv("CFMGR_FSYNC_TRACE") && write(4, "x", 1) != 1)
        return 2;
    if (!mode)
        mode = "clean";
    if (strcmp(mode, "open") == 0) {
        errno = EACCES;
        fprintf(stderr, "%s: %s\n", argv[1], strerror(errno));
        return 1;
    }
    if (strcmp(mode, "nonzero") == 0)
        return 7;
    if (strcmp(mode, "signal") == 0) {
        raise(SIGTERM);
        return 8;
    }
    if (strcmp(mode, "newline") == 0) {
        fputs("\n", stderr);
        return 0;
    }
    if (strcmp(mode, "stdout") == 0) {
        fputs("unexpected output", stdout);
        return 0;
    }
    if (strcmp(mode, "fsync") == 0) {
        /* A real failing syscall supplies errno for the legacy diagnostic. */
        if (fsync(-1) == 0)
            return 9;
    } else if (fsync(3) == 0) {
        return 0;
    }
    fprintf(stderr, "%s: %s\n", argv[1], strerror(errno));
    return 0; /* Deliberately reproduce Merlin's zero-status defect. */
}
