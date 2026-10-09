/* Linux-only mechanism proof; never distributed or executed on routers.
 * The child deliberately keeps two anonymous communication pipes outside the
 * private root. These proof-only handles are not root/Opt mount references.
 * This tests trusted filesystem lifetime, not protection from privileged escape.
 */
#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#ifdef __linux__
#include <sys/mount.h>
#endif

static const char *guard;

static void fail(const char *message) {
    perror(message);
    exit(1);
}

static void path(char *output, size_t size, const char *base, const char *name) {
    int length = snprintf(output, size, "%s/%s", base, name);
    if (length < 0 || (size_t)length >= size) {
        errno = ENAMETOOLONG;
        fail("fixture path");
    }
}

static void mark(const char *name) {
    char output[4096];
    path(output, sizeof(output), guard, name);
    int fd = open(output, O_WRONLY | O_CREAT | O_EXCL, 0600);
    size_t size = strlen(name);
    if (fd < 0 || write(fd, name, size) != (ssize_t)size || close(fd)) fail("guard marker");
}

static void retained_guard(int uncertain) {
    char output[4096];
    struct stat metadata;
    if (lstat(guard, &metadata) || !S_ISDIR(metadata.st_mode)) fail("guard missing");
    path(output, sizeof(output), guard, "active");
    if (lstat(output, &metadata) || !S_ISREG(metadata.st_mode)) fail("active marker missing");
    if (uncertain) {
        path(output, sizeof(output), guard, "uncertain");
        if (lstat(output, &metadata) || !S_ISREG(metadata.st_mode)) fail("uncertainty missing");
    }
    path(output, sizeof(output), guard, "complete");
    errno = 0;
    if (!lstat(output, &metadata) || errno != ENOENT) fail("premature completion");
}

static int remove_mount(const char *target) {
#ifdef __linux__
    return umount(target); /* Ordinary non-lazy syscall, no force or fallback. */
#else
    /* Let a non-Linux compiler check the portable controller without executing
     * or substituting Linux mount behavior. main also refuses these hosts. */
    (void)target;
    errno = ENOSYS;
    return -1;
#endif
}

static void expect_busy(const char *target, int uncertain) {
    errno = 0;
    int status = remove_mount(target);
    if (status != -1 || errno != EBUSY) fail("root removal must fail EBUSY");
    retained_guard(uncertain);
}

static void bind_opt(const char *source, const char *target) {
#ifdef __linux__
    if (mount(source, target, NULL, MS_BIND, NULL) ||
        mount(NULL, target, NULL, MS_PRIVATE, NULL)) fail("writable private Opt bind");
#else
    (void)source;
    (void)target;
    errno = ENOSYS;
    fail("Linux Opt bind required");
#endif
}

static void byte_write(int fd, char value) {
    ssize_t size;
    do { size = write(fd, &value, 1); } while (size < 0 && errno == EINTR);
    if (size != 1) fail("owned pipe write");
}

static void byte_expect(int fd, char expected) {
    char value = 0;
    ssize_t size;
    do { size = read(fd, &value, 1); } while (size < 0 && errno == EINTR);
    if (size != 1 || value != expected) {
        fprintf(stderr, "owned acknowledgement: expected %c, got %c (%zd bytes)\n",
                expected, value ? value : '?', size);
        exit(1);
    }
}

static void empty_directory(const char *target) {
    DIR *directory = opendir(target);
    if (!directory) fail("fallback directory");
    struct dirent *entry;
    while ((entry = readdir(directory))) {
        if (strcmp(entry->d_name, ".") && strcmp(entry->d_name, "..")) {
            errno = ENOTEMPTY;
            fail("fallback must be empty");
        }
    }
    if (closedir(directory)) fail("fallback directory close");
}

static void actual_root_lease(int fd, unsigned long expected) {
    char location[64], line[256];
    snprintf(location, sizeof(location), "/proc/self/fdinfo/%d", fd);
    FILE *info = fopen(location, "r");
    if (!info) fail("root lease fdinfo");
    unsigned long observed = 0;
    while (fgets(line, sizeof(line), info)) {
        if (sscanf(line, "mnt_id: %lu", &observed) == 1) break;
    }
    if (fclose(info) || !observed || observed != expected) fail("lease is not actual root bind");
    struct statvfs metadata;
    if (fstatvfs(fd, &metadata) || !(metadata.f_flag & ST_RDONLY)) fail("root lease is not readonly");
}

static void close_unrelated(DIR *descriptors, int command, int reply, int lease) {
    int listing = dirfd(descriptors);
    struct dirent *entry;
    while ((entry = readdir(descriptors))) {
        if (entry->d_name[0] == '.') continue;
        char *end;
        long number = strtol(entry->d_name, &end, 10);
        if (*end || number < 0 || number > 2147483647) fail("descriptor entry");
        int fd = (int)number;
        if (fd != listing && fd != command && fd != reply && fd != lease && close(fd)) {
            fail("unrelated descriptor close");
        }
    }
    if (closedir(descriptors)) fail("descriptor listing close");
}

