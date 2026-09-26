#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>

#import "SCCTileProvider.h"

/* CCSupport 内部类（非系统类）：等它出现再挂钩，避免 %ctor 时序问题 */
static void (*orig_reloadProviders)(id self, SEL _cmd);

static void hook_reloadProviders(id self, SEL _cmd)
{
    orig_reloadProviders(self, _cmd);

    /* 每次 CCSupport 重建 provider 字典后补插我们的 provider */
    NSMutableDictionary *providers = [[self valueForKey:@"moduleProvidersByIdentifier"] mutableCopy];
    if (providers && ![providers objectForKey:@"com.qwq.scctile"]) {
        providers[@"com.qwq.scctile"] = [[SCCTileProvider alloc] init];
        [self setValue:providers forKey:@"moduleProvidersByIdentifier"];
    }
}

__attribute__((constructor))
static void SCCTileInit(void)
{
    /* 配置模板：文件不存在才写 */
    [SCCTileProvider writeDefaultConfigIfMissing];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        /* 轮询等 CCSupport 的 provider manager 类注册（Dopamine/ElleKit 下 tweak 类注册晚于 %ctor） */
        Class managerClass = nil;
        for (int i = 0; i < 60; i++) {
            managerClass = objc_getClass("CCSModuleProviderManager");
            if (managerClass) break;
            [NSThread sleepForTimeInterval:0.5];
        }
        if (!managerClass) return; /* 没装 CCSupport，静默退出 */

        id shared = ((id(*)(id, SEL))objc_msgSend)((id)managerClass, NSSelectorFromString(@"sharedInstance"));
        if (!shared) return;

        Method m = class_getInstanceMethod(managerClass, NSSelectorFromString(@"_reloadProviders"));
        if (!m) return;
        MSHookMessageEx(managerClass, NSSelectorFromString(@"_reloadProviders"),
                        (IMP)hook_reloadProviders, (IMP *)&orig_reloadProviders);

        /* 若 CCSupport 已完成过 reload，主动再走一次触发补插 */
        ((void(*)(id, SEL))objc_msgSend)(shared, NSSelectorFromString(@"_reloadProviders"));

        /* 配置热更新轮询（仅 SpringBoard 进程） */
        NSString *processName = [[NSProcessInfo processInfo] processName];
        if ([processName containsString:@"SpringBoard"]) {
            [SCCTileProvider startConfigWatch];
        }
    });
}
