# TweetFlow AI — current implementation scope

- Flutter Android app with email/password Supabase Auth.
- Bottom navigation: Generate and Topics.
- Topic cards show title and description; Copy copies both.
- Generation accepts pasted/custom topic and optional tagline.
- Global prompt is configured in web admin; individual users cannot set it.
- Natural medium-length tweet generation through a custom OpenAI-compatible provider.
- Admin can add providers, model IDs, select the active model, and set generation quotas.
- Individual tweet cards have repeatable Copy and copied indicator. No edit, individual regenerate, or Copy All.
- Daily campaigns and generated tweets are stored in Supabase; topic snapshots preserve active campaign context.
- Unity rewarded placement `BP_Rewarded_Android`; Unity banner placement `BP_Banner_Android`.
- Codemagic builds Android APK.

## Not yet complete
- Full Android floating overlay service and controls are not implemented; current source only requests overlay permission.
- Secure Unity server-to-server reward verification is not complete. Client completion callback is not fraud-proof.
- API model discovery/fetch models is not implemented; admin pastes comma-separated model IDs.
- Automated previous-day database cleanup is not configured.
