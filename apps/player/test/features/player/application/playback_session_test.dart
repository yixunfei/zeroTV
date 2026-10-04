import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/player/application/playback_session.dart';

void main() {
  const sources = [
    Channel(name: 'A', streamUrl: 'http://a'),
    Channel(name: 'A', streamUrl: 'http://b'),
    Channel(name: 'A', streamUrl: 'http://c'),
  ];

  test('errors during open continue through all failing sources', () async {
    final opened = <String>[];
    late PlaybackSession session;
    session = PlaybackSession(
      sources: sources,
      open: (channel) async {
        opened.add(channel.streamUrl);
        if (opened.length < 3) session.onError('failed while opening');
      },
    );
    addTearDown(session.dispose);
    await session.start();
    expect(opened, ['http://a', 'http://b', 'http://c']);
    expect(session.index, 2);
    expect(session.error, isNull);
    expect(session.opening, isFalse);
  });

  group('live seek diagnostics', () => _testLiveSeekDiagnostics(sources));

  test('retry restarts from the first source after a terminal error', () async {
    var attempts = 0;
    final opened = <String>[];
    final session = PlaybackSession(
      sources: sources,
      open: (channel) async {
        attempts++;
        opened.add(channel.streamUrl);
        if (attempts <= 3) throw StateError('offline');
      },
    );
    addTearDown(session.dispose);
    await session.start();
    expect(session.error, contains('offline'));

    session.retry();
    await pumpEventQueue();

    expect(session.index, 0);
    expect(session.error, isNull);
    expect(opened, ['http://a', 'http://b', 'http://c', 'http://a']);
  });

  test('retry without a terminal error is a no-op', () async {
    var opens = 0;
    final session = PlaybackSession(
      sources: sources,
      open: (_) async => opens++,
    );
    addTearDown(session.dispose);
    await session.start();
    session.retry();
    await pumpEventQueue();
    expect(opens, 1);
  });

  test('thrown open failures become a terminal error', () async {
    final session = PlaybackSession(
      sources: sources,
      open: (_) async {
        throw StateError('offline');
      },
    );
    addTearDown(session.dispose);
    await session.start();
    expect(session.index, 2);
    expect(session.error, contains('offline'));
    session.onPlaying();
    expect(session.error, isNull);
  });

  test('suspended failover surfaces errors without advancing', () async {
    final session = PlaybackSession(
      sources: sources,
      open: (_) async {},
    );
    addTearDown(session.dispose);
    await session.start();
    session
      ..suspendFailover()
      ..onError('catchup stream failed');
    expect(session.index, 0);
    expect(session.error, 'catchup stream failed');
    // Recovery clears the error; resuming restores failover behavior.
    session.onPlaying();
    expect(session.error, isNull);
    session
      ..resumeFailover()
      ..onError('live failed');
    expect(session.index, 1);
  });

  test('a switch requested during open is applied once it settles', () async {
    final gate = Completer<void>();
    final opened = <String>[];
    final session = PlaybackSession(
      sources: sources,
      open: (channel) async {
        opened.add(channel.streamUrl);
        await gate.future;
      },
    );
    addTearDown(session.dispose);
    final opening = session.start();
    session.switchTo(2);
    expect(session.index, 0);
    gate.complete();
    await opening;
    // The queued switch reopens at the requested source.
    await pumpEventQueue();
    expect(session.index, 2);
    expect(opened, ['http://a', 'http://c']);
  });

  test('dispose during open prevents subsequent source changes', () async {
    final pending = Completer<void>();
    var calls = 0;
    final session = PlaybackSession(
      sources: sources,
      open: (_) {
        calls++;
        return pending.future;
      },
    );
    final opening = session.start();
    session
      ..onError('pending failure')
      ..dispose();
    pending.complete();
    await opening;
    expect(calls, 1);
  });
}

void _testLiveSeekDiagnostics(List<Channel> sources) {
  test('live seek diagnostics during open do not cause failover', () async {
    var opens = 0;
    late PlaybackSession session;
    session = PlaybackSession(
      sources: sources,
      open: (_) async {
        opens++;
        session
          ..onError('Cannot seek in this stream.')
          ..onError("You can force it with '--force-seekable=yes'.");
      },
    );
    addTearDown(session.dispose);
    await session.start();
    expect(opens, 1);
    expect(session.index, 0);
    expect(session.error, isNull);
  });

  test('seek diagnostics after playback do not display a failure', () async {
    final session = PlaybackSession(
      sources: [sources.first],
      open: (_) async {},
    );
    addTearDown(session.dispose);
    await session.start();
    session
      ..onPlaying()
      ..onError(
        ' Cannot seek in this stream.\r\n'
        'you can force it with --force-seekable=yes\n',
      );
    expect(session.error, isNull);
  });

  test('seek advice does not hide a real error in the same message', () async {
    final session = PlaybackSession(
      sources: [sources.first],
      open: (_) async {},
    );
    addTearDown(session.dispose);
    await session.start();
    session.onError(
      'Failed to open https://example.com/live\n'
      "You can force it with '--force-seekable=yes'.",
    );
    expect(session.error, 'Failed to open https://example.com/live');
  });
}
