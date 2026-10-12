/* Linux-only process ownership fixture for host tests. Never install on routers. */
#define _GNU_SOURCE

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pthread.h>
#include <sched.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include <poll.h>

enum fixture_mode { MODE_HOLD, MODE_DAEMON, MODE_LEADER_EXIT, MODE_MIXED };

struct sync_state {
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    int done;
    int result;
};

static struct sync_state thread_sync = {
    PTHREAD_MUTEX_INITIALIZER, PTHREAD_COND_INITIALIZER, 0, 0
};

static void report_error(const char *operation)
{
    fprintf(stderr, "dependency_process: %s: %s\n", operation, strerror(errno));
}

static long current_tid(void)
{
    return (long)syscall(SYS_gettid);
}

static int is_kept(int fd, const int *kept, size_t count)
{
    size_t i;

    for (i = 0; i < count; ++i) {
        if (kept[i] == fd)
            return 1;
    }
    return 0;
}

static int close_all_except(const int *kept, size_t count)
{
    DIR *directory;
    struct dirent *entry;
    int scan_fd;
    int saved_errno = 0;

    directory = opendir("/proc/self/fd");
    if (!directory)
        return -1;
    scan_fd = dirfd(directory);
    while ((entry = readdir(directory)) != NULL) {
        char *end;
        long value;

        if (entry->d_name[0] == '.')
            continue;
        errno = 0;
        value = strtol(entry->d_name, &end, 10);
        if (errno || *end || value < 3 || value > INT_MAX || value == scan_fd ||
            is_kept((int)value, kept, count))
            continue;
        if (close((int)value) < 0 && errno != EBADF) {
            saved_errno = errno;
            break;
        }
    }
    if (closedir(directory) < 0 && !saved_errno)
        saved_errno = errno;
    if (saved_errno) {
        errno = saved_errno;
        return -1;
    }
    return 0;
}

static int redirect_stdio_and_close_fds(const int *kept, size_t count)
{
    int null_fd = open("/dev/null", O_RDWR | O_CLOEXEC);
    int target;

    if (null_fd < 0)
        return -1;
    for (target = STDIN_FILENO; target <= STDERR_FILENO; ++target) {
        if (dup2(null_fd, target) < 0) {
            int saved_errno = errno;
            close(null_fd);
            errno = saved_errno;
            return -1;
        }
    }
    if (null_fd > STDERR_FILENO && close(null_fd) < 0)
        return -1;
    return close_all_except(kept, count);
}

