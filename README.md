# VidBunker Test Player — Analytics Verification

Minimal Flutter test app based on the supplied Codemagic-ready player project.

Preloaded videos:
- https://vidbunker.in/watch/t9oacLF5g
- https://vidbunker.in/watch/ckpRfY1jN

Manual Add Link remains available.

## Analytics test layer

The project adds the client-side analytics flow observed in the supplied Telegram Player APK:

- persistent `views_analytics` / `device_id`
- playback `event_id`, `device_id`, `video_id`, `played_sec`
- skip playback reports below 1 second
- HMAC-SHA256 signed analytics requests
- `X-Timestamp` and `X-Signature`
- `/collect` playback report
- `/collect_add_video_visit` add-video visit report
- server response fields `ok`, `counted`, and `remaining_today_like`

The preloaded videos test playback/view reporting. A manually added link tests both the visit report and playback reporting.

## Build

The existing Codemagic/Gradle setup from the supplied project is intentionally retained.

Codemagic runs:

```text
flutter pub get
flutter build apk --debug
```

Artifact:
`build/app/outputs/flutter-apk/app-debug.apk`
