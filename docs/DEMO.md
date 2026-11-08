# Cravey demo guide

How to run the backend, the app and Stripe locally, and a two-minute script that shows the two things the drops feature has to get right:

1. reserve, countdown, pay, confirmed
2. reserve, hold expires, stock comes back

There are two ways to run it. They differ only in who plays Stripe.

| | A. Demo profile | B. Real Stripe test mode |
|---|---|---|
| Stripe account | not needed | needed (test mode, free) |
| Payment sheet | simulated in the app | Stripe's real PaymentSheet |
| Who sends the webhook | `scripts/demo/pay_order.sh` | Stripe CLI (`stripe listen`) |
| Backend port | 8090 | 8080 |

Start with A. It runs everywhere and is what the automated tests and the smoke script exercise. Use B when you want to see a real test card go through Stripe.

Nothing below needs a real card. Never put live keys (`sk_live_`, `pk_live_`) into any of these commands.

---

## 0. One-time setup

| Tool | Version | Check |
|---|---|---|
| Java | **17** (what `pom.xml` and CI use) | `java -version` |
| Docker | any recent | `docker version` |
| Flutter | 3.44.x | `flutter doctor` |
| Stripe CLI | only for path B | `stripe --version` |

Java 17 on macOS:

```bash
brew install openjdk@17
```

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
```

Run that `export` in every terminal you start the backend from. The repository's Maven wrapper (`./mvnw`) downloads Maven itself, so nothing else is needed for the backend.

Flutter packages, once:

```bash
flutter pub get
```

---

## A. Demo profile (no Stripe account)

The `demo` profile swaps Stripe for an in-memory fake and seeds sample drops plus the four accounts behind the app's **Quick Demo Sign-In** buttons. It must never be pointed at a database real people use.

### A1. A throwaway database

```bash
docker run -d --name cravey_demo_pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=cravey -p 5499:5432 postgres:16-alpine
```

Port 5499 on purpose, so it cannot collide with a Postgres you already run.

### A2. Backend on port 8090

`DROPS_HOLD_MINUTES=1` shortens the 10-minute hold to 1 minute so expiry is quick to show.

```bash
cd backend && SERVER_PORT=8090 SPRING_PROFILES_ACTIVE=demo DB_URL=jdbc:postgresql://localhost:5499/cravey DB_USERNAME=postgres DB_PASSWORD=postgres STRIPE_SECRET_KEY=sk_test_demo STRIPE_PUBLIC_KEY=pk_test_demo STRIPE_WEBHOOK_SECRET=whsec_demo DROPS_HOLD_MINUTES=1 ./mvnw spring-boot:run
```

Ready when the log shows `Started ZomatoApplication`. Check it:

```bash
curl -s http://localhost:8090/drops | head -c 400
```

You should see the seeded drops, for example "Wagyu & Truffle Brioche Sando" (25 slots in total) and "Hokkaido Uni Butter Cacio e Pepe" (10 in total). Some slots are already taken in the seed data.

### A3. The app

Leave `STRIPE_PUBLISHABLE_KEY` unset: the payment sheet is then simulated.

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8090
```

On a phone emulator use `-d <device id>` (see `flutter devices`). The Android emulator reaches your Mac at `http://10.0.2.2:8090`, so pass `--dart-define=API_BASE_URL=http://10.0.2.2:8090` there. The iOS simulator can use `localhost`.

Sign in with **Quick Demo Sign-In** as the customer (debug builds only).

### A4. Playing Stripe

After you tap **Pay** in the app, the app shows "Verifying Confirmation..." and waits for Stripe's webhook. Send it yourself with the order id shown in the backend log (or `GET /orders`) and the amount in rupees:

```bash
API_BASE_URL=http://localhost:8090 STRIPE_WEBHOOK_SECRET=whsec_demo scripts/demo/pay_order.sh 4 24.50
```

Add `payment_intent.processing` as a third argument to play "payment in flight" (it keeps a hold alive past its expiry, which is the real-world 3-D Secure case).

### A5. Tear down

```bash
docker rm -f cravey_demo_pg
```

---

## B. Real Stripe test mode

### B1. Keys

In the Stripe dashboard switch to **Test mode**, then copy from Developers, API keys:

- `sk_test_...` secret key (backend)
- `pk_test_...` publishable key (app)

Keep them in your shell only. Do not commit them and do not paste them into files in this repository (`.env` files are gitignored; `*.example` templates are not).

### B2. Database

Any Postgres 16 works. Reuse the throwaway one from A1, or point `DB_URL` at your own.

### B3. Backend on port 8080 (not the demo profile)

The `demo` profile uses the fake gateway, so for real Stripe leave the profile unset and seed the sample data explicitly. Use your own `JWT_SECRET`:

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
export STRIPE_SECRET_KEY=sk_test_PASTE_YOURS
export STRIPE_PUBLIC_KEY=pk_test_PASTE_YOURS
export JWT_SECRET="$(openssl rand -base64 48)"
```

The webhook secret comes from the Stripe CLI in the next step, so start the CLI first.

### B4. Stripe CLI webhook forwarding

One-time login (opens your browser; you approve it):

```bash
stripe login
```

Print the signing secret the CLI will use. It starts with `whsec_` and stays the same for your machine:

```bash
stripe listen --print-secret
```

```bash
export STRIPE_WEBHOOK_SECRET=whsec_PASTE_THE_PRINTED_VALUE
```

Forward Stripe's events to the backend and leave this running in its own terminal:

```bash
stripe listen --forward-to localhost:8080/payment/webhook --events payment_intent.succeeded,payment_intent.payment_failed,payment_intent.processing,payment_intent.requires_action
```

Now start the backend in another terminal where the exports above are set:

```bash
cd backend && DB_URL=jdbc:postgresql://localhost:5499/cravey DB_USERNAME=postgres DB_PASSWORD=postgres SEED_DEMO_ACCOUNTS=true DROPS_HOLD_MINUTES=2 ./mvnw spring-boot:run
```

`SEED_DEMO_ACCOUNTS=true` creates the sample drops and the `customer@cravey.com` / `Password123!` account. Never use it on a database real people use.

### B5. The app with the real payment sheet

```bash
flutter run -d <ios simulator or android emulator id> --dart-define=API_BASE_URL=http://localhost:8080 --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_PASTE_YOURS
```

(Android emulator: `API_BASE_URL=http://10.0.2.2:8080`.) The Quick Demo Sign-In needs the `demo`/`dev` profile on the backend, so sign in with the form as `customer@cravey.com` / `Password123!` instead.

