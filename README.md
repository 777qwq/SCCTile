# SCCTile — 控制中心快捷指令磁贴

iOS 16.3 · Dopamine rootless。在控制中心添加自定义「快捷指令」磁贴，点击运行对应指令，支持配置开关与指令选择。

## 架构

- 依赖 [CCSupport](https://github.com/opa334/CCSupport)（opa334 / Dopamine 作者维护），本插件以 **CCSupport Provider bundle** 形式注册进控制中心模块系统
- 每条配置的快捷指令 = 一个 1×1 磁贴（图标居中，与原生磁贴同形态）
- 点击磁贴 → `shortcuts://run-shortcut?name=` URL 方案运行指令
- 配置文件变更 → 5 秒轮询感知 → darwin 通知 `com.opa334.ccsupport/ReloadProviders` 免注销增删磁贴

## 安装

1. **先装 CCSupport**（Sileo 添加源 `https://opa334.github.io/` 后搜索安装；Depends 已声明会自动拉取）
2. 安装本插件 deb
3. 注销，进入控制中心编辑界面（长按空白处），找到磁贴拖到网格

## 配置

文件：`/var/mobile/Library/Preferences/com.qwq.scctile.plist`（首次启动自动生成模板，Filza 编辑）

```xml
<!-- enabled: 总开关，false 时全部磁贴隐藏 -->
<!-- shortcuts: 数组每项 = 一个磁贴，顺序 = 磁贴顺序 -->
<dict>
    <key>enabled</key> <true/>
    <key>shortcuts</key>
    <array>
        <dict>
            <key>name</key>   <string>回家开灯</string>   <!-- 快捷指令的准确名称 -->
            <key>symbol</key> <string>house.fill</string> <!-- SF Symbol 图标，可删 -->
        </dict>
        <!-- 也支持纯字符串简写：<string>指令名</string> -->
    </array>
</dict>
```

- 改完保存约 5 秒生效：**增删磁贴即时生效**；改名/改图标若无变化，注销一次
- 指令名必须在快捷指令 App 里完全一致（同名取第一条）

## 已知边界

- 点击磁贴运行时会短暂拉起快捷指令 App（URL 方案运行的系统行为）；如需无感后台运行，后续版本可攻 ShortcutsKit 进程内运行
- 图标为单色 glyph（SF Symbol），跟随原生磁贴渲染

## 构建

GitHub Actions（`.github/workflows/build.yml`）：push 到 main/master 自动构建，`macos-latest` + Theos + Apple clang，产物 arm64e rootless deb（Artifacts 下载）。

本地验证（可选，仅语法检查用）：`export THEOS=~/theos && make package FINALPACKAGE=1`

## 版本

- 1.0.0 — 首版：CCSupport Provider + 配置表热更新 + URL 方案运行
