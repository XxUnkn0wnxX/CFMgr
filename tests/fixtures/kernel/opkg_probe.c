/* Trusted static opkg/capability stand-ins; never real opkg or router code. */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

extern char **environ;

static int write_all(int fd, const char *data, size_t length) {
    while (length) {
        ssize_t written = write(fd, data, length);
        if (written <= 0) return 1;
        data += written;
        length -= (size_t)written;
    }
    return 0;
}

static int input_matches(int fd, const char *expected) {
    char retained[128], extra;
    size_t size = strlen(expected);
    if (size >= sizeof(retained)) return 1;
    ssize_t length = read(fd, retained, size);
    ssize_t remaining = read(fd, &extra, 1);
    return length != (ssize_t)size || remaining != 0 || memcmp(retained, expected, size);
}

static int context(int version) {
    /* Observe inherited descriptors before opening any fixture evidence. */
    for (int fd = 3; fd <= 63; fd++) {
        errno = 0;
        if (fcntl(fd, F_GETFD) != -1 || errno != EBADF) return 121;
    }
    char cwd[2];
    if (!getcwd(cwd, sizeof(cwd)) || strcmp(cwd, "/")) return 122;
    const char *allowed[] = {
        version ? "PATH=/sbin:/bin:/usr/sbin:/usr/bin" :
                  "PATH=/sbin:/bin:/usr/sbin:/usr/bin:/opt/bin:/opt/sbin",
        "LC_ALL=C", "HOME=/tmp/cfmgr-home", version ? "TMPDIR=/tmp" : 0,
        "PWD=/", "SHLVL=1"
    };
    unsigned seen = 0;
    for (char **entry = environ; *entry; entry++) {
        unsigned index;
        for (index = 0; index < sizeof(allowed) / sizeof(allowed[0]); index++) {
            if (allowed[index] && !strcmp(*entry, allowed[index])) break;
        }
        if (index == sizeof(allowed) / sizeof(allowed[0]) || (seen & (1U << index))) return 123;
        seen |= 1U << index;
    }
    unsigned required = version ? 15U : 7U;
    if ((seen & required) != required) return 124;
    int marker = open("/opt/anchored", O_RDONLY | O_CLOEXEC);
    if (marker < 0) return 125;
    int mismatch = input_matches(marker, "anchored\n");
    int closed = close(marker);
    return mismatch || closed ? 126 : 0;
}

static int record(const char *command) {
    int log = open("/opt/dependency-commands", O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0600);
    if (log < 0) return 1;
    int failed = write_all(log, command, strlen(command));
    int closed = close(log);
    return failed || closed;
}

static int install_jq(void) {
    /* A 32KiB package write witnesses absence of the old tiny probe cap. */
    char buffer[4096] = {0};
    int package = open("/opt/dependency-package-data", O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
    if (package < 0) return 1;
    int failed = 0;
    for (int count = 0; count < 8; count++) failed |= write_all(package, buffer, sizeof(buffer));
    if (close(package) || failed) return 1;
    /* Install genuine executable fixture bytes so the actual backend's post
     * check invokes the newly available jq, rather than trusting a marker. */
    int source = open("/opt/bin/opkg", O_RDONLY | O_CLOEXEC);
    if (source < 0) return 1;
    int target = open("/opt/bin/jq", O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0700);
    if (target < 0) { close(source); return 1; }
    size_t total = 0;
    ssize_t length;
    while ((length = read(source, buffer, sizeof(buffer))) > 0) {
        total += (size_t)length;
        if (total > 4194304 || write_all(target, buffer, (size_t)length)) { failed = 1; break; }
    }
    if (length < 0 || total == 0) failed = 1;
    int source_closed = close(source), target_closed = close(target);
    return failed || source_closed || target_closed;
}

int main(int argc, char **argv) {
    int opkg = !strcmp(argv[0], "/opt/bin/opkg");
    int version = opkg && argc == 2 && !strcmp(argv[1], "--version");
    if (version) {
        int checked = context(1);
        if (checked) return checked;
        const char response[] =
            "opkg version 80503d94e356476250adaf1f669ee955ec26de76 (2025-11-05)\n";
        return write_all(STDOUT_FILENO, response, sizeof(response) - 1) ? 127 : 0;
    }
    if (argc < 1) return 120;
    int checked = context(0);
    if (checked) return checked;
    if (opkg && argc == 2 && !strcmp(argv[1], "update")) return record("update\n");
    if (opkg && argc == 3 && !strcmp(argv[1], "install") && !strcmp(argv[2], "jq")) {
        return record("install jq\n") || install_jq();
    }
    if (!strcmp(argv[0], "/opt/bin/jq") && argc == 4 && !strcmp(argv[1], "-M") &&
        !strcmp(argv[2], "-r") && !strcmp(argv[3], ".cfmgr")) {
        if (input_matches(STDIN_FILENO, "{\"cfmgr\":\"ready\"}\n") || record("jq\n")) return 1;
        return write_all(STDOUT_FILENO, "ready\n", 6);
    }
    if (!strcmp(argv[0], "/opt/bin/timeout") && argc == 5 && !strcmp(argv[1], "1") &&
        !strcmp(argv[2], "/bin/sh") && !strcmp(argv[3], "-c") && !strcmp(argv[4], "exit 0")) {
        if (record("timeout\n")) return 1;
        execv("/bin/sh", &argv[2]);
        return 127;
    }
    if (!strcmp(argv[0], "/opt/bin/sha256sum") && argc == 1) {
        if (input_matches(STDIN_FILENO, "abc") || record("sha256sum\n")) return 1;
        const char digest[] = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  -\n";
        return write_all(STDOUT_FILENO, digest, sizeof(digest) - 1);
    }
    return 120;
}