### Test cards

Any future expiry date, any 3-digit CVC, any postal code.

| Card number | What happens |
|---|---|
| `4242 4242 4242 4242` | Succeeds. Use this for the happy path. |
| `4000 0025 0000 3155` | Needs 3-D Secure: the sheet shows a challenge to approve. Good for the "payment in flight keeps the hold alive" case. |
| `4000 0000 0000 9995` | Declined, insufficient funds. The order stays unpaid and the hold stays until it expires. |
| `4000 0000 0000 0002` | Declined, generic. |

Stripe's own list: https://docs.stripe.com/testing

---

## Two-minute demo script

Use the seeded live drop **Wagyu & Truffle Brioche Sando**. The hold length is 1 minute in path A (2 minutes in path B). Have the backend log visible in a second window; it prints each drop sweep.

### Part 1: reserve, countdown, pay, confirmed (about 60 seconds)

1. Sign in as the customer. Open the drop. The seeded database starts with some slots already taken (20 of 25 left on a fresh start). Say: "Limited slots, and nobody can hold more than one per drop."
2. Tap **Reserve a slot**. A "Slot held for you" banner appears with a countdown (`01:00` in path A). Say: "The countdown is the server's clock, not the phone's, so a wrong phone clock cannot extend a hold."
3. Tap through to checkout, then **Pay**. Path A: the sheet is simulated, then run `scripts/demo/pay_order.sh <orderId> 24.50` in a terminal. Path B: pay with `4242 4242 4242 4242`.
4. The app shows "Payment successful! Your slot is secured." and lands on your orders. The reservation is now confirmed and the order is paid.
5. Back on the drop, the count has dropped by one (20 left became 19 on a fresh start). Say: "One slot taken, exactly once."

### Part 2: reserve, expire, stock returns (about 60 seconds)

1. Stay signed in and open a second drop: **Hokkaido Uni Butter Cacio e Pepe** (10 slots). The limit is one active hold per drop, so holding a Wagyu slot does not block this.
2. Tap **Reserve a slot**. Note the count (2 left on a fresh start; it drops to 1). Do not pay.
3. Watch the countdown reach `00:00`. The banner disappears and, if you had opened checkout, it says "This hold has expired".
4. Within about 15 seconds (the sweep interval) the backend log shows `Drop sweep: expire stale holds -> 1`. The count goes back up (1 left becomes 2 again) and **Reserve a slot** is available again. Say: "The slot went back to the pool and anyone can take it."
5. If asked "what if they paid at the last second?": run `scripts/demo/pay_order.sh <orderId> <amount>` after expiry. If the slot is still free it is reclaimed and the order is confirmed; if someone else took it, the payment is refunded and the app says the drop sold out and the payment is refunded.

### What to point at

- The slot count only ever moves by one per reserve, per expiry, per refund.
- A paid order whose slot is gone is refunded automatically, never silently kept.
- The countdown agrees with the server even if the phone clock is hours off.

---

## If something goes wrong

| Symptom | Fix |
|---|---|
| Backend exits with `JWT_SECRET is not set` | You ran the `prod` profile without `JWT_SECRET`. Set it, or drop the profile. |
| Port 8080 or 8090 already in use | Another backend is running. Pick another `SERVER_PORT`, and match it in `API_BASE_URL`. |
| App says it cannot reach the server on Android | Use `http://10.0.2.2:<port>`, not `localhost`. |
| Payment sheet never appears | `STRIPE_PUBLISHABLE_KEY` was not passed to `flutter run`. Unset it only in path A. |
| Webhook returns 400 "Invalid webhook signature" | `STRIPE_WEBHOOK_SECRET` in the backend does not match `stripe listen --print-secret` (path B) or the script's secret (path A). |
| Order stays "Verifying Confirmation..." | No webhook arrived. Check the `stripe listen` terminal (path B), or run `pay_order.sh` (path A). |
| Hold does not expire | The sweep runs every 15 seconds. Wait, then look for `Drop sweep: expire stale holds` in the backend log. |

---

## What was and was not verified

Path A was run live against a throwaway Postgres on the day this was written (backend started with the exact A2 command): demo sign-in, reserve, checkout, `pay_order.sh` (reservation CONFIRMED, order PAID), and an unpaid reservation that expired and returned its slot. The Flutter UI steps (what the banner and screens say) match the widget tests but were not clicked through in a simulator. Path A's backend steps and the expiry behaviour are also covered by the automated suites (`DropHoldPolicyAndWaitlistTest`, `DropPostgresIntegrationTest`, `test/app_flow_test.dart`) and by `scripts/demo/e2e_drops_smoke.py`. Path B has not been run end to end by the author of this guide: it needs a Stripe test account, the Stripe CLI and a simulator, none of which were available when this was written. Treat the B commands as a checklist to confirm, and fix this file where they differ.
