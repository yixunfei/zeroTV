# Offline live-video fixture

`red_transport_stream.dart` contains a generated red H.264 MPEG-TS video, not an
external broadcast. The in-process HTTP server deliberately omits Content-Length
and Range support, reproducing Android's rejected surface-attachment seek.

Regenerate the sample with FFmpeg, then encode the bytes into the Dart fixture:

```text
ffmpeg -f lavfi -i color=c=red:s=160x90:r=10 -t 10 -an -c:v libx264 -profile:v baseline -pix_fmt yuv420p -g 10 -f mpegts red-live.ts
```

The integration test verifies the actual Flutter screenshot center is red;
decoding audio or reporting video dimensions alone is not sufficient.
