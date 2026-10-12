// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class L10nZh extends L10n {
  L10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Spark';

  @override
  String get navHome => '首页';

  @override
  String get navLibrary => '曲库';

  @override
  String get navSearch => '搜索';

  @override
  String get navSettings => '设置';

  @override
  String get greeting => '你好';

  @override
  String get greeting0 => '今天也要好好听歌';

  @override
  String get greeting1 => '愿音乐陪你一整天';

  @override
  String get greeting2 => '慢下来，听一首歌';

  @override
  String get greeting3 => '让旋律替你说话';

  @override
  String get greeting4 => '好音乐值得等待';

  @override
  String get greeting5 => '此刻，只属于你';

  @override
  String get greeting6 => '用耳朵拥抱世界';

  @override
  String get greeting7 => '每一次播放都是新的开始';

  @override
  String get greeting8 => '静下心来，听点好的';

  @override
  String get greeting9 => '音乐是最好的解药';

  @override
  String get sectionCurated => '精选推荐';

  @override
  String get dailyMix => '每日歌单';

  @override
  String dailyMixSubtitle(int count) {
    return '每天换一批 · $count 首';
  }

  @override
  String get forYou => '猜你喜欢';

  @override
  String forYouSubtitle(int count) {
    return '根据你的收听 · $count 首';
  }

  @override
  String get forYouNoHistory => '来自 Audius 和 Jamendo 的推荐';

  @override
  String get recentlyPlayed => '最近播放';

  @override
  String get sectionNewest => '最新发行';

  @override
  String get sectionMostPlayed => '常听的';

  @override
  String get filterEmptyTitle => '这里还是空的';

  @override
  String get filterEmptyBody => '换个筛选看看，或者先播放几首歌。';

  @override
  String get sectionRecentlyAdded => '最近添加';

  @override
  String get seeAll => '查看全部';

  @override
  String get chipAll => '全部';

  @override
  String get chipNewRelease => '新发行';

  @override
  String get chipTrending => '热门';

  @override
  String get chipFavorites => '喜欢';

  @override
  String songCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首',
      zero: '暂无歌曲',
    );
    return '$_temp0';
  }

  @override
  String songCountShort(int count) {
    return '$count 首';
  }

  @override
  String get nowPlaying => '正在播放';

  @override
  String get queue => '播放队列';

  @override
  String get lyrics => '歌词';

  @override
  String get lyricsUnavailable => '这首歌暂时没有找到歌词';

  @override
  String get myMusic => '我的音乐';

  @override
  String get playlists => '歌单';

  @override
  String get likedSongs => '我喜欢的';

  @override
  String get likedEmptyBody => '点击歌曲上的心形即可收藏到这里。';

  @override
  String get downloads => '已下载';

  @override
  String get download => '下载';

  @override
  String get downloaded => '已保存到音乐文件夹';

  @override
  String get downloadCachedOnly => '已缓存，可离线播放';

  @override
  String get downloadFailed => '下载失败';

  @override
  String get downloadsEmptyTitle => '还没有离线内容';

  @override
  String get downloadsEmptyBody => '播放 Audius 或 Jamendo 的歌曲后会自动缓存，可离线收听。';

  @override
  String get removeDownload => '删除下载';

  @override
  String get refresh => '刷新';

  @override
  String cacheUsage(String size) {
    return '已占用 $size';
  }

  @override
  String get cacheSettings => '缓存管理';

  @override
  String get cacheLimit => '缓存上限';

  @override
  String get cacheUnlimited => '不限';

  @override
  String get cacheClear => '清除缓存';

  @override
  String get cacheClearConfirm => '清除缓存？已下载到音乐文件夹的文件不受影响。';

  @override
  String get cacheCleared => '缓存已清除';

  @override
  String selectedCount(int count) {
    return '已选 $count 首';
  }

  @override
  String get selectAll => '全选';

  @override
  String get selectNone => '取消全选';

  @override
  String get favorite => '收藏';

  @override
  String get unfavorite => '取消收藏';

  @override
  String get sleepTimer => '睡眠定时';

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes 分钟后停止';
  }

  @override
  String get sleepTimerOff => '关闭定时';

  @override
  String cacheDetail(String size, int count) {
    return '$size · $count 首';
  }

  @override
  String get searchHint => '歌曲、专辑、艺人';

  @override
  String get searchEmptyTitle => '搜索你的曲库';

  @override
  String get searchEmptyBody => '按名称查找歌曲、专辑和艺人。';

  @override
  String searchNoResults(String query) {
    return '没有找到与「$query」匹配的内容';
  }

  @override
  String get localResults => '本地曲库';

  @override
  String get onlineDiscover => '在线推荐';

  @override
  String get onlineFromAudius => '来自 Audius';

  @override
  String get onlineNoResults => '在线没有找到相关内容';

  @override
  String get onlineUnavailable => '在线音乐暂时不可用';

  @override
  String get onlineStreaming => '在线播放';

  @override
  String get onlineFromJamendo => '来自 Jamendo';

  @override
  String get jamendoClientId => 'Jamendo Client ID';

  @override
  String get jamendoClientIdHint => '在 devportal.jamendo.com 免费申请（非商业）';

  @override
  String get jamendoClientIdEmpty => '未设置';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get onlineGenreAll => '全部';

  @override
  String get onlineGenreElectronic => '电子';

  @override
  String get onlineGenreRock => '摇滚';

  @override
  String get onlineGenreHipHop => '嘻哈';

  @override
  String get onlineGenreJazz => '爵士';

  @override
  String get onlineGenrePop => '流行';

  @override
  String get onlineGenreClassical => '古典';

  @override
  String get onlineGenreAmbient => '氛围';

  @override
  String get onlineGenreFolk => '民谣';

  @override
  String get playlistNew => '新建播放列表';

  @override
  String playlistCountShort(int count) {
    return '$count 个歌单';
  }

  @override
  String get playlistNameHint => '播放列表名称';

  @override
  String get playlistRename => '重命名';

  @override
  String get playlistDelete => '删除播放列表';

  @override
  String playlistDeleteConfirm(String name) {
    return '删除「$name」？此操作无法撤销。';
  }

  @override
  String get playlistEmptyTitle => '这个播放列表还是空的';

  @override
  String get playlistEmptyBody => '在曲库中长按歌曲即可添加到这里。';

  @override
  String get addToPlaylist => '添加到播放列表';

  @override
  String addedToPlaylist(String name) {
    return '已添加到「$name」';
  }

  @override
  String alreadyInPlaylist(String name) {
    return '已在「$name」中';
  }

  @override
  String get removeFromPlaylist => '从播放列表移除';

  @override
  String get playAll => '播放全部';

  @override
  String get create => '创建';

  @override
  String get delete => '删除';

  @override
  String get rename => '重命名';

  @override
  String get libraryEmptyTitle => '曲库还是空的';

  @override
  String get libraryEmptyBody => '添加一个音乐文件夹，Spark 会自动扫描。';

  @override
  String get libraryAddFolder => '添加音乐文件夹';

  @override
  String get libraryScanning => '正在扫描…';

  @override
  String get musicFolders => '音乐文件夹';

  @override
  String get rescanLibrary => '重新扫描曲库';

  @override
  String get rescanStarted => '正在重新扫描曲库…';

  @override
  String folderAdded(String name) {
    return '已添加「$name」';
  }

  @override
  String get folderAddFailed => '无法添加该文件夹。';

  @override
  String get folderAlreadyAdded => '该文件夹已在曲库中。';

  @override
  String get settingsAudio => '音频与 USB';

  @override
  String get settingsAudioSubtitle => '输出通路、USB DAC、均衡器';

  @override
  String get outputMode => '输出模式';

  @override
  String get outputModeAndroid => 'Android 共享输出';

  @override
  String get outputModeAndroidHint => '标准 Android 输出，其他应用的声音会混入。';

  @override
  String get outputModeOboe => '高解析（Oboe）';

  @override
  String get outputModeOboeHint => 'Android 托管的低延迟通路，并非独占。';

  @override
  String get outputModeUsb => 'USB DAC 直连';

  @override
  String get outputModeUsbHint => '位完美。Spark 会独占 DAC 并绕过 Android 混音器。';

  @override
  String get outputModeUsbNeedsDac => '需要接入 USB DAC 才能使用。';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSubtitle => 'English 或 简体中文';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeSystemHint => '跟随手机的深色 / 浅色设置。';

  @override
  String get themeDark => '深色';

  @override
  String get themeDarkHint => '近黑底色，设计稿的原始外观。';

  @override
  String get themeAmoled => '纯黑';

  @override
  String get themeAmoledHint => '纯黑背景，OLED 屏幕更省电。';

  @override
  String get themeLight => '浅色';

  @override
  String get themeLightHint => '浅色背景，适合明亮环境。';

  @override
  String get albumColorMode => '专辑配色';

  @override
  String get albumColorOff => '关闭';

  @override
  String get albumColorOffHint => '保持默认渐变。';

  @override
  String get albumColorSubtle => '淡雅';

  @override
  String get albumColorSubtleHint => '带一点封面颜色的气息。';

  @override
  String get albumColorModerate => '适中';

  @override
  String get albumColorModerateHint => '明显受封面颜色影响。';

  @override
  String get albumColorVibrant => '鲜艳';

  @override
  String get albumColorVibrantHint => '使用封面浓烈的色彩。';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsAboutSubtitle => '版本与许可';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get outputNormalAndroid => 'Android 共享输出';

  @override
  String get outputUsbDirect => 'USB DAC 直连';

  @override
  String get outputUsbDirectUnavailable => '未检测到 USB DAC';

  @override
  String get aboutVersion => '版本';

  @override
  String get aboutEngine => '音频引擎';

  @override
  String get diagRequestedEngine => '请求引擎';

  @override
  String get diagActualEngine => '实际引擎';

  @override
  String get diagUsbInterface => 'USB 接口';

  @override
  String get diagUsbStream => 'USB 数据流';

  @override
  String get diagFallbackReason => '回退原因';

  @override
  String get diagClaimed => '已占用';

  @override
  String get diagUnclaimed => '未占用';

  @override
  String get diagStable => '稳定';

  @override
  String get diagUnstable => '不稳定';

  @override
  String get diagNotFallenBack => '无';

  @override
  String get settingsAudioDiagnostics => '音频诊断';

  @override
  String get outputModeDapExclusive => 'DAP 原生独占';
}