static void child(const char *root, int command, int reply, int lease) {
    alarm(12);
    byte_write(reply, 'L');
    byte_expect(command, 'C');
    DIR *descriptors = opendir("/proc/self/fd");
    if (!descriptors || chroot(root) || chdir("/")) fail("child chroot");
    if (setsid() != getpid() || getsid(0) != getpid() || getpgrp() != getpid()) fail("child detachment");
    char cwd[16];
    if (!getcwd(cwd, sizeof(cwd)) || strcmp(cwd, "/")) fail("child root cwd");
    close_unrelated(descriptors, command, reply, lease);
    byte_write(reply, 'R');
    /* Parent has committed no-more-launches only after our chroot transition. */
    byte_expect(command, 'D');
    if (close(lease)) fail("launch lease close");
    byte_write(reply, 'D');
    byte_expect(command, 'W');
    int output = open("/opt/early", O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (output < 0 || write(output, "early", 5) != 5 || close(output)) fail("mounted Opt write");
    byte_write(reply, 'W'); /* No Opt FD/cwd remains when removal starts. */
    byte_expect(command, 'F');
    const char *fallbacks[] = {"/opt/late", "/tmp/late"};
    for (size_t i = 0; i < sizeof(fallbacks) / sizeof(fallbacks[0]); i++) {
        errno = 0;
        output = open(fallbacks[i], O_WRONLY | O_CREAT | O_EXCL, 0600);
        if (output != -1 || errno != EROFS) fail("late fallback write must fail EROFS");
    }
    byte_write(reply, 'F');
    byte_expect(command, 'X');
    if (close(command) || close(reply)) fail("child pipe close");
    _exit(0);
}

int main(int argc, char **argv) {
    if (argc != 6) return 2;
#ifndef __linux__
    fprintf(stderr, "worker lifetime fixture requires Linux\n");
    return 2;
#endif
    if (geteuid() != 0 || getppid() != 1 || getpid() == 1) {
        fprintf(stderr, "worker lifetime controller requires checked namespace init parent\n");
        return 2;
    }
    alarm(12);
    if (signal(SIGPIPE, SIG_IGN) == SIG_ERR) fail("owned pipe signals");
    const char *root = argv[1], *opt = argv[3], *image = argv[4];
    guard = argv[2];
    char *end;
    unsigned long root_mount_id = strtoul(argv[5], &end, 10);
    if (*end || !root_mount_id) return 2;
    char root_opt[4096], root_tmp[4096], observed[4096];
    path(root_opt, sizeof(root_opt), root, "opt");
    path(root_tmp, sizeof(root_tmp), root, "tmp");
    empty_directory(root_opt);
    empty_directory(root_tmp);
    mark("active");
    int lease = open(root, O_RDONLY | O_DIRECTORY);
    if (lease < 0) fail("launch root lease");
    actual_root_lease(lease, root_mount_id);
    int commands[2], replies[2];
    if (pipe(commands) || pipe(replies)) fail("owned controller pipes");
    pid_t actor = fork();
    if (actor < 0) fail("owned launcher fork");
    if (!actor) {
        if (close(commands[1]) || close(replies[0])) fail("child unused pipes");
        child(root, commands[0], replies[1], lease);
        _exit(1);
    }
    /* The delayed launcher alone now owns the actual bind's directory lease. */
    if (close(lease) || close(commands[0]) || close(replies[1])) fail("controller unused descriptors");
    byte_expect(replies[0], 'L');
    expect_busy(root, 0); /* No child mount exists yet. */
    byte_write(commands[1], 'C');
    byte_expect(replies[0], 'R');
    /* No additional fork/launch is permitted after this controller transition. */
    mark("no-more-launches");
    byte_write(commands[1], 'D');
    byte_expect(replies[0], 'D');
    expect_busy(root, 0); /* Only the detached child's fs root/cwd pins this bind. */
    bind_opt(opt, root_opt);
    byte_write(commands[1], 'W');
    byte_expect(replies[0], 'W');
    path(observed, sizeof(observed), opt, "early");
    struct stat metadata;
    if (stat(observed, &metadata) || !S_ISREG(metadata.st_mode) || metadata.st_size != 5) fail("Opt write absent");
    mark("uncertain"); /* Revoking a writable child is partial teardown, not success. */
    if (remove_mount(root_opt)) fail("ordinary writable Opt removal");
    byte_write(commands[1], 'F');
    byte_expect(replies[0], 'F');
    path(observed, sizeof(observed), image, "opt/late");
    errno = 0;
    if (!lstat(observed, &metadata) || errno != ENOENT) fail("Opt fallback file exists");
    path(observed, sizeof(observed), image, "tmp/late");
    errno = 0;
    if (!lstat(observed, &metadata) || errno != ENOENT) fail("tmp fallback file exists");
    expect_busy(root, 1);
    printf("partial teardown retained uncertainty; detached root reference and RO fallbacks proved\n");
    byte_write(commands[1], 'X');
    if (close(commands[1]) || close(replies[0])) fail("controller pipe close");
    int status;
    pid_t waited;
    do { waited = waitpid(actor, &status, 0); } while (waited < 0 && errno == EINTR);
    if (waited != actor || !WIFEXITED(status) || WEXITSTATUS(status)) fail("exact controlled actor wait");
    if (remove_mount(root)) fail("root removal after final child exit");
    mark("complete");
    printf("root lease, setsid lifetime, Opt revocation and final ordinary root removal passed\n");
    return 0;
}
