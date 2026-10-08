/* Controlled Linux proof fixture; never distributed or executed on routers. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void fail(const char *message) {
    perror(message);
    exit(1);
}

static void ready(const char *path) {
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd < 0 || write(fd, "ready\n", 6) != 6 || close(fd)) fail("readiness");
}

int main(int argc, char **argv) {
    alarm(12);
    if (argc == 2 && !strcmp(argv[1], "signal-parent")) {
        pid_t owner = getppid();
        if (owner <= 1 || kill(owner, SIGTERM)) fail("signal exact callback owner");
        return 0;
    }
    if (argc == 4 && !strcmp(argv[1], "holder")) {
        FILE *control = fopen(argv[2], "r");
        char path[PATH_MAX], release;
        if (!control || !fgets(path, sizeof(path), control)) fail("holder request");
        size_t length = strlen(path);
        if (!length || path[length - 1] != '\n') fail("holder path framing");
        path[length - 1] = 0;
        int held = open(path, O_RDONLY);
        if (held < 0) fail("open destination bind");
        ready(argv[3]);
        if (fread(&release, 1, 1, control) != 1 || release != 'x') fail("holder release");
        if (close(held) || fclose(control)) fail("holder close");
        return 0;
    }
    if (argc != 2 || (strcmp(argv[1], "check") && strcmp(argv[1], "wait") &&
                     strcmp(argv[1], "image-wait"))) return 2;
    char cwd[PATH_MAX];
    if (!getcwd(cwd, sizeof(cwd)) || strcmp(cwd, "/")) fail("chroot cwd");
    for (int fd = 8; fd <= 9; fd++) {
        errno = 0;
        if (fcntl(fd, F_GETFD) != -1 || errno != EBADF) fail("external descriptor retained");
    }
    const char *absent[] = {"/proc", "/bin/sh"};
    struct stat metadata;
    for (size_t i = 0; i < sizeof(absent) / sizeof(absent[0]); i++) {
        errno = 0;
        if (!stat(absent[i], &metadata) || errno != ENOENT) fail("unexpected root entry");
    }
    int null = open("/dev/null", O_RDWR);
    char byte;
    if (null < 0 || write(null, "x", 1) != 1 || read(null, &byte, 1) != 0 || close(null)) {
        fail("native null");
    }
    if (!strcmp(argv[1], "image-wait")) {
        if (geteuid() != 0) fail("image actor must be root");
        const char *writes[] = {"/opt/write-test", "/opt/sentinel"};
        for (size_t i = 0; i < sizeof(writes) / sizeof(writes[0]); i++) {
            errno = 0;
            int writable = open(writes[i], O_WRONLY | (i == 0 ? O_CREAT | O_EXCL : 0), 0600);
            if (writable != -1 || errno != EROFS) fail("image write must fail EROFS");
        }
        const char expected[] = "controlled fixture\n";
        char retained[sizeof(expected)];
        int offline = open("/offline/opt/sentinel", O_RDONLY);
        if (offline < 0 || read(offline, retained, sizeof(expected) - 1) != (ssize_t)(sizeof(expected) - 1) ||
            memcmp(retained, expected, sizeof(expected) - 1) || read(offline, &byte, 1) != 0 ||
            close(offline)) fail("retained offline sentinel");
    }
    if (!strcmp(argv[1], "wait") || !strcmp(argv[1], "image-wait")) {
        if (write(STDOUT_FILENO, "ready\n", 6) != 6) fail("mapping readiness");
        if (read(STDIN_FILENO, &byte, 1) != 1 || byte != 'x') fail("mapping release");
    }
    return 0;
}
