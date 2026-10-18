# Forki

Forki is a SwiftUI nutrition tracker with a virtual pet. Meal history, daily totals, calorie goals, and the device profile persist locally. Optional Supabase accounts provide explicit backup/restore and authenticated photo analysis.

## Build

- Xcode 26 or newer, with an installed iOS simulator runtime compatible with its SDK.
- iOS 18.5 or newer. A physical device is required to test camera capture; Simulator supports photo-library selection.
- Open `HabitPet.xcodeproj`, select the `HabitPet` scheme and an iPhone simulator, then Run. Lottie 4.6.1 is resolved by Swift Package Manager.
- `HabitPet/CalorieCameraConfig.plist` contains `SUPABASE_FUNCTIONS_URL` and the public `SUPABASE_ANON_KEY`. These public configuration values are included in the app. OpenAI, USDA, and Supabase service-role secrets belong exclusively on the server. `.env.local` is not read by the native app.

The app no longer depends on an external Downloads-folder copy of CalorieCameraKit. The historical camera-package directories are retained as reference; they are not part of the app build. Capture uses Apple's camera/photo picker. Photo analysis estimates the entire pictured portion and asks for confirmation before logging. It does not measure depth or guarantee portion accuracy. Manual logging and bundled popular foods work without an account; cloud food search requires the deployed USDA proxy. AI analysis requires signing in through Profile.

Onboarding saves a local profile, not a cloud account. Profile supports email/password account creation, email confirmation, sign-in/out, explicit backup/restore, and permanent account deletion. The session is stored in device-only Keychain. Notifications schedule breakfast, lunch, and dinner reminders only after system permission is granted.

## Nutrition behavior

A saved `LoggedFood.food` contains the selected portion's calories/macros; `portion` is metadata. Daily totals sum those values once, preserving the existing `hp_loggedMeals_v1` format. Totals use the device's local calendar day and refresh at day changes and foreground entry. Historical logs remain available in Stats. Saved custom goals take precedence over onboarding defaults. The onboarding targets are simple presets, not personalized calculations from biometrics.

USDA results use relevance ranking, tolerate numeric or string food identifiers, and prefer Atwater-specific energy (2048), followed by legacy Energy (1008), then Atwater-general (2047). USDA nutrition is per 100 g; the logging UI labels that basis. Camera totals already describe the pictured portion and are not replaced with an unrelated USDA serving.

## Checks

```sh
swift test --scratch-path /tmp/forki-core-tests
xcodebuild -project HabitPet.xcodeproj -scheme HabitPet \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test
npx --yes deno@2.9.6 fmt --check supabase/functions
npx --yes deno@2.9.6 check supabase/functions/analyze_food/index.ts supabase/functions/food_search/index.ts supabase/functions/delete_account/index.ts
npx --yes deno@2.9.6 test --deny-net --deny-env supabase/functions
scripts/test-database.sh
```

Choose a simulator actually installed on your machine. Database tests require local PostgreSQL tools (`pg_config`); override `FORKI_POSTGRES_BIN` if necessary. They create a disposable, socket-only cluster, apply migrations against a fixture of the existing schema, and check ownership, RPC grants, insert/update/delete triggers, and backup isolation. They never connect to production. GitHub Actions runs core, iOS, Edge Function, and database checks separately.

## Server rollout

Deploy the backend before distributing this client. No production migration, function deployment, credential rotation, or database upgrade is performed by opening this PR.

1. Back up the Supabase project and review the migrations against its current schema. `20261018134849_restrict_public_rpc_access.sql` restricts the existing seven helper functions, fixes mutable search paths, enforces progress-calculation ownership, and repairs delete/update trigger handling. `20261018135441_account_backups.sql` adds an owner-only backup table with account-deletion cascade.
2. Rotate the USDA key previously embedded in the app through USDA's account tools. Removing it from source does not revoke copies in history or old app binaries. Set the replacement as `USDA_API_KEY` in Supabase Edge Function secrets. Do not commit it. Set `OPENAI_API_KEY` there too; set `OPENAI_MODEL=gpt-6-luna`. The account deletion function uses Supabase's server-provided `SUPABASE_SERVICE_ROLE_KEY`, never a client key.
3. With a current CLI (verified version 2.121.0), link the intended project and review/apply the migrations: `npx supabase@2.121.0 db push`. Deploy `food_search`, `analyze_food`, and `delete_account` with JWT verification enabled, as specified in `supabase/config.toml`. `food_search` permits the public app key but bounds upstream queries; paid AI requests additionally verify a non-anonymous user with Supabase Auth. Old anonymous camera clients must upgrade and sign in.
4. Smoke-test registration/confirmation, sign-in/refresh/sign-out, USDA search, a real food image, invalid/revoked sessions, backup/restore between two devices, and deletion using disposable accounts. A deletion first revokes sessions and then removes the Auth user and cascading backup. If deletion fails after revocation, sign in again to retry. Tests mock upstream services; real credentials, model access, deliverability, camera permission, and device capture require this deployment check.
5. Schedule the managed Postgres minor upgrade separately. The inspected project was on Postgres 17.6 (`17.6.1.008`); Supabase now offers 17.11. Review extension compatibility and downtime in the dashboard before upgrading. Hosted Auth/Edge runtime versions are managed by Supabase, not Swift dependencies. The repository's older Vercel web deployments should point to the website branch rather than this native app branch.

Dependency/service references checked October 18, 2026: [Lottie releases](https://github.com/airbnb/lottie-ios/releases), [OpenAI deprecations](https://developers.openai.com/api/docs/deprecations) (GPT-4o mini shutdown January 14, 2027; replacement GPT-6 Luna), and [Supabase database changelog](https://supabase.com/changelog?tags=database). The checked-in Edge Functions replace old remote std imports with native Deno APIs. Production `analyze_food` source could not be retrieved for a complete parity comparison; review its deployment before replacing it.

## Other code

The `website` branch contains the web landing page. Legacy CalorieCameraKit snapshots and demo folders are not required for the native app. See [LICENSE](LICENSE).
