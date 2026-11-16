import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:go_bike_app/screens/splash_screen.dart';
import 'package:go_bike_app/widgets/auth_widgets.dart';
import 'package:go_bike_app/widgets/brand.dart';

/// A video player that never touches a real decoder: it says the video is ready right
/// away and finishes only when the test says so.
class _FakeVideoPlayer extends VideoPlayerPlatform {
  _FakeVideoPlayer({this.fails = false});

  final bool fails;
  final _events = StreamController<VideoEvent>();
  String? asset;
  bool played = false;

  void finish() => _events.add(VideoEvent(eventType: VideoEventType.completed));

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    asset = options.dataSource.asset;
    if (fails) {
      _events.addError(PlatformException(code: 'codec', message: 'no decoder'));
    } else {
      _events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(milliseconds: 4600),
          size: const Size(1080, 1920),
        ),
      );
    }
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Future<void> play(int playerId) async => played = true;

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool preventsDisplaySleepDuringVideoPlayback,
  ) async {}

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.white);
}

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  // The saved session is read from secure storage, which only answers in real time.
  Future<void> letSessionLoad(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1000)),
    );
    await tester.pump();
  }

  testWidgets(
    'plays the RondaGo video, and waits for it to end before moving on',
    (tester) async {
      await phone(tester);
      final player = _FakeVideoPlayer();
      VideoPlayerPlatform.instance = player;

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump();

      expect(player.asset, SplashScreen.video);
      expect(player.played, isTrue);
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(find.byType(AuthLogo), findsNothing);

      // The session is known long before the video ends: the splash stays.
      await letSessionLoad(tester);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);

      player.finish();
      await tester.pump();
      await tester.pump(); // a new page sits offstage for its first frame
      await tester.pump(const Duration(seconds: 1)); // the fade
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.byType(RondaGoWordmark), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a video that never reports its end does not hold the app', (
    tester,
  ) async {
    await phone(tester);
    VideoPlayerPlatform.instance = _FakeVideoPlayer();

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await letSessionLoad(tester);
    expect(find.text('Get Started'), findsNothing);

    await tester.pump(SplashScreen.longestWait);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Get Started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('when the video cannot play, the logo shows instead', (
    tester,
  ) async {
    await phone(tester);
    VideoPlayerPlatform.instance = _FakeVideoPlayer(fails: true);

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();
    expect(find.byType(VideoPlayer), findsNothing);
    expect(find.byType(AuthLogo), findsOneWidget);

    await letSessionLoad(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Get Started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with reduced motion, no video plays: just the logo', (
    tester,
  ) async {
    await phone(tester);
    final player = _FakeVideoPlayer();
    VideoPlayerPlatform.instance = player;

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();
    expect(player.asset, isNull);
    expect(find.byType(AuthLogo), findsOneWidget);

    await letSessionLoad(tester);
    await tester.pump();
    expect(find.text('Get Started'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); // Get Started's own entrance
    expect(tester.takeException(), isNull);
  });
}
