/* sctiled.m — SCCTile 指令目录守护进程 (v1.3.0)
 * role: mobile 用户 launchd daemon，entitlement 豁免沙盒读快捷指令库。
 * 直读 /var/mobile/Library/Shortcuts/Shortcuts.sqlite，
 * 把「指令名 → uuid/glyph/color」目录发布到
 * /var/mobile/Library/Preferences/com.qwq.scctile.cache.plist（SpringBoard 沙盒内可读）。
 * 触发：启动 + 收到 darwin 通知 com.qwq.scctile/refresh + 定期兜底刷新。
 * 状态写回主配置域 ResolverState（ok/error），SpringBoard 可读。
 */

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import <notify.h>
#import <dispatch/dispatch.h>
#import <sys/stat.h>
#import <errno.h>
#import <fcntl.h>
#import <unistd.h>
#import <Security/Security.h>
/* SecTask API 为私有符号，SDK 头文件未声明，运行时存在于 Security.framework */
typedef struct CF_BRIDGED_TYPE(id) SecTaskStruct *SecTaskRef;
extern SecTaskRef SecTaskCreateFromSelf(CFAllocatorRef allocator);
extern CFTypeRef SecTaskCopyValueForEntitlement(SecTaskRef task, CFStringRef entitlement, CFErrorRef *error);
#import <errno.h>
#import <fcntl.h>
#import <unistd.h>
#import <Security/Security.h>
/* SecTask API 为私有符号，SDK 头文件未声明，运行时存在于 Security.framework */
typedef struct CF_BRIDGED_TYPE(id) SecTaskStruct *SecTaskRef;
extern SecTaskRef SecTaskCreateFromSelf(CFAllocatorRef allocator);
extern CFTypeRef SecTaskCopyValueForEntitlement(SecTaskRef task, CFStringRef entitlement, CFErrorRef *error);

static NSString * const kDBPath = @"/var/mobile/Library/Shortcuts/Shortcuts.sqlite";
static NSString * const kCachePath = @"/var/mobile/Library/Preferences/com.qwq.scctile.cache.plist";
static NSString * const kDomain = @"com.qwq.scctile";
static NSString * const kRefreshNotification = @"com.qwq.scctile/refresh";

