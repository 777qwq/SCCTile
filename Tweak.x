#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>

#import "SCCTileProvider.h"

/* CCSupport 内部类（非系统类）：等它出现再挂钩，避免 %ctor 时序问题 */
static void (*orig_populateCache)(id self, SEL _cmd);

/* 在 CCSupport 重建 provider→模块缓存【之前】把我们的 provider 塞进字典，
 * 这样任何 reload 路径的枚举都会包含我们（v1.0.1 只补字典没重建缓存，是空磁贴根因） */
static void hook_populateCache(id self, SEL _cmd)
{
    NSMutableDictionary *providers = [[self valueForKey:@"moduleProvidersByIdentifier"] mutableCopy];
    if (![providers objectForKey:@"com.qwq.scctile"]) {
        if (!providers) providers = [NSMutableDictionary new];
        providers[@"com.qwq.scctile"] = [[SCCTileProvider alloc] init];
        [self setValue:providers forKey:@"moduleProvidersByIdentifier"];
    }
    [SCCTileProvider logFormat:@"hook_populateCache: provider ensured in dict"];
    orig_populateCache(self, _cmd);
}

__attribute__((constructor))
static void SCCTileInit(void)
{
    [SCCTileProvider writeDefaultConfigIfMissing];

    NSString *processName = [[NSProcessInfo processInfo] processName];
    [SCCTileProvider logFormat:@"ctor in %@", processName];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        /* 轮询等 CCSupport 的 provider manager 类注册（Dopamine/ElleKit 下 tweak 类注册晚于 %ctor） */
        Class managerClass = nil;
        for (int i = 0; i < 60; i++) {
            managerClass = objc_getClass("CCSModuleProviderManager");
            if (managerClass) break;
            [NSThread sleepForTimeInterval:0.5];
        }
        if (!managerClass) {
            [SCCTileProvider logFormat:@"ctor: CCSModuleProviderManager NOT found (CCSupport missing?)"];
            return;
        }
        [SCCTileProvider logFormat:@"ctor: manager class found"];

        id shared = ((id(*)(id, SEL))objc_msgSend)((id)managerClass, NSSelectorFromString(@"sharedInstance"));
        if (!shared) {
            [SCCTileProvider logFormat:@"ctor: sharedInstance nil"];
            return;
        }

        SEL populateSel = NSSelectorFromString(@"_populateProviderToModuleCache");
        Method m = class_getInstanceMethod(managerClass, populateSel);
        if (!m) {
            [SCCTileProvider logFormat:@"ctor: _populateProviderToModuleCache NOT found"];
            return;
        }
        MSHookMessageEx(managerClass, populateSel, (IMP)hook_populateCache, (IMP *)&orig_populateCache);
        [SCCTileProvider logFormat:@"ctor: hook installed"];

        /* 主动走一次缓存重建，让本次启动立即注册 */
        ((void(*)(id, SEL))objc_msgSend)(shared, populateSel);
        [SCCTileProvider logFormat:@"ctor: initial populate done"];

        /* 配置热更新轮询（仅 SpringBoard 进程） */
        if ([processName containsString:@"SpringBoard"]) {
            [SCCTileProvider startConfigWatch];
            [SCCTileProvider logFormat:@"ctor: config watch started"];
        }
    });
}
