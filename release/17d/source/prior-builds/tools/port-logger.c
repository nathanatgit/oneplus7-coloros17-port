// DEBUG ONLY: boot-time kernel log capture, installed as the ramdisk's /init (the real one stays at
// /system/bin/init in the ramdisk). Built static for aarch64 by tools/build-debug-b.sh.
//
// Why: the LineageOS sm8150 kernel has CONFIG_PSTORE and CONFIG_DEVTMPFS off, so a failed boot leaves no log.
// What: make device nodes by hand (major:minor from sysfs), mount the metadata partition, fork a child that
// copies /dev/kmsg into <metadata>/port-kmsg.txt in batches with fdatasync, then leave no trace in the
// ramdisk mount table (first-stage init's SwitchRoot() MS_MOVEs every mount and PLOG(FATAL)s on failure)
// and exec the real init with the original argv.
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <time.h>
#include <unistd.h>

static int find_partition(const char* partname, unsigned* maj, unsigned* min) {
    DIR* d = opendir("/sys/class/block");
    if (!d) return -1;
    struct dirent* e;
    int found = -1;
    while (found && (e = readdir(d))) {
        char path[512], buf[1024];
        snprintf(path, sizeof(path), "/sys/class/block/%s/uevent", e->d_name);
        int fd = open(path, O_RDONLY);
        if (fd < 0) continue;
        ssize_t n = read(fd, buf, sizeof(buf) - 1);
        close(fd);
        if (n <= 0) continue;
        buf[n] = 0;
        char want[128];
        snprintf(want, sizeof(want), "PARTNAME=%s\n", partname);
        if (!strstr(buf, want)) continue;
        char* p = strstr(buf, "MAJOR=");
        char* q = strstr(buf, "MINOR=");
        if (p && q && sscanf(p, "MAJOR=%u", maj) == 1 && sscanf(q, "MINOR=%u", min) == 1) found = 0;
    }
    closedir(d);
    return found;
}

static void klog(int kfd, const char* msg) {
    if (kfd >= 0) write(kfd, msg, strlen(msg));
}

int main(int argc, char** argv) {
    (void)argc;
    mkdir("/proc", 0755);
    mkdir("/sys", 0755);
    mkdir("/logmnt", 0755);
    mount("proc", "/proc", "proc", 0, NULL);
    mount("sysfs", "/sys", "sysfs", 0, NULL);
    mknod("/port-kmsg", S_IFCHR | 0600, makedev(1, 11));
    int kfd = open("/port-kmsg", O_RDWR | O_CLOEXEC);

    unsigned maj = 0, min = 0;
    int logfd = -1;
    if (find_partition("metadata", &maj, &min) == 0 &&
        mknod("/port-logdev", S_IFBLK | 0600, makedev(maj, min)) == 0 &&
        mount("/port-logdev", "/logmnt", "ext4", MS_NOATIME, NULL) == 0) {   // durability: fdatasync per batch
        rename("/logmnt/port-kmsg.txt", "/logmnt/port-kmsg.prev.txt");
        logfd = open("/logmnt/port-kmsg.txt", O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    }
    char msg[160];
    snprintf(msg, sizeof(msg), "<3>port-logger: metadata %u:%u logfd=%d errno=%d\n", maj, min, logfd, errno);
    klog(kfd, msg);

    if (logfd >= 0 && kfd >= 0) {
        pid_t pid = fork();
        if (pid == 0) {                       // child: copy kernel log records until the device reboots
            // One O_SYNC write per record was far too slow (v2 only got through the first 0.4 s of boot):
            // batch records and flush every 64 KiB or after 200 ms without new records.
            int rfd = open("/port-kmsg", O_RDONLY | O_NONBLOCK);
            static char buf[1 << 17];
            size_t used = 0;
            for (int fails = 0; rfd >= 0 && fails < 100;) {
                struct pollfd pfd = {.fd = rfd, .events = POLLIN};
                int pr = poll(&pfd, 1, 200);
                ssize_t n = 0;
                if (pr > 0) n = read(rfd, buf + used, sizeof(buf) - used - 1);
                if (n > 0) { used += n; fails = 0; }
                else if (n < 0 && errno == EPIPE) continue;              // records overwritten: skip ahead
                else if (n < 0 && errno != EAGAIN && errno != EINTR) fails++;
                // After 15 s of uptime, flush every record: a hard reset (PLK build 4/5) otherwise loses the
                // last batch, which is exactly the part that explains the crash.
                struct timespec now;
                clock_gettime(CLOCK_BOOTTIME, &now);
                int eager = now.tv_sec >= 15;
                if (used && (eager || pr == 0 || used > sizeof(buf) - 8192 || fails)) {
                    write(logfd, buf, used);
                    fdatasync(logfd);
                    used = 0;
                }
                if (fails) usleep(100000);
            }
            _exit(0);
        }
        usleep(200000);                       // let the child open the kmsg node before it is unlinked
    }
    if (logfd >= 0) close(logfd);
    umount2("/logmnt", MNT_DETACH);           // child keeps its fds; mount leaves the table
    umount2("/sys", MNT_DETACH);
    umount2("/proc", MNT_DETACH);
    unlink("/port-logdev");
    unlink("/port-kmsg");
    rmdir("/logmnt");
    if (kfd >= 0) close(kfd);

    execv("/system/bin/init", argv);
    return 127;                               // only reached if exec fails (kernel then panics: no init)
}