static int split_receipt_path(const char *path, int *directory_fd,
                              char *name, size_t name_size)
{
    const char *slash = strrchr(path, '/');
    const char *base = slash ? slash + 1 : path;
    char directory[PATH_MAX];
    size_t directory_length;

    if (!*base || strcmp(base, ".") == 0 || strcmp(base, "..") == 0 ||
        strlen(base) >= name_size) {
        errno = EINVAL;
        return -1;
    }
    strcpy(name, base);
    if (!slash) {
        strcpy(directory, ".");
    } else if (slash == path) {
        strcpy(directory, "/");
    } else {
        directory_length = (size_t)(slash - path);
        if (directory_length >= sizeof(directory)) {
            errno = ENAMETOOLONG;
            return -1;
        }
        memcpy(directory, path, directory_length);
        directory[directory_length] = '\0';
    }
    *directory_fd = open(directory, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    return *directory_fd < 0 ? -1 : 0;
}

static int publish_receipt(int directory_fd, const char *name, long pid, long tid)
{
    char line[96];
    int length;
    int receipt_fd;
    struct stat info;
    size_t offset = 0;

    receipt_fd = openat(directory_fd, name,
                        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                        0600);
    if (receipt_fd < 0)
        return -1;
    if (fstat(receipt_fd, &info) < 0) {
        int saved_errno = errno;
        close(receipt_fd);
        unlinkat(directory_fd, name, 0);
        errno = saved_errno;
        return -1;
    }
    if (!S_ISREG(info.st_mode)) {
        int saved_errno = EINVAL;
        close(receipt_fd);
        unlinkat(directory_fd, name, 0);
        errno = saved_errno;
        return -1;
    }
    if (fchmod(receipt_fd, 0600) < 0) {
        int saved_errno = errno;
        close(receipt_fd);
        unlinkat(directory_fd, name, 0);
        errno = saved_errno;
        return -1;
    }
    length = snprintf(line, sizeof(line), "%ld %ld\n", pid, tid);
    if (length <= 0 || (size_t)length >= sizeof(line)) {
        errno = EOVERFLOW;
        close(receipt_fd);
        unlinkat(directory_fd, name, 0);
        return -1;
    }
    while (offset < (size_t)length) {
        ssize_t written = write(receipt_fd, line + offset, (size_t)length - offset);
        if (written < 0 && errno == EINTR)
            continue;
        if (written <= 0) {
            int saved_errno = written == 0 ? EIO : errno;
            close(receipt_fd);
            unlinkat(directory_fd, name, 0);
            errno = saved_errno;
            return -1;
        }
        offset += (size_t)written;
    }
    if (close(receipt_fd) < 0) {
        int saved_errno = errno;
        unlinkat(directory_fd, name, 0);
        errno = saved_errno;
        return -1;
    }
    return 0;
}

static int establish_root(const char *view_root)
{
    if (view_root && chroot(view_root) < 0)
        return -1;
    if (chdir("/") < 0)
        return -1;
    return 0;
}

static int set_term_behavior(int ignore)
{
    struct sigaction action;

    memset(&action, 0, sizeof(action));
    action.sa_handler = ignore ? SIG_IGN : SIG_DFL;
    sigemptyset(&action.sa_mask);
    return sigaction(SIGTERM, &action, NULL);
}

static void hold_forever(void)
{
    for (;;)
        pause();
}

static int open_and_publish(int directory_fd, const char *name, long tid)
{
    int saved_errno;

    if (publish_receipt(directory_fd, name, (long)getpid(), tid) < 0) {
        saved_errno = errno;
        close(directory_fd);
        errno = saved_errno;
        return -1;
    }
    return close(directory_fd);
}

static void finish_thread_setup(int result, int error_number)
{
    pthread_mutex_lock(&thread_sync.mutex);
    thread_sync.result = error_number ? error_number : result;
    thread_sync.done = 1;
    pthread_cond_signal(&thread_sync.cond);
    pthread_mutex_unlock(&thread_sync.mutex);
}

struct thread_args {
    const char *view_root;
    int mixed;
    int directory_fd;
    const char *receipt_name;
};

static void *thread_worker(void *opaque)
{
    struct thread_args *args = opaque;
    int saved_errno = 0;
    int result = -1;

    if (args->mixed && unshare(CLONE_FS) < 0) {
        saved_errno = errno;
    } else if (establish_root(args->view_root) < 0) {
        saved_errno = errno;
    } else if (open_and_publish(args->directory_fd, args->receipt_name,
                                current_tid()) < 0) {
        saved_errno = errno;
    } else {
        result = 0;
    }
    if (result < 0 && args->directory_fd >= 0)
        close(args->directory_fd);
    finish_thread_setup(result, saved_errno);
    if (result == 0)
        hold_forever();
    return NULL;
}

static int wait_for_thread_setup(void)
{
    struct timespec deadline;
    int wait_result = 0;

    if (clock_gettime(CLOCK_REALTIME, &deadline) < 0)
        return -1;
    deadline.tv_sec += 10;
    pthread_mutex_lock(&thread_sync.mutex);
    while (!thread_sync.done && wait_result == 0)
        wait_result = pthread_cond_timedwait(&thread_sync.cond, &thread_sync.mutex,
                                             &deadline);
    if (!thread_sync.done) {
        pthread_mutex_unlock(&thread_sync.mutex);
        errno = wait_result == ETIMEDOUT ? ETIMEDOUT : wait_result;
        return -1;
    }
    wait_result = thread_sync.result;
    pthread_mutex_unlock(&thread_sync.mutex);
    if (wait_result > 0) {
        errno = wait_result;
        return -1;
    }
    return wait_result;
}

static int run_thread_mode(int mixed, int directory_fd, const char *receipt_name,
                           const char *view_root)
{
    struct thread_args args = { view_root, mixed, directory_fd, receipt_name };
    pthread_t worker;
    int result;
    int thread_result;

    thread_result = pthread_create(&worker, NULL, thread_worker, &args);
    if (thread_result != 0) {
        close(directory_fd);
        errno = thread_result;
        return -1;
    }
    result = wait_for_thread_setup();
    if (result < 0) {
        int saved_errno = errno;
        pthread_cancel(worker);
        pthread_join(worker, NULL);
        errno = saved_errno;
        return -1;
    }
    if (mixed)
        hold_forever();
    pthread_exit(NULL);
    return 0;
}

static int write_ready_byte(int fd, char value)
{
    ssize_t written;

    do {
        written = write(fd, &value, 1);
    } while (written < 0 && errno == EINTR);
    return written == 1 ? 0 : -1;
}

static void cancel_and_reap_child(pid_t child)
{
    const struct timespec base_delay = { 0, 20000000L };
    struct timespec delay = base_delay;
    struct timespec remaining;
    int saved_errno = errno;
    int status;
    pid_t waited;
    int attempt;

    do {
        waited = waitpid(child, &status, WNOHANG);
    } while (waited < 0 && errno == EINTR);
    if (waited == child || (waited < 0 && errno == ECHILD)) {
        errno = saved_errno;
        return;
    }
    (void)kill(child, SIGKILL);
    for (attempt = 0; attempt < 100; ++attempt) {
        do {
            waited = waitpid(child, &status, WNOHANG);
        } while (waited < 0 && errno == EINTR);
        if (waited == child || (waited < 0 && errno == ECHILD))
            break;
        if (waited < 0)
            break;
        if (nanosleep(&delay, &remaining) < 0) {
            if (errno != EINTR)
                break;
            delay = remaining;
        } else {
            delay = base_delay;
        }
    }
    do {
        waited = waitpid(child, &status, WNOHANG);
    } while (waited < 0 && errno == EINTR);
    errno = saved_errno;
}

static int run_daemon(int directory_fd, const char *receipt_name,
                      const char *view_root)
{
    int ready_socket[2];
    pid_t child;
    struct sigaction child_action;

    if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, ready_socket) < 0) {
        close(directory_fd);
        return -1;
    }
    memset(&child_action, 0, sizeof(child_action));
    child_action.sa_handler = SIG_DFL;
    sigemptyset(&child_action.sa_mask);
    if (sigaction(SIGCHLD, &child_action, NULL) < 0) {
        int saved_errno = errno;
        close(ready_socket[0]);
        close(ready_socket[1]);
        close(directory_fd);
        errno = saved_errno;
        return -1;
    }
    child = fork();
    if (child < 0) {
        int saved_errno = errno;
        close(ready_socket[0]);
        close(ready_socket[1]);
        close(directory_fd);
        errno = saved_errno;
        return -1;
    }
    if (child == 0) {
        int kept[] = { directory_fd, ready_socket[1] };
        int saved_errno;

        close(ready_socket[0]);
        if (setsid() < 0 || set_term_behavior(1) < 0 ||
            signal(SIGPIPE, SIG_IGN) == SIG_ERR ||
            redirect_stdio_and_close_fds(kept, 2) < 0 ||
            establish_root(view_root) < 0 ||
            publish_receipt(directory_fd, receipt_name, (long)getpid(),
                            current_tid()) < 0) {
            saved_errno = errno;
            write_ready_byte(ready_socket[1], 'E');
            close(ready_socket[1]);
            close(directory_fd);
            errno = saved_errno;
            report_error("daemon child setup");
            _exit(1);
        }
        if (write_ready_byte(ready_socket[1], 'R') < 0) {
            unlinkat(directory_fd, receipt_name, 0);
            close(directory_fd);
            close(ready_socket[1]);
            _exit(1);
        }
        close(directory_fd);
        close(ready_socket[1]);
        hold_forever();
    }
    close(ready_socket[1]);
    close(directory_fd);
    {
        struct pollfd poll_fd;
        char result;
        ssize_t count;

        poll_fd.fd = ready_socket[0];
        poll_fd.events = POLLIN | POLLHUP;
        poll_fd.revents = 0;
        {
            int poll_result = poll(&poll_fd, 1, 10000);
            if (poll_result <= 0) {
                int saved_errno = poll_result == 0 ? ETIMEDOUT : errno;
                close(ready_socket[0]);
                errno = saved_errno;
                cancel_and_reap_child(child);
                errno = saved_errno;
                return -1;
            }
        }
        do {
            count = read(ready_socket[0], &result, 1);
        } while (count < 0 && errno == EINTR);
        if (count != 1 || result != 'R') {
            int saved_errno = count < 0 ? errno : ECHILD;
            close(ready_socket[0]);
            errno = saved_errno;
            cancel_and_reap_child(child);
            errno = saved_errno;
            return -1;
        }
        poll_fd.revents = 0;
        {
            int poll_result = poll(&poll_fd, 1, 10000);
            if (poll_result <= 0) {
                int saved_errno = poll_result == 0 ? ETIMEDOUT : errno;
                close(ready_socket[0]);
                errno = saved_errno;
                cancel_and_reap_child(child);
                errno = saved_errno;
                return -1;
            }
        }
        do {
            count = read(ready_socket[0], &result, 1);
        } while (count < 0 && errno == EINTR);
        if (count != 0) {
            int saved_errno = count < 0 ? errno : ECHILD;
            close(ready_socket[0]);
            errno = saved_errno;
            cancel_and_reap_child(child);
            errno = saved_errno;
            return -1;
        }
        close(ready_socket[0]);
    }
    return 0;
}

