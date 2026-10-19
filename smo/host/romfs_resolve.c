// RomFS 路径解析的实现。见 romfs_resolve.h。
#include "romfs_resolve.h"
#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#if defined(_WIN32)
#define SMO_DIRSEP '\\'
#else
#define SMO_DIRSEP '/'
#endif

static int find_named(const char *dir, const char *name, char *out, size_t n) {
    char p1[1024], p2[1024];
    // ① 直接放在目录下：<dir>/<want>
    if (snprintf(p1, sizeof p1, "%s%c%s", dir, SMO_DIRSEP, name) >= (int)sizeof p1) return 0;
    struct stat st;
    if (stat(p1, &st) == 0 && S_ISDIR(st.st_mode)) {
        snprintf(out, n, "%s", p1);
        return 1;
    }
    // ② 一层包装目录：<dir>/<任意目录>/<want>
    DIR *d = opendir(dir);
    if (!d) return 0;
    struct dirent *e;
    int found = 0;
    while ((e = readdir(d)) && !found) {
        if (e->d_name[0] == '.') continue;
        if (snprintf(p2, sizeof p2, "%s%c%s%c%s", dir, SMO_DIRSEP, e->d_name, SMO_DIRSEP, name) >= (int)sizeof p2)
            continue;
        if (stat(p2, &st) == 0 && S_ISDIR(st.st_mode)) {
            snprintf(out, n, "%s", p2);
            found = 1;
        }
    }
    closedir(d);
    return found;
}

static int find_in(const char *dir, const char *upper, const char *lower, char *out, size_t n) {
    /* nxnative's public layout uses Documents/romfs.  Keep the existing
     * SMO Resource/RomFS layout for already-installed data and accept both
     * spellings so a user can copy the folder directly from Files.app. */
    return find_named(dir, lower, out, n) || find_named(dir, upper, out, n);
}

int dm_romfs_path(char *out, size_t n, const char *docs_dir) {
    return find_in(docs_dir, "RomFS", "romfs", out, n);
}

int dm_exefs_path(char *out, size_t n, const char *docs_dir) {
    return find_in(docs_dir, "ExeFS", "exefs", out, n);
}
