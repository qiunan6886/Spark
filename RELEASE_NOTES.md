# Spark v0.1.0

Flutter + Rust 的 Android 本地/在线音乐播放器，带 USB DAC 直推。

**注意：本次改动没有在任何设备上验证过** —— 构建期间手机一直无法通过 adb 连接。
单元测试（108 个）与静态分析全部通过，但真机行为未经确认。

## 下载

`app-release.apk`（约 48 MB，release 签名）

- 覆盖安装即可，数据保留（收藏、播放列表、缓存）
- SHA-256 见 Release 附件旁说明

## 本次修复

### 1. 在线歌曲收藏失效

**症状**：在线歌曲点❤️后心形不亮，也不会出现在「我喜欢的」。

**原因**：收藏的 id 集合是从「已解析成歌曲的列表」反推出来的：

```dart
final songs = await service.getFavorites();   // 从曲库解析 id → Song
final ids = songs.map((s) => s.id).toSet();   // ← 在线歌曲解析不到，被丢弃
```

在线歌曲的 id（如 `audius:xxx`）在本地曲库里查不到，所以解析时被丢弃，id 也就没进集合。
收藏其实已经存进本地存储，只是立刻变得不可见。

**修复**：id 改为直接读存储的原始值；同时为在线收藏保存一份轻量记录
（标题/艺人/封面/时长），让它也能出现在「我喜欢的」里。

### 2. 新增专辑详情页

**症状**：点专辑行直接开始播放，看不到里面有哪些歌。

**修复**：点专辑行进入二级歌曲列表（封面、专辑名、艺人、曲目数、播放全部），
列表支持左滑和长按多选。行尾的播放按钮行为不变，仍是播放整张专辑。

### 3. USB DAC 直推疑似失效

**症状**：只有手机音量条出现「电脑图标」（即 Android 已把输出路由到 USB）时才生效。

**原因**：判断条件是「Android **当前正路由**到 USB」——

```kotlin
val hasUsbAudioRoute = routeType == "usb"   // 当前「最佳」输出设备
"hasUsbDac" to hasUsbAudioRoute
```

但直推引擎的意义正是**自己接管 USB、绕开 Android 路由**。于是形成一个死结：
它要求 Android 先路由过去才肯启动。只要路由还没切过去（也就是最需要直推的场景），
就静默回退到 Android 播放器。

这个判断有**两处**，第二处还会抛 `StateError`：

```dart
if (!deviceInfo.hasUsbDac) {
  throw StateError('Rust USB engine requires a USB DAC');   // 引擎选择对了也会被拦下
}
```

**修复**：两处统一改为「DAC 已插入**且已授权**」即可，并抽出可测的纯函数
`canUseDirectUsbEngine()`。会话层（`audio_session_manager`）本来就是正确写法，
这次是把 `player_service` 对齐到代码库既有约定。

同时补了授权判断：`UsbManager.deviceList` 包含用户拒绝授权的设备，
只看"已插入"会把静默回退变成硬报错。

### 4. 新增「音频诊断」卡片

设置页原本只显示**请求的**模式，所以「静默回退到 Android」和「成功直推」长得一模一样。

现在设置 → AUDIO 下方新增诊断卡片：

| 项 | 说明 |
|---|---|
| 请求引擎 | 你选择的 |
| 实际引擎 | **真正在跑的**；与请求不符时变琥珀色 |
| USB 接口 | 已占用 / 未占用 |
| USB 数据流 | 稳定 / 不稳定 |
| 回退原因 | 发生回退时直接显示原因 |

**要看直推是否真的生效，请看「实际引擎」这一行。**

### 5. 在线列表去掉行尾下载按钮

左滑和多选栏已经能完成下载，按钮是第三种重复入口，已移除。

### 6. 多选栏缺少下载按钮

**症状**：在线列表长按多选后，底部操作栏看不到下载按钮。

**原因**：Material 3 的 `IconButton` 默认点击目标是 **48×48**。
多选栏里几个按钮加计数文字再加「全选」，在窄屏上溢出——

```
A RenderFlex overflowed by 15 pixels on the right.
```

尾部的动作按钮被挤出屏幕。

**修复**：按钮改为紧凑尺寸（40×40、`padding: zero`、`VisualDensity.compact`），
计数文字改为可省略。已加回归测试（320dp 窄屏 + 12 项选中）。

## 已知未验证项

- 上述真机行为全部未验证
- `player_service.dart` 里的 `_appInForeground` 字段：生命周期回调在写它，
  但**全代码库没有任何地方读它**。旁边注释说明它本是为「后台时 USB 传输被挂起、
  直推假失败」准备的。它在关键播放路径上，未做改动。

## 构建

```powershell
.\tools\build_apk.ps1
```

不要使用裸 `flutter build apk`：cargokit 不会把构建工具的退出码传出来，
可能静默产出没有 `.so` 的 APK。构建脚本会校验三个 ABI 里都有
`librust_lib_flick_player.so`。

## 测试

```bash
flutter test
```

108 个测试，覆盖收藏、专辑页、音频诊断、引擎选择规则、多选栏布局、
在线分页、缓存、播放列表等。