static int parse_mode(const char *value, enum fixture_mode *mode)
{
    if (strcmp(value, "hold") == 0)
        *mode = MODE_HOLD;
    else if (strcmp(value, "daemon") == 0)
        *mode = MODE_DAEMON;
    else if (strcmp(value, "leader-exit") == 0)
        *mode = MODE_LEADER_EXIT;
    else if (strcmp(value, "mixed") == 0)
        *mode = MODE_MIXED;
    else
        return -1;
    return 0;
}

int main(int argc, char **argv)
{
    enum fixture_mode mode;
    const char *view_root = NULL;
    char receipt_name[NAME_MAX + 1];
    int directory_fd;
    int keep[1];
    size_t keep_count = 0;

    if ((argc != 3 && argc != 4) || parse_mode(argv[1], &mode) < 0 ||
        (mode == MODE_MIXED && argc != 4)) {
        fprintf(stderr, "usage: dependency_process MODE PID_RECEIPT [VIEW_ROOT]\n");
        return 2;
    }
    if (argc == 4)
        view_root = argv[3];
    if (split_receipt_path(argv[2], &directory_fd, receipt_name,
                           sizeof(receipt_name)) < 0) {
        report_error("receipt path");
        return 2;
    }
    if (mode != MODE_DAEMON && set_term_behavior(0) < 0) {
        report_error("SIGTERM setup");
        close(directory_fd);
        return 1;
    }
    keep[keep_count++] = directory_fd;
    if (redirect_stdio_and_close_fds(keep, keep_count) < 0) {
        report_error("descriptor setup");
        close(directory_fd);
        return 1;
    }
    if (mode == MODE_DAEMON) {
        if (run_daemon(directory_fd, receipt_name, view_root) < 0) {
            report_error("daemon setup");
            return 1;
        }
        return 0;
    }
    if (mode == MODE_LEADER_EXIT || mode == MODE_MIXED) {
        if (run_thread_mode(mode == MODE_MIXED, directory_fd, receipt_name,
                            view_root) < 0) {
            report_error("thread setup");
            return 1;
        }
        return 0;
    }
    if (establish_root(view_root) < 0) {
        report_error("root setup");
        close(directory_fd);
        return 1;
    }
    if (open_and_publish(directory_fd, receipt_name, current_tid()) < 0) {
        report_error("receipt publish");
        return 1;
    }
    hold_forever();
    return 0;
}
