# Spark v0.2.0

Flutter + Rust 的 Android 本地/在线音乐播放器，带 USB DAC 直推。

本次重点修复**输出模式设置**与 **USB DAC 直推**，并首次在 Galaxy S24 Ultra 上完成真机验证。

## 下载

`Spark-v0.2.0.apk`（约 48 MB，release 签名）

- 覆盖安装即可，数据保留（收藏、播放列表、缓存）
- 已实测：arm64-v8a / armeabi-v7a / x86_64 三个 ABI 的 Rust 原生库齐全

## 本次修复

### 1. 输出模式设置完全无效 ← 核心问题

**症状**：无论选「Android 共享输出」「高解析（Oboe）」还是「USB DAC 直连」，实际使用的引擎都不变。

**根因（一个接线错误）**：`PlayerService` 里早就写好了正确的方法：

```dart
Future<void> setAudioEnginePreference(AudioEnginePreference preference) async {
  await _preferencesService.setAudioEnginePreference(preference);
  await initAudio();
  await _sessionManager.syncRouteSelection(     // ← 触发引擎重算
    reason: 'audio engine preference changed',
  );
}
```

但**设置页绕过它，直接调了底层存储**：

```dart
await ref.read(uac2PreferencesServiceProvider).setAudioEnginePreference(choice);
ref.invalidate(audioEnginePreferenceProvider);   // 只刷新了界面标签
```

播放时使用的引擎是 `_sessionManager.selectedMode`，而它**只在启动时和音频路由变化时**重算。保存偏好不触发这两者 —— 于是标签变了、引擎没变。

**修复**：设置页改走 `PlayerService`；并加源码级守护测试，防止再被绕过。

### 2. 独占内部通路被普通手机误触发

```dart
if (supportsHiResInternal) { ... return dapInternalHighRes; }   // 在读取用户偏好之前就返回了
```

而 `hiResInternal` 的条件是「内部路由且最高采样率 > 48kHz」—— **每一台近年旗舰机都满足**。于是用户偏好从未被读取。

**修复**：抽出可测的 `resolveInternalEngine()`，独占通路只留给**确认是 DAP** 的设备。

### 3. 改模式要暂停再播放才生效

`_syncRouteSelection` 在播放中只更新「请求引擎」，真正的引擎要等下次播放请求（原设计如此，避免中途切换爆音）。结果设置看起来失效。

**修复**：新增 `_reapplyEngineWhilePlaying()`，复用项目已有的「销毁旧引擎 → 建新引擎 → 从当前位置重新起播」流程，**播放中即时切换，不中断**。

### 4. USB 直推失效（两处闸门）

**症状**：只有手机音量条出现「电脑图标」（Android 已路由到 USB）时才生效。

**根因**：引擎要求「Android **当前正路由**到 USB」—— 但直推的意义正是**自己接管 USB、绕开 Android 路由**，形成死结。而且判断有**两处**，第二处还会抛 `StateError`：

```dart
if (!deviceInfo.hasUsbDac) {
  throw StateError('Rust USB engine requires a USB DAC');
}
```

**修复**：两处统一为「DAC 已插入**且已授权**」，并抽出 `canUseDirectUsbEngine()`。授权判断是必要的 —— `UsbManager.deviceList` 包含用户拒绝授权的设备。

### 5. 运行中插上 DAC 检测不到

**症状**：App 运行中插 DAC 没反应；杀掉 App、插上、再启动才能检测到。

**根因**：

```dart
final uac2DevicesProvider = FutureProvider<List<Uac2DeviceInfo>>((ref) async {
  return service.listDevices();     // 只算一次，之后永久缓存
});
```

没有任何东西在插拔时让它重算。

**修复**：监听插拔事件并重新列举。（Kotlin 侧的 USB 广播与 Dart 处理器本身是完整的，只是没人刷新这个 provider。）

### 6. 「拔掉 USB DAC 暂停播放」没有界面

该行为**早已实现且默认开启**，但界面上完全没有开关，无法发现或更改。

**修复**：设置 → AUDIO 新增开关。

### 7. 新增「音频诊断」卡片

设置页原本只显示**请求的**模式，所以「静默回退」和「成功」长得一模一样。

现在显示：请求引擎 / **实际引擎**（与请求不符时变色）/ USB 接口是否已占用 / USB 数据流是否稳定 / 回退原因。

**故意降级**（在线歌曲未缓存时只能走 Android 播放器）与**真失败**分开显示，前者是信息提示，后者才是警告。

### 8. 若干显示问题

- `USB DAC` 一行原本显示手机型号 `SM-S9280`（路由标签回退成了设备产品名）
- `音频与 USB` 一行原本显示英文 `Resampled fallback`（服务层拼的英文字符串漏进中文界面）
- `dapInternalHighRes` 和 `rustOboe` 原本共用同一个标签，无法区分

## 真机验证记录（Galaxy S24 Ultra / SM-S9280 / Android 16）

**输出模式双向切换**：

```
enginePref=rustOboe   → [Session] Selected RUST_OBOE
enginePref=exoPlayer  → [Session] Selected NORMAL_ANDROID
```

**USB DAC 直推**（播放中点选，在线歌曲已缓存）：

```
mode=USB_DAC_EXPERIMENTAL, selected=USB_DAC_EXPERIMENTAL
backend="Rust engine via libusb direct USB (verified)"
route=USB-Audio - DTC 480
usbRegistered=true   usbClaimed=true
mixerManaged=false                         ← 绕开 Android 混音器
passthrough=true     resampler=false       ← 直通，无重采样
underruns=0          driftMs=0             ← 零欠载
transport=PCM/16/2 @ 48000Hz

dumpsys audio → Devices: usb_headset(4000000)   ← Android 侧路由到 USB
```

**热插拔**：运行中插入 DTC 480 → 设置页由「未检测到 USB DAC」变为「USB-Audio - DTC 480」，USB 选项由置灰变为可点。

## 输出模式选择对在线歌曲的规则

| 情况 | 使用的引擎 |
|---|---|
| 本地歌曲 | 跟随设置 |
| 在线歌曲**已缓存** | 跟随设置 |
| 在线歌曲**未缓存** | Android 播放器（`https://` 不是磁盘文件，Rust 与 USB 引擎都无法打开） |

未缓存时诊断卡片会写明原因。缓存完成后从下次播放起跟随设置。

## 已知未处理

`player_service.dart` 里的 `_appInForeground` 字段：生命周期回调在写它，但**全代码库没有任何地方读它**。旁边注释说明它本是为「后台时 USB 传输被挂起、直推假失败」准备的。它位于关键播放路径，未做改动。

## 构建

```powershell
.\tools\build_apk.ps1
```

不要使用裸 `flutter build apk`：cargokit 不会把构建工具的退出码传出来，可能静默产出没有 `.so` 的 APK。构建脚本会校验三个 ABI 里都有 `librust_lib_flick_player.so`。

## 测试

```bash
flutter test
```

121 个测试，覆盖收藏、专辑详情页、音频诊断、引擎选择规则、多选栏布局、在线分页、缓存、播放列表、热插拔偏好等。
