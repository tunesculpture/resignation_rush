# Video Player — Flutter + Supabase

This project now uses a database-managed video catalog. The existing player, download implementation, analytics request catcher, playback settings, user agent and analytics service were retained. The two hard-coded demo links and manual Add Link flow have been removed.

## Features

- Fetches published videos from Supabase table `public.videos`.
- Home feed shows a 16:9 thumbnail, video title, category, and opens the existing player on tap.
- Supports direct image URLs or an HTML `<img src="...">` snippet as the thumbnail value; image source is extracted and rendered with a 16:9 `BoxFit.cover` frame.
- Search and pull-to-refresh.
- Existing player controls/settings, fullscreen, playback speed, fit/crop/stretch, seeking, mute, video size check, download handling and analytics reporting retained.
- AdMob uses Google's official Android test App ID and test ad units: home banner, native feed ads after each five videos, large banner below the player title/download controls, occasional interstitial video-capable ad (on every fourth opened video), and an opt-in rewarded video ad for 30 minutes without interstitials.
- The analytics source file `lib/analytics.dart` is unchanged. Analytics reports still use the prior worker configuration.

## Supabase project

Project: `video player`

- URL: `https://ixsmbnrjkhbumofnever.supabase.co`
- Region: `ap-south-1` (Mumbai)
- Table: `public.videos`

Columns include `title`, `video_url`, `thumbnail_url`, `description`, `category`, `is_published`, `sort_order`, `created_at`, and `updated_at`.

Row Level Security is enabled. Anonymous clients can only read published videos. Writes and the ability to view unpublished entries are restricted to users registered in `public.video_admins`.

## Admin panel setup

The `admin/index.html` page is the management interface. It lets an authorized admin create, edit, publish/unpublish, sort, and delete video records. Use a public image URL for thumbnail and video playback URL for the video. Thumbnails use 16:9 display ratio. The admin page can accept a direct image URL or `<img src="https://...">` snippet.

1. In Supabase Dashboard > Authentication > Users, create the admin account with email and password.
2. Open SQL Editor and run `supabase/admin-bootstrap.sql` after replacing `YOUR_ADMIN_EMAIL@example.com` with that exact email.
3. Host `admin/index.html` on a static HTTPS host (for example, a private admin-only page on your own domain), or open it locally in a browser. Sign in with the Supabase Auth account. The page uses the project's public publishable key and is protected by database RLS; it does not contain a service-role secret.
4. Add a video title, playback URL, thumbnail URL, and any optional metadata, then select Published and save. Refresh the mobile app to fetch newly published entries.

Do not make the page publicly discoverable if you can avoid it, and do not put the Supabase service-role key in the page or mobile app. Authorization is enforced in the database even if somebody reaches the admin page.

## AdMob testing

`android/app/src/main/AndroidManifest.xml` includes Google's official Android test app ID. `lib/main.dart` uses official test unit IDs for banner, native, interstitial, and rewarded formats. These IDs are for testing and must be replaced with the app's own production AdMob IDs before release. Continue using test units while developing; never click live ads to test.

## Build

Run:

```sh
flutter pub get
flutter build apk --debug
```

Codemagic builds the debug APK at `build/app/outputs/flutter-apk/app-debug.apk`.

## Notes

- This archive contains the source project, not a compiled APK. A Flutter/Codemagic build is needed to create the APK.
- The Supabase `videos` table is created; the admin interface starts empty until you add records.
- Video playback URLs need to be URLs that the existing `video_player`/ExoPlayer stack can play. A page URL is not necessarily a direct media URL, but the previously working player compatibility code was intentionally retained.
