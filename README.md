# TweetFlow AI — Flutter + Supabase project

## Live Supabase project
- Name: TweetFlow AI
- Project ref: `rrtahdvdcczbxzsukjgl`
- Region: `ap-south-1` (Mumbai)
- URL: `https://rrtahdvdcczbxzsukjgl.supabase.co`
- Edge Functions deployed: `tweetflow-api` and `tweetflow-admin`
- Database tables and RLS have been applied to the live project.

## Android build reference
Based on the supplied `video-player-ui-improved(3).zip`: Flutter stable, AGP 8.11.1, Kotlin 2.2.20, Java/Kotlin target 17, min SDK 23, Supabase Flutter 2.15.4. Unity plugin is pinned to `unity_ads_plugin: ^0.6.0`. `codemagic.yaml` builds a release APK.

## Unity Ads
- Game ID: `800438578`
- Rewarded: `BP_Rewarded_Android`
- Banner: `BP_Banner_Android`
- Test mode is currently enabled in `lib/main.dart`; switch off only after testing and production approval.

## Admin setup (required)
1. In Supabase Dashboard > Authentication > Users, create an email/password admin user.
2. Replace `YOUR_ADMIN_EMAIL@example.com` in `supabase/admin-bootstrap.sql` with that exact email and run the SQL in the project's SQL Editor.
3. Disable email confirmation in Supabase Auth settings to match the requested no-verification signup flow.
4. Host `admin/index.html` on an HTTPS static host. Sign in with the admin account.
5. Add your custom API provider using its HTTPS base URL, API key, and comma-separated model IDs. Provider must support OpenAI-compatible `POST /chat/completions`. Then activate a model.
6. Configure global prompt, free tweet count, tweets per rewarded ad and max rewarded ads per day.

## Custom API compatibility
The backend calls `<base_url>/chat/completions` with `Authorization: Bearer <key>`, JSON messages and the selected model ID. It parses `{"tweets":[...]}` from the assistant response. The provider key is not included in the Flutter APK. Model discovery is manual in this initial version: enter model IDs in Admin Panel and select the active model. Non-OpenAI-compatible APIs need an adapter.

## Build on Codemagic
Connect the extracted project folder to Codemagic and use `codemagic.yaml`. The workflow runs `flutter pub get`, `flutter analyze`, then `flutter build apk --release`. Output: `build/app/outputs/flutter-apk/app-release.apk`.

## Important limitations before public launch
- The floating overlay is **not fully implemented**. This version only includes the permission request hook; the foreground overlay service, tweet controls and auto-advance still need implementation and device testing.
- Reward unlock currently trusts the SDK completion callback and the Edge Function records `reward_verified=false`. Client callbacks can be spoofed. Implement Unity server-to-server callbacks and signature/replay validation before monetized public release.
- Model fetching from the provider's `/models` endpoint is not implemented; model IDs are entered manually.
- Previous-day tweet rows are not automatically deleted. The app only presents today's campaign. Add a retention cleanup job if database deletion is required.
- No Codemagic build was run in this environment, so the ZIP is a configured source project, not a verified APK. Run the workflow and share the complete logs if it fails.
- For production security, move provider API-key encryption to Supabase Vault/KMS before scaling. Keys are restricted to server-side service-role access in this setup, but application-level encryption is not included.
