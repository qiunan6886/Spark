// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Spark';

  @override
  String get navHome => 'Home';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSearch => 'Search';

  @override
  String get navSettings => 'Settings';

  @override
  String get greeting => 'Hi';

  @override
  String get greeting0 => 'Time for some good music';

  @override
  String get greeting1 => 'Let the music carry your day';

  @override
  String get greeting2 => 'Slow down. Play something.';

  @override
  String get greeting3 => 'Let the melody do the talking';

  @override
  String get greeting4 => 'Good music is worth the wait';

  @override
  String get greeting5 => 'This moment is yours';

  @override
  String get greeting6 => 'Hear the world differently';

  @override
  String get greeting7 => 'Every play is a fresh start';

  @override
  String get greeting8 => 'Settle in and listen well';

  @override
  String get greeting9 => 'Music is the best medicine';

  @override
  String get sectionCurated => 'Curated & trending';

  @override
  String get dailyMix => 'Daily mix';

  @override
  String dailyMixSubtitle(int count) {
    return 'A fresh set each day · $count tracks';
  }

  @override
  String get forYou => 'For you';

  @override
  String forYouSubtitle(int count) {
    return 'From what you listen to · $count tracks';
  }

  @override
  String get forYouNoHistory => 'Picks from Audius and Jamendo';

  @override
  String get recentlyPlayed => 'Recently played';

  @override
  String get sectionNewest => 'Newest releases';

  @override
  String get sectionMostPlayed => 'Most played';

  @override
  String get filterEmptyTitle => 'Nothing here yet';

  @override
  String get filterEmptyBody =>
      'Try another filter, or play a few songs first.';

  @override
  String get sectionRecentlyAdded => 'Recently added';

  @override
  String get seeAll => 'See all';

  @override
  String get chipAll => 'All';

  @override
  String get chipNewRelease => 'New release';

  @override
  String get chipTrending => 'Trending';

  @override
  String get chipFavorites => 'Liked';

  @override
  String songCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
      zero: 'No songs',
    );
    return '$_temp0';
  }

  @override
  String songCountShort(int count) {
    return '$count songs';
  }

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get queue => 'Queue';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get lyricsUnavailable => 'No lyrics found for this track';

  @override
  String get myMusic => 'My Music';

  @override
  String get playlists => 'Playlists';

  @override
  String get likedSongs => 'Liked Songs';

  @override
  String get likedEmptyBody => 'Tap the heart on a song to save it here.';

  @override
  String get downloads => 'Downloads';

  @override
  String get download => 'Download';

  @override
  String get downloaded => 'Saved to your music folder';

  @override
  String get downloadCachedOnly => 'Saved for offline play';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get downloadsEmptyTitle => 'Nothing saved offline yet';

  @override
  String get downloadsEmptyBody =>
      'Play a track from Audius or Jamendo and it is kept for offline listening.';

  @override
  String get removeDownload => 'Remove download';

  @override
  String get refresh => 'Refresh';

  @override
  String cacheUsage(String size) {
    return 'Using $size';
  }

  @override
  String get cacheSettings => 'Cache';

  @override
  String get cacheLimit => 'Cache limit';

  @override
  String get cacheUnlimited => 'No limit';

  @override
  String get cacheClear => 'Clear cache';

  @override
  String get cacheClearConfirm =>
      'Clear the cache? Downloads saved to your music folder are not affected.';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get selectNone => 'Deselect all';

  @override
  String get favorite => 'Like';

  @override
  String get unfavorite => 'Remove from liked';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String sleepTimerMinutes(int minutes) {
    return 'Stop after $minutes min';
  }

  @override
  String get sleepTimerOff => 'Turn off timer';

  @override
  String cacheDetail(String size, int count) {
    return '$size · $count tracks';
  }

  @override
  String get searchHint => 'Songs, albums, artists';

  @override
  String get searchEmptyTitle => 'Search your library';

  @override
  String get searchEmptyBody => 'Find songs, albums and artists by name.';

  @override
  String searchNoResults(String query) {
    return 'Nothing matched \"$query\"';
  }

  @override
  String get localResults => 'In your library';

  @override
  String get onlineDiscover => 'Discover online';

  @override
  String get onlineFromAudius => 'From Audius';

  @override
  String get onlineNoResults => 'Nothing found online';

  @override
  String get onlineUnavailable => 'Online music is unavailable right now';

  @override
  String get onlineStreaming => 'Streaming';

  @override
  String get onlineFromJamendo => 'From Jamendo';

  @override
  String get jamendoClientId => 'Jamendo Client ID';

  @override
  String get jamendoClientIdHint =>
      'Free non-commercial ID from devportal.jamendo.com';

  @override
  String get jamendoClientIdEmpty => 'Not set';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get onlineGenreAll => 'All';

  @override
  String get onlineGenreElectronic => 'Electronic';

  @override
  String get onlineGenreRock => 'Rock';

  @override
  String get onlineGenreHipHop => 'Hip-hop';

  @override
  String get onlineGenreJazz => 'Jazz';

  @override
  String get onlineGenrePop => 'Pop';

  @override
  String get onlineGenreClassical => 'Classical';

  @override
  String get onlineGenreAmbient => 'Ambient';

  @override
  String get onlineGenreFolk => 'Folk';

  @override
  String get playlistNew => 'New playlist';

  @override
  String playlistCountShort(int count) {
    return '$count playlists';
  }

  @override
  String get playlistNameHint => 'Playlist name';

  @override
  String get playlistRename => 'Rename';

  @override
  String get playlistDelete => 'Delete playlist';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get playlistEmptyTitle => 'This playlist is empty';

  @override
  String get playlistEmptyBody =>
      'Long-press a song in your library to add it here.';

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String addedToPlaylist(String name) {
    return 'Added to \"$name\"';
  }

  @override
  String alreadyInPlaylist(String name) {
    return 'Already in \"$name\"';
  }

  @override
  String get removeFromPlaylist => 'Remove from playlist';

  @override
  String get playAll => 'Play all';

  @override
  String get create => 'Create';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get libraryEmptyTitle => 'Your library is empty';

  @override
  String get libraryEmptyBody => 'Add a music folder and Spark will scan it.';

  @override
  String get libraryAddFolder => 'Add music folder';

  @override
  String get libraryScanning => 'Scanning…';

  @override
  String get musicFolders => 'Music folders';

  @override
  String get rescanLibrary => 'Rescan library';

  @override
  String get rescanStarted => 'Rescanning your library…';

  @override
  String folderAdded(String name) {
    return 'Added \"$name\"';
  }

  @override
  String get folderAddFailed => 'Could not add that folder.';

  @override
  String get folderAlreadyAdded => 'That folder is already in your library.';

  @override
  String get settingsAudio => 'Audio & USB';

  @override
  String get settingsAudioSubtitle => 'Output path, USB DAC, equalizer';

  @override
  String get outputMode => 'Output mode';

  @override
  String get outputModeAndroid => 'Android shared';

  @override
  String get outputModeAndroidHint =>
      'Standard Android output. Everything else can mix in.';

  @override
  String get outputModeOboe => 'Hi-res (Oboe)';

  @override
  String get outputModeOboeHint =>
      'Android-managed low-latency path. Not exclusive.';

  @override
  String get outputModeUsb => 'USB DAC direct';

  @override
  String get outputModeUsbHint =>
      'Bit-perfect. Spark claims the DAC and bypasses the Android mixer.';

  @override
  String get outputModeUsbNeedsDac => 'Connect a USB DAC to use this.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle => 'English or 简体中文';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeSystemHint => 'Matches your phone\'s dark or light setting.';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeDarkHint => 'Near-black canvas. The original design.';

  @override
  String get themeAmoled => 'True black';

  @override
  String get themeAmoledHint =>
      'Pure black background, easier on OLED battery.';

  @override
  String get themeLight => 'Light';

  @override
  String get themeLightHint => 'Light surfaces for bright rooms.';

  @override
  String get albumColorMode => 'Cover colouring';

  @override
  String get albumColorOff => 'Off';

  @override
  String get albumColorOffHint => 'Keep the default gradient.';

  @override
  String get albumColorSubtle => 'Subtle';

  @override
  String get albumColorSubtleHint => 'A faint hint of the cover\'s colour.';

  @override
  String get albumColorModerate => 'Moderate';

  @override
  String get albumColorModerateHint => 'Clearly tinted by the cover.';

  @override
  String get albumColorVibrant => 'Vibrant';

  @override
  String get albumColorVibrantHint => 'Strong, saturated cover colours.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutSubtitle => 'Version and licences';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get outputNormalAndroid => 'Android shared';

  @override
  String get outputUsbDirect => 'USB DAC (direct)';

  @override
  String get outputUsbDirectUnavailable => 'No USB DAC detected';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutEngine => 'Audio engine';

  @override
  String get diagRequestedEngine => 'Requested';

  @override
  String get diagActualEngine => 'Actually using';

  @override
  String get diagUsbInterface => 'USB interface';

  @override
  String get diagUsbStream => 'USB stream';

  @override
  String get diagFallbackReason => 'Fallback reason';

  @override
  String get diagClaimed => 'claimed';

  @override
  String get diagUnclaimed => 'not claimed';

  @override
  String get diagStable => 'stable';

  @override
  String get diagUnstable => 'unstable';

  @override
  String get diagNotFallenBack => 'none';

  @override
  String get settingsAudioDiagnostics => 'AUDIO DIAGNOSTICS';

  @override
  String get outputModeDapExclusive => 'DAP native (exclusive)';
}
