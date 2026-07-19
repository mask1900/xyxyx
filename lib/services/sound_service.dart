import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// HTML prototipindeki ses efektlerinin (Web Audio API ile sentezlenen kisa
/// "bip" sesleri) Dart karsiligi. Hicbir ses dosyasi, asset veya internet
/// linki KULLANILMAZ — her efekt, runtime'da basit sinüs dalgalarindan
/// bellekte PCM16 WAV olarak uretilir ve bir kere hesaplanip onbelleklenir.
/// Bu sayede tamamen ucretsiz ve sinirsizdir.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  bool enabled = true;
  static const int _sampleRate = 22050;

  final Map<String, Uint8List> _cache = {};
  final List<AudioPlayer> _pool = [];
  int _poolIndex = 0;

  AudioPlayer _nextPlayer() {
    if (_pool.length < 4) {
      final p = AudioPlayer();
      p.setReleaseMode(ReleaseMode.stop);
      _pool.add(p);
      return p;
    }
    _poolIndex = (_poolIndex + 1) % _pool.length;
    return _pool[_poolIndex];
  }

  Future<void> _playWav(String key, Uint8List Function() build) async {
    if (!enabled) return;
    try {
      final bytes = _cache.putIfAbsent(key, build);
      await _nextPlayer().play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Ses cihazda calisamazsa (ornegin bazi web/masaustu ortamlarinda)
      // oyunu asla bozmasin diye sessizce yut.
    }
  }

  // --- Genel efektler ---------------------------------------------------

  void tapTube() => _playWav('tap', () => _tone(
        freqStart: 520,
        freqEnd: 620,
        durationMs: 55,
        amplitude: 0.22,
      ));

  void selectTube() => _playWav('select', () => _tone(
        freqStart: 700,
        freqEnd: 700,
        durationMs: 45,
        amplitude: 0.18,
      ));

  void pour() => _playWav('pour', () => _tone(
        freqStart: 420,
        freqEnd: 180,
        durationMs: 260,
        amplitude: 0.20,
        harmonicMix: 0.25,
      ));

  /// "Sifir Yercekimi" ters cevirme efekti: yukselen bir sweep ile inen
  /// bir sweep'in art arda gelmesi + hafif bir "enerji parazit" katmani —
  /// bir teleportasyon/warp hissi verir. Yine tamamen sentetik, dosya yok.
  void warpFlip() => _playWav('warp', () => _mix([
        _tone(
          freqStart: 260,
          freqEnd: 900,
          durationMs: 160,
          amplitude: 0.22,
          harmonicMix: 0.35,
        ),
        _tone(
          freqStart: 900,
          freqEnd: 200,
          durationMs: 180,
          amplitude: 0.20,
          harmonicMix: 0.3,
          wave: _Wave.square,
        ),
      ], gapMs: 40));

  void land() => _playWav('land', () => _tone(
        freqStart: 300,
        freqEnd: 260,
        durationMs: 70,
        amplitude: 0.20,
      ));

  void invalid() => _playWav('invalid', () => _tone(
        freqStart: 200,
        freqEnd: 160,
        durationMs: 120,
        amplitude: 0.18,
        wave: _Wave.square,
      ));

  void undo() => _playWav('undo', () => _tone(
        freqStart: 500,
        freqEnd: 340,
        durationMs: 130,
        amplitude: 0.2,
      ));

  void buttonTap() => _playWav('button', () => _tone(
        freqStart: 480,
        freqEnd: 480,
        durationMs: 35,
        amplitude: 0.15,
      ));

  // --- Yorunge Vardiyasi (Orbit Jam) efektleri --------------------------

  /// Bir halka basariyla dondugunde calinan kisa, yumusak "tik" sesi.
  void orbitRotate() => _playWav('orbit_rotate', () => _tone(
        freqStart: 480,
        freqEnd: 640,
        durationMs: 90,
        amplitude: 0.30,
        harmonicMix: 0.15,
      ));

  /// Kapiya gelen gezegen o anki hedefle eslesip teslim edildiginde
  /// calinan, tatmin edici kisa yukselen ikili nota.
  void orbitDeliver() => _playWav(
        'orbit_deliver',
        () => _sequence([
          (740.0, 70),
          (1046.5, 110),
        ], amplitude: 0.24, harmonicMix: 0.2),
      );

  /// Kapiya gelen gezegen hedefle eslesmeyip rihtima (dock) konuldugunda
  /// calinan, daha notr/yumusak bir "yerlesme" sesi.
  void orbitDock() => _playWav('orbit_dock', () => _tone(
        freqStart: 340,
        freqEnd: 240,
        durationMs: 140,
        amplitude: 0.18,
      ));

  void reward() => _playWav(
        'reward',
        () => _sequence([
          (660.0, 90),
          (880.0, 140),
        ], amplitude: 0.24, harmonicMix: 0.2),
      );

  void win() => _playWav(
        'win',
        () => _sequence([
          (523.25, 100),
          (659.25, 100),
          (783.99, 180),
        ], amplitude: 0.26, harmonicMix: 0.18),
      );

  void starWin() => _playWav(
        'starwin',
        () => _sequence([
          (523.25, 90),
          (659.25, 90),
          (783.99, 90),
          (1046.5, 220),
        ], amplitude: 0.28, harmonicMix: 0.22),
      );

  void levelUp() => _playWav(
        'levelup',
        () => _sequence([
          (392.0, 90),
          (523.25, 90),
          (659.25, 90),
          (880.0, 260),
        ], amplitude: 0.26, harmonicMix: 0.2),
      );

  // --- Sentez -------------------------------------------------------------

  Uint8List _tone({
    required double freqStart,
    required double freqEnd,
    required int durationMs,
    required double amplitude,
    _Wave wave = _Wave.sine,
    // 0..1 arasi: fundamentale, bir oktav ustundeki hafif bir "shimmer"
    // harmoniginin ne kadar karistirilacagini belirler. Efekti dolgun ve
    // az "sentetik bip" hissettiren, biraz daha kozmik/dolu bir ton verir.
    double harmonicMix = 0.0,
  }) {
    final n = (_sampleRate * durationMs / 1000).round();
    final samples = Int16List(n);
    final attack = math.max(1, (n * 0.06).round());
    final release = math.max(1, (n * 0.22).round());
    var phase = 0.0;
    var phase2 = 0.0;
    for (var i = 0; i < n; i++) {
      final freq = freqStart + (freqEnd - freqStart) * (i / n);
      phase += 2 * math.pi * freq / _sampleRate;
      phase2 += 2 * math.pi * (freq * 2) / _sampleRate;
      double raw;
      switch (wave) {
        case _Wave.sine:
          raw = math.sin(phase);
          break;
        case _Wave.square:
          raw = math.sin(phase) >= 0 ? 1.0 : -1.0;
          break;
      }
      if (harmonicMix > 0) {
        raw = raw * (1 - harmonicMix) + math.sin(phase2) * harmonicMix;
      }
      var env = 1.0;
      if (i < attack) {
        env = i / attack;
      } else if (i > n - release) {
        env = (n - i) / release;
      }
      samples[i] =
          (raw * amplitude * env * 32767).round().clamp(-32768, 32767).toInt();
    }
    return _wavBytes(samples, _sampleRate);
  }

  /// Birden fazla onceden uretilmis WAV klibini, aralarinda kucuk bir
  /// sessizlik payi birakarak arka arkaya birlestirir (warp/whoosh gibi
  /// iki asamali efektler icin).
  Uint8List _mix(List<Uint8List> clips, {int gapMs = 0}) {
    final gapSamples = (_sampleRate * gapMs / 1000).round();
    final gap = Int16List(gapSamples);
    final parts = <Int16List>[];
    for (var i = 0; i < clips.length; i++) {
      parts.add(_pcmFromWav(clips[i]));
      if (i != clips.length - 1 && gapSamples > 0) parts.add(gap);
    }
    final total = parts.fold<int>(0, (a, b) => a + b.length);
    final merged = Int16List(total);
    var offset = 0;
    for (final p in parts) {
      merged.setRange(offset, offset + p.length, p);
      offset += p.length;
    }
    return _wavBytes(merged, _sampleRate);
  }

  Int16List _pcmFromWav(Uint8List wav) {
    // WAV basligi sabit 44 byte (bizim _wavBytes ciktimizda hep boyle).
    final byteData = ByteData.sublistView(wav);
    final dataLength = (wav.length - 44) ~/ 2;
    final samples = Int16List(dataLength);
    for (var i = 0; i < dataLength; i++) {
      samples[i] = byteData.getInt16(44 + i * 2, Endian.little);
    }
    return samples;
  }

  /// Ard arda notalar (kisa aralarla) — odul/kazanma fanfarlari icin.
  Uint8List _sequence(
    List<(double, int)> notes, {
    required double amplitude,
    double harmonicMix = 0.0,
  }) {
    final parts = <Int16List>[];
    for (final note in notes) {
      final n = (_sampleRate * note.$2 / 1000).round();
      final samples = Int16List(n);
      final attack = math.max(1, (n * 0.08).round());
      final release = math.max(1, (n * 0.3).round());
      for (var i = 0; i < n; i++) {
        final phase = 2 * math.pi * note.$1 * i / _sampleRate;
        final phase2 = 2 * math.pi * (note.$1 * 2) * i / _sampleRate;
        var raw = math.sin(phase);
        if (harmonicMix > 0) {
          raw = raw * (1 - harmonicMix) + math.sin(phase2) * harmonicMix;
        }
        var env = 1.0;
        if (i < attack) {
          env = i / attack;
        } else if (i > n - release) {
          env = (n - i) / release;
        }
        samples[i] =
            (raw * amplitude * env * 32767).round().clamp(-32768, 32767).toInt();
      }
      parts.add(samples);
    }
    final total = parts.fold<int>(0, (a, b) => a + b.length);
    final merged = Int16List(total);
    var offset = 0;
    for (final p in parts) {
      merged.setRange(offset, offset + p.length, p);
      offset += p.length;
    }
    return _wavBytes(merged, _sampleRate);
  }

  Uint8List _wavBytes(Int16List samples, int sampleRate) {
    final dataLength = samples.length * 2;
    final bytes = ByteData(44 + dataLength);
    void s(int offset, String v) {
      for (var i = 0; i < v.length; i++) {
        bytes.setUint8(offset + i, v.codeUnitAt(i));
      }
    }

    s(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    s(8, 'WAVE');
    s(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    bytes.setUint16(32, 2, Endian.little); // block align
    bytes.setUint16(34, 16, Endian.little); // bits per sample
    s(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      bytes.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}

enum _Wave { sine, square }
