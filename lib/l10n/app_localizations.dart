import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Application name, shown in the task switcher and About screen.
  ///
  /// In en, this message translates to:
  /// **'Spark'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Short greeting at the top of the home screen. Followed by the user name if one is known.
  ///
  /// In en, this message translates to:
  /// **'Hi'**
  String get greeting;

  /// No description provided for @greeting0.
  ///
  /// In en, this message translates to:
  /// **'Time for some good music'**
  String get greeting0;

  /// No description provided for @greeting1.
  ///
  /// In en, this message translates to:
  /// **'Let the music carry your day'**
  String get greeting1;

  /// No description provided for @greeting2.
  ///
  /// In en, this message translates to:
  /// **'Slow down. Play something.'**
  String get greeting2;

  /// No description provided for @greeting3.
  ///
  /// In en, this message translates to:
  /// **'Let the melody do the talking'**
  String get greeting3;

  /// No description provided for @greeting4.
  ///
  /// In en, this message translates to:
  /// **'Good music is worth the wait'**
  String get greeting4;

  /// No description provided for @greeting5.
  ///
  /// In en, this message translates to:
  /// **'This moment is yours'**
  String get greeting5;

  /// No description provided for @greeting6.
  ///
  /// In en, this message translates to:
  /// **'Hear the world differently'**
  String get greeting6;

  /// No description provided for @greeting7.
  ///
  /// In en, this message translates to:
  /// **'Every play is a fresh start'**
  String get greeting7;

  /// No description provided for @greeting8.
  ///
  /// In en, this message translates to:
  /// **'Settle in and listen well'**
  String get greeting8;

  /// No description provided for @greeting9.
  ///
  /// In en, this message translates to:
  /// **'Music is the best medicine'**
  String get greeting9;

  /// No description provided for @sectionCurated.
  ///
  /// In en, this message translates to:
  /// **'Curated & trending'**
  String get sectionCurated;

  /// No description provided for @dailyMix.
  ///
  /// In en, this message translates to:
  /// **'Daily mix'**
  String get dailyMix;

  /// No description provided for @dailyMixSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A fresh set each day · {count} tracks'**
  String dailyMixSubtitle(int count);

  /// No description provided for @forYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get forYou;

  /// No description provided for @forYouSubtitle.
  ///
  /// In en, this message translates to:
  /// **'From what you listen to · {count} tracks'**
  String forYouSubtitle(int count);

  /// No description provided for @forYouNoHistory.
  ///
  /// In en, this message translates to:
  /// **'Picks from Audius and Jamendo'**
  String get forYouNoHistory;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get recentlyPlayed;

  /// No description provided for @sectionNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest releases'**
  String get sectionNewest;

  /// No description provided for @sectionMostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most played'**
  String get sectionMostPlayed;

  /// No description provided for @filterEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get filterEmptyTitle;

  /// No description provided for @filterEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try another filter, or play a few songs first.'**
  String get filterEmptyBody;

  /// No description provided for @sectionRecentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get sectionRecentlyAdded;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @chipAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chipAll;

  /// No description provided for @chipNewRelease.
  ///
  /// In en, this message translates to:
  /// **'New release'**
  String get chipNewRelease;

  /// No description provided for @chipTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get chipTrending;

  /// No description provided for @chipFavorites.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get chipFavorites;

  /// Track count for an album or playlist row.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No songs} =1{1 song} other{{count} songs}}'**
  String songCount(int count);

  /// Compact track count used in dense list rows.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String songCountShort(int count);

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @lyricsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found for this track'**
  String get lyricsUnavailable;

  /// No description provided for @myMusic.
  ///
  /// In en, this message translates to:
  /// **'My Music'**
  String get myMusic;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @likedSongs.
  ///
  /// In en, this message translates to:
  /// **'Liked Songs'**
  String get likedSongs;

  /// No description provided for @likedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a song to save it here.'**
  String get likedEmptyBody;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Saved to your music folder'**
  String get downloaded;

  /// No description provided for @downloadCachedOnly.
  ///
  /// In en, this message translates to:
  /// **'Saved for offline play'**
  String get downloadCachedOnly;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @downloadsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved offline yet'**
  String get downloadsEmptyTitle;

  /// No description provided for @downloadsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Play a track from Audius or Jamendo and it is kept for offline listening.'**
  String get downloadsEmptyBody;

  /// No description provided for @removeDownload.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get removeDownload;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @cacheUsage.
  ///
  /// In en, this message translates to:
  /// **'Using {size}'**
  String cacheUsage(String size);

  /// No description provided for @cacheSettings.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get cacheSettings;

  /// No description provided for @cacheLimit.
  ///
  /// In en, this message translates to:
  /// **'Cache limit'**
  String get cacheLimit;

  /// No description provided for @cacheUnlimited.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get cacheUnlimited;

  /// No description provided for @cacheClear.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get cacheClear;

  /// No description provided for @cacheClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear the cache? Downloads saved to your music folder are not affected.'**
  String get cacheClearConfirm;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @selectNone.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get selectNone;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get favorite;

  /// No description provided for @unfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from liked'**
  String get unfavorite;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @sleepTimerMinutes.
  ///
  /// In en, this message translates to:
  /// **'Stop after {minutes} min'**
  String sleepTimerMinutes(int minutes);

  /// No description provided for @sleepTimerOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off timer'**
  String get sleepTimerOff;

  /// No description provided for @cacheDetail.
  ///
  /// In en, this message translates to:
  /// **'{size} · {count} tracks'**
  String cacheDetail(String size, int count);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Songs, albums, artists'**
  String get searchHint;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Search your library'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Find songs, albums and artists by name.'**
  String get searchEmptyBody;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing matched \"{query}\"'**
  String searchNoResults(String query);

  /// No description provided for @localResults.
  ///
  /// In en, this message translates to:
  /// **'In your library'**
  String get localResults;

  /// No description provided for @onlineDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover online'**
  String get onlineDiscover;

  /// No description provided for @onlineFromAudius.
  ///
  /// In en, this message translates to:
  /// **'From Audius'**
  String get onlineFromAudius;

  /// No description provided for @onlineNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found online'**
  String get onlineNoResults;

  /// No description provided for @onlineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Online music is unavailable right now'**
  String get onlineUnavailable;

  /// No description provided for @onlineStreaming.
  ///
  /// In en, this message translates to:
  /// **'Streaming'**
  String get onlineStreaming;

  /// No description provided for @onlineFromJamendo.
  ///
  /// In en, this message translates to:
  /// **'From Jamendo'**
  String get onlineFromJamendo;

  /// No description provided for @jamendoClientId.
  ///
  /// In en, this message translates to:
  /// **'Jamendo Client ID'**
  String get jamendoClientId;

  /// No description provided for @jamendoClientIdHint.
  ///
  /// In en, this message translates to:
  /// **'Free non-commercial ID from devportal.jamendo.com'**
  String get jamendoClientIdHint;

  /// No description provided for @jamendoClientIdEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get jamendoClientIdEmpty;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @onlineGenreAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get onlineGenreAll;

  /// No description provided for @onlineGenreElectronic.
  ///
  /// In en, this message translates to:
  /// **'Electronic'**
  String get onlineGenreElectronic;

  /// No description provided for @onlineGenreRock.
  ///
  /// In en, this message translates to:
  /// **'Rock'**
  String get onlineGenreRock;

  /// No description provided for @onlineGenreHipHop.
  ///
  /// In en, this message translates to:
  /// **'Hip-hop'**
  String get onlineGenreHipHop;

  /// No description provided for @onlineGenreJazz.
  ///
  /// In en, this message translates to:
  /// **'Jazz'**
  String get onlineGenreJazz;

  /// No description provided for @onlineGenrePop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get onlineGenrePop;

  /// No description provided for @onlineGenreClassical.
  ///
  /// In en, this message translates to:
  /// **'Classical'**
  String get onlineGenreClassical;

  /// No description provided for @onlineGenreAmbient.
  ///
  /// In en, this message translates to:
  /// **'Ambient'**
  String get onlineGenreAmbient;

  /// No description provided for @onlineGenreFolk.
  ///
  /// In en, this message translates to:
  /// **'Folk'**
  String get onlineGenreFolk;

  /// No description provided for @playlistNew.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get playlistNew;

  /// No description provided for @playlistCountShort.
  ///
  /// In en, this message translates to:
  /// **'{count} playlists'**
  String playlistCountShort(int count);

  /// No description provided for @playlistNameHint.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistNameHint;

  /// No description provided for @playlistRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get playlistRename;

  /// No description provided for @playlistDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist'**
  String get playlistDelete;

  /// No description provided for @playlistDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String playlistDeleteConfirm(String name);

  /// No description provided for @playlistEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'This playlist is empty'**
  String get playlistEmptyTitle;

  /// No description provided for @playlistEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Long-press a song in your library to add it here.'**
  String get playlistEmptyBody;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// No description provided for @addedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added to \"{name}\"'**
  String addedToPlaylist(String name);

  /// No description provided for @alreadyInPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Already in \"{name}\"'**
  String alreadyInPlaylist(String name);

  /// No description provided for @removeFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get removeFromPlaylist;

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playAll;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a music folder and Spark will scan it.'**
  String get libraryEmptyBody;

  /// No description provided for @libraryAddFolder.
  ///
  /// In en, this message translates to:
  /// **'Add music folder'**
  String get libraryAddFolder;

  /// No description provided for @libraryScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get libraryScanning;

  /// No description provided for @musicFolders.
  ///
  /// In en, this message translates to:
  /// **'Music folders'**
  String get musicFolders;

  /// No description provided for @rescanLibrary.
  ///
  /// In en, this message translates to:
  /// **'Rescan library'**
  String get rescanLibrary;

  /// No description provided for @rescanStarted.
  ///
  /// In en, this message translates to:
  /// **'Rescanning your library…'**
  String get rescanStarted;

  /// No description provided for @folderAdded.
  ///
  /// In en, this message translates to:
  /// **'Added \"{name}\"'**
  String folderAdded(String name);

  /// No description provided for @folderAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add that folder.'**
  String get folderAddFailed;

  /// No description provided for @folderAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'That folder is already in your library.'**
  String get folderAlreadyAdded;

  /// No description provided for @settingsAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio & USB'**
  String get settingsAudio;

  /// No description provided for @settingsAudioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Output path, USB DAC, equalizer'**
  String get settingsAudioSubtitle;

  /// No description provided for @outputMode.
  ///
  /// In en, this message translates to:
  /// **'Output mode'**
  String get outputMode;

  /// No description provided for @outputModeAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android shared'**
  String get outputModeAndroid;

  /// No description provided for @outputModeAndroidHint.
  ///
  /// In en, this message translates to:
  /// **'Standard Android output. Everything else can mix in.'**
  String get outputModeAndroidHint;

  /// No description provided for @outputModeOboe.
  ///
  /// In en, this message translates to:
  /// **'Hi-res (Oboe)'**
  String get outputModeOboe;

  /// No description provided for @outputModeOboeHint.
  ///
  /// In en, this message translates to:
  /// **'Android-managed low-latency path. Not exclusive.'**
  String get outputModeOboeHint;

  /// No description provided for @outputModeUsb.
  ///
  /// In en, this message translates to:
  /// **'USB DAC direct'**
  String get outputModeUsb;

  /// No description provided for @outputModeUsbHint.
  ///
  /// In en, this message translates to:
  /// **'Bit-perfect. Spark claims the DAC and bypasses the Android mixer.'**
  String get outputModeUsbHint;

  /// No description provided for @outputModeUsbNeedsDac.
  ///
  /// In en, this message translates to:
  /// **'Connect a USB DAC to use this.'**
  String get outputModeUsbNeedsDac;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'English or 简体中文'**
  String get settingsLanguageSubtitle;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// No description provided for @themeSystemHint.
  ///
  /// In en, this message translates to:
  /// **'Matches your phone\'s dark or light setting.'**
  String get themeSystemHint;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeDarkHint.
  ///
  /// In en, this message translates to:
  /// **'Near-black canvas. The original design.'**
  String get themeDarkHint;

  /// No description provided for @themeAmoled.
  ///
  /// In en, this message translates to:
  /// **'True black'**
  String get themeAmoled;

  /// No description provided for @themeAmoledHint.
  ///
  /// In en, this message translates to:
  /// **'Pure black background, easier on OLED battery.'**
  String get themeAmoledHint;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeLightHint.
  ///
  /// In en, this message translates to:
  /// **'Light surfaces for bright rooms.'**
  String get themeLightHint;

  /// No description provided for @albumColorMode.
  ///
  /// In en, this message translates to:
  /// **'Cover colouring'**
  String get albumColorMode;

  /// No description provided for @albumColorOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get albumColorOff;

  /// No description provided for @albumColorOffHint.
  ///
  /// In en, this message translates to:
  /// **'Keep the default gradient.'**
  String get albumColorOffHint;

  /// No description provided for @albumColorSubtle.
  ///
  /// In en, this message translates to:
  /// **'Subtle'**
  String get albumColorSubtle;

  /// No description provided for @albumColorSubtleHint.
  ///
  /// In en, this message translates to:
  /// **'A faint hint of the cover\'s colour.'**
  String get albumColorSubtleHint;

  /// No description provided for @albumColorModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get albumColorModerate;

  /// No description provided for @albumColorModerateHint.
  ///
  /// In en, this message translates to:
  /// **'Clearly tinted by the cover.'**
  String get albumColorModerateHint;

  /// No description provided for @albumColorVibrant.
  ///
  /// In en, this message translates to:
  /// **'Vibrant'**
  String get albumColorVibrant;

  /// No description provided for @albumColorVibrantHint.
  ///
  /// In en, this message translates to:
  /// **'Strong, saturated cover colours.'**
  String get albumColorVibrantHint;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version and licences'**
  String get settingsAboutSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @outputNormalAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android shared'**
  String get outputNormalAndroid;

  /// No description provided for @outputUsbDirect.
  ///
  /// In en, this message translates to:
  /// **'USB DAC (direct)'**
  String get outputUsbDirect;

  /// No description provided for @outputUsbDirectUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No USB DAC detected'**
  String get outputUsbDirectUnavailable;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutEngine.
  ///
  /// In en, this message translates to:
  /// **'Audio engine'**
  String get aboutEngine;

  /// No description provided for @diagRequestedEngine.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get diagRequestedEngine;

  /// No description provided for @diagActualEngine.
  ///
  /// In en, this message translates to:
  /// **'Actually using'**
  String get diagActualEngine;

  /// No description provided for @diagUsbInterface.
  ///
  /// In en, this message translates to:
  /// **'USB interface'**
  String get diagUsbInterface;

  /// No description provided for @diagUsbStream.
  ///
  /// In en, this message translates to:
  /// **'USB stream'**
  String get diagUsbStream;

  /// No description provided for @diagFallbackReason.
  ///
  /// In en, this message translates to:
  /// **'Fallback reason'**
  String get diagFallbackReason;

  /// No description provided for @diagClaimed.
  ///
  /// In en, this message translates to:
  /// **'claimed'**
  String get diagClaimed;

  /// No description provided for @diagUnclaimed.
  ///
  /// In en, this message translates to:
  /// **'not claimed'**
  String get diagUnclaimed;

  /// No description provided for @diagStable.
  ///
  /// In en, this message translates to:
  /// **'stable'**
  String get diagStable;

  /// No description provided for @diagUnstable.
  ///
  /// In en, this message translates to:
  /// **'unstable'**
  String get diagUnstable;

  /// No description provided for @diagNotFallenBack.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get diagNotFallenBack;

  /// No description provided for @settingsAudioDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'AUDIO DIAGNOSTICS'**
  String get settingsAudioDiagnostics;

  /// No description provided for @outputModeDapExclusive.
  ///
  /// In en, this message translates to:
  /// **'DAP native (exclusive)'**
  String get outputModeDapExclusive;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'zh':
      return L10nZh();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