static void SCTLog(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    static NSString * const kLogPath = @"/var/mobile/Library/sctiled.log";
    NSString *line = [NSString stringWithFormat:@"[%@][sctiled] %@\n",
                      [[NSDate date] descriptionWithLocale:nil], message];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:kLogPath error:nil];
    if ([attrs fileSize] > 256 * 1024) [fm removeItemAtPath:kLogPath error:nil];

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
    if (!handle) {
        [line writeToFile:kLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [handle seekToEndOfFile];
    [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
}

static void PublishState(NSString *state, NSString *message)
{
    CFPreferencesSetAppValue(CFSTR("ResolverState"), (__bridge CFTypeRef)state, (__bridge CFStringRef)kDomain);
    CFPreferencesSetAppValue(CFSTR("ResolverMessage"), (__bridge CFTypeRef)message, (__bridge CFStringRef)kDomain);
    CFPreferencesSetAppValue(CFSTR("ResolverUpdated"), (__bridge CFTypeRef)[[NSDate date] descriptionWithLocale:nil], (__bridge CFStringRef)kDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    NSLog(@"[sctiled] STATE state=%@ message=%@", state, message);
}

static BOOL TableHasColumn(sqlite3 *db, NSString *table, NSString *column)
{
    NSString *pragma = [NSString stringWithFormat:@"PRAGMA table_info(%@)", table];
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(db, pragma.UTF8String, -1, &st, NULL) != SQLITE_OK) return NO;
    BOOL found = NO;
    while (sqlite3_step(st) == SQLITE_ROW) {
        const unsigned char *nameText = sqlite3_column_text(st, 1);
        if (!nameText) continue;
        if ([[NSString stringWithUTF8String:(const char *)nameText] caseInsensitiveCompare:column] == NSOrderedSame) {
            found = YES;
            break;
        }
    }
    sqlite3_finalize(st);
    return found;
}

static BOOL RefreshCatalog(void)
{
    sqlite3 *db = NULL;
    /* 原始 open errno：区分 unix 权限(EACCES)与沙盒/保护(EPERM 等) */
    int probeFd = open(kDBPath.fileSystemRepresentation, O_RDONLY);
    int probeErrno = errno;
    SCTLog(@"raw open fd=%d errno=%d(%s) uid=%d", probeFd, probeErrno, strerror(probeErrno), (int)getuid());
    if (probeFd >= 0) close(probeFd);

    SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
    if (task) {
        CFTypeRef nsb = SecTaskCopyValueForEntitlement(task, CFSTR("com.apple.private.security.no-sandbox"), NULL);
        CFTypeRef crq = SecTaskCopyValueForEntitlement(task, CFSTR("com.apple.private.security.container-required"), NULL);
        SCTLog(@"entitlement view: no-sandbox=%@ container-required=%@", (__bridge id)nsb, (__bridge id)crq);
        if (nsb) CFRelease(nsb);
        if (crq) CFRelease(crq);
        CFRelease(task);
    } else {
        SCTLog(@"SecTaskCreateFromSelf failed");
    }

    int rc = sqlite3_open_v2(kDBPath.UTF8String, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, NULL);
    if (rc != SQLITE_OK) {
        const char *msg = db ? sqlite3_errmsg(db) : "no handle";
        NSLog(@"[sctiled] DB_OPEN_FAILED rc=%d msg=%s", rc, msg);
        SCTLog(@"DB open FAILED rc=%d msg=%s", rc, msg);
        if (db) sqlite3_close(db);
        PublishState(@"error", [NSString stringWithFormat:@"db open failed rc=%d (%s)", rc, msg]);
        return NO;
    }
    sqlite3_busy_timeout(db, 1000);

    /* 列探测（跟 CSL 同策略：旧 schema 缺列时优雅降级） */
    BOOL hasIconJoin = TableHasColumn(db, @"ZSHORTCUT", @"ZICON")
        && TableHasColumn(db, @"ZSHORTCUTICON", @"Z_PK");
    BOOL hasGlyph = hasIconJoin && TableHasColumn(db, @"ZSHORTCUTICON", @"ZGLYPHNUMBER");
    BOOL hasColor = hasIconJoin && TableHasColumn(db, @"ZSHORTCUTICON", @"ZBACKGROUNDCOLORVALUE");
    BOOL hasTombstone = TableHasColumn(db, @"ZSHORTCUT", @"ZTOMBSTONED");
    BOOL hasHidden = TableHasColumn(db, @"ZSHORTCUT", @"ZHIDDENFROMLIBRARYANDSYNC");

    NSMutableString *sql = [NSMutableString stringWithFormat:
        @"SELECT s.ZNAME, s.ZWORKFLOWID, %@, %@ "
         "FROM ZSHORTCUT s ",
        hasGlyph ? @"i.ZGLYPHNUMBER" : @"NULL",
        hasColor ? @"i.ZBACKGROUNDCOLORVALUE" : @"NULL"];
    if (hasIconJoin) [sql appendString:@"LEFT JOIN ZSHORTCUTICON i ON s.ZICON = i.Z_PK "];
    [sql appendString:
        @"WHERE s.ZWORKFLOWID IS NOT NULL AND length(s.ZWORKFLOWID) > 0 "
         "AND s.ZNAME IS NOT NULL AND length(trim(s.ZNAME)) > 0 "];
    if (hasTombstone) [sql appendString:@"AND COALESCE(s.ZTOMBSTONED, 0) = 0 "];
    if (hasHidden) [sql appendString:@"AND COALESCE(s.ZHIDDENFROMLIBRARYANDSYNC, 0) = 0 "];
    /* 同名指令取 Z_PK 最大（最近编辑）的一条 */
    [sql appendString:@"GROUP BY s.ZNAME HAVING MAX(s.Z_PK) "];

    sqlite3_stmt *st = NULL;
    rc = sqlite3_prepare_v2(db, sql.UTF8String, -1, &st, NULL);
    if (rc != SQLITE_OK) {
        NSLog(@"[sctiled] QUERY_PREPARE_FAILED rc=%d msg=%s", rc, sqlite3_errmsg(db));
        SCTLog(@"query prepare FAILED rc=%d msg=%s", rc, sqlite3_errmsg(db));
        sqlite3_close(db);
        PublishState(@"error", [NSString stringWithFormat:@"query prepare failed rc=%d", rc]);
        return NO;
    }

    NSMutableDictionary<NSString *, NSDictionary *> *catalog = [NSMutableDictionary dictionary];
    while (sqlite3_step(st) == SQLITE_ROW) {
        const unsigned char *nameText = sqlite3_column_text(st, 0);
        const unsigned char *uuidText = sqlite3_column_text(st, 1);
        if (!nameText || !uuidText) continue;

        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        entry[@"uuid"] = [NSString stringWithUTF8String:(const char *)uuidText];
        if (sqlite3_column_type(st, 2) != SQLITE_NULL) entry[@"glyph"] = @(sqlite3_column_int(st, 2));
        if (sqlite3_column_type(st, 3) != SQLITE_NULL) entry[@"color"] = @(sqlite3_column_int64(st, 3));
        catalog[[NSString stringWithUTF8String:(const char *)nameText]] = entry;
    }
    sqlite3_finalize(st);
    sqlite3_close(db);

    /* 发布：XML plist（带注释格式无所谓，机器读） */
    NSError *err = nil;
    NSDictionary *out = @{@"catalog": catalog,
                          @"updated": [[NSDate date] descriptionWithLocale:nil]};
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:out
                                                              format:NSPropertyListXMLFormat_v1_0
                                                             options:0
                                                               error:&err];
    if (!data || ![data writeToFile:kCachePath atomically:YES]) {
        NSLog(@"[sctiled] CACHE_WRITE_FAILED %@", err);
        SCTLog(@"cache write FAILED %@", err);
        PublishState(@"error", @"cache write failed");
        return NO;
    }

    NSLog(@"[sctiled] CATALOG published count=%lu", (unsigned long)[catalog count]);
    SCTLog(@"refresh done count=%lu", (unsigned long)[catalog count]);
    NSUInteger i = 0;
    for (NSString *k in catalog) {
        if (i++ >= 3) break;
        NSDictionary *e = catalog[k];
        SCTLog(@"item \"%@\" uuid=%@ glyph=%@ color=%@", k, e[@"uuid"], e[@"glyph"], e[@"color"]);
    }
    PublishState(@"ok", [NSString stringWithFormat:@"count=%lu", (unsigned long)[catalog count]]);
    return YES;
}

int main(int argc, char **argv, char **envp)
{
    @autoreleasepool {
        NSLog(@"[sctiled] started pid=%d", (int)getpid());
        SCTLog(@"daemon started pid=%d uid=%d", (int)getpid(), (int)getuid());
        PublishState(@"starting", @"daemon booted");

        /* 启动先读一次 */
        RefreshCatalog();

        /* darwin 通知：SpringBoard 点击磁贴发现缺指令时请求刷新 */
        int token = 0;
        notify_register_dispatch(kRefreshNotification.UTF8String,
                                 &token,
                                 dispatch_get_global_queue(QOS_CLASS_UTILITY, 0),
                                 ^(int token) {
                                     NSLog(@"[sctiled] refresh requested");
                                     SCTLog(@"refresh requested (darwin notify)");
                                     RefreshCatalog();
                                 });

        /* 兜底：每 5 分钟静默刷新（指令增删改后不依赖通知也能自愈） */
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                                         dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, 300 * NSEC_PER_SEC), 300 * NSEC_PER_SEC, 10 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer, ^{
            RefreshCatalog();
        });
        dispatch_resume(timer);

        dispatch_main();
    }
    return 0;
}
