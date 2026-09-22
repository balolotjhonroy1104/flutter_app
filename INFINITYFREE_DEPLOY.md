# Hosting the API on InfinityFree

A step-by-step guide to move your `api/` PHP folder from XAMPP to free InfinityFree
hosting, so your Flutter app works from anywhere (no more `192.168.1.149`).

**Already prepared for you:**
- `api_infinityfree.zip` (project root) — all 10 API files, ready to upload
- `api/config.php` — auto-detects InfinityFree vs XAMPP, so the same file works in both places
- `api/.htaccess` — blocks visitors from downloading `setup.sql` over the web

---

## Step 0 — What you already have

- InfinityFree **client account** (your DB names start with `if0_42976992`, so this exists)
- MySQL credentials in `config.php`:
  - Host: `sql105.infinityfree.com`
  - DB: `if0_42976992_app_db`, user `if0_42976992`

---

## Step 1 — Create the hosting account + subdomain

1. Log in at https://app.infinityfree.com
2. Click **Create Account** (the hosting account, not the client login).
3. Pick a **free subdomain**, e.g. `janry-attendance` → choose extension `infinityfreeapp.com`.
   → your site will be `http://janry-attendance.infinityfreeapp.com`
4. Wait a few minutes for activation (can take up to ~30 min on the first account).
5. From the account's control panel note:
   - **FTP host** (like `ftpupload.net`)
   - **FTP username** (like `if0_42976992`) and password (shown in the panel)
   - The **htdocs** folder is the web root.

> Wherever this guide says `janry-attendance.infinityfreeapp.com`, use YOUR subdomain.

---

## Step 2 — Import the database

1. In the control panel open **MySQL Databases** — the DB `if0_42976992_app_db` should
   already be listed (you created it when you got the credentials). If not, create it.
2. Click **Admin** / **phpMyAdmin** next to it and log in (MySQL password is in the panel,
   it is NOT your client-account password).
3. Select the database on the left, open the **Import** tab.
4. Choose `api/setup.sql` from this project → **Go**.
   This creates the `users`, `attendance`, and `auth_tokens` tables.
5. (Optional demo user) In phpMyAdmin's **SQL** tab run nothing special — instead just
   open `http://YOUR-SUBDOMAIN/seed.php` once in a browser. It creates
   `janry123 / password123`.

> Note: your data from XAMPP does NOT transfer automatically. Only the structure comes
> from setup.sql. If you want your existing users/attendance records too, export them
> from XAMPP's phpMyAdmin (`http://localhost/phpmyadmin` → `app_db` → Export) and import
> the same way.

---

## Step 3 — Upload the API files

**Option A — File manager (easiest):**
1. In the control panel open the **File Manager** (or "Online file manager").
2. Navigate into the `htdocs` folder.
3. Upload `api_infinityfree.zip` (from the project root) into `htdocs`.
4. Right-click the zip → **Extract** → then delete the zip.
5. Rename the extracted folder (probably `api_hosting`) to **`api`** so URLs end in `/api/...`.

**Option B — FTP with FileZilla:**
1. Site Manager → New site:
   - Host: `ftpupload.net`, Port: `21`, Protocol: FTP (plain)
   - User / password: from the control panel's FTP accounts section
2. On the remote side go into `htdocs`, create a folder `api`, and upload the **contents**
   of the project's `api/` folder (all .php files + `setup.sql` + `.htaccess`) into it.
   - Do NOT upload the `uploads/` folder content; the endpoint creates it on demand.

---

## Step 4 — Test in a browser first

Open these in a normal browser (replaces `YOUR-SUBDOMAIN`):

1. `http://YOUR-SUBDOMAIN/api/login.php` → should print JSON
   `{"success":false,"message":"Username and password are required"}` — **that means it works**.
2. If instead you see an HTML page with "security check" / JavaScript challenge,
   InfinityFree is blocking non-browser traffic. See the Troubleshooting section.

---

## Step 5 — Test with curl (the same kind of request the app makes)

```
curl -X POST http://YOUR-SUBDOMAIN/api/login.php -H "Content-type: application/json" -d "{\"username\":\"janry123\",\"password\":\"password123\"}"
```

- JSON with `"success":true` → you're done, go to Step 6.
- JSON with `"success":false,"message":"Invalid username or password"` → the API works,
  the demo user is missing → open `/seed.php` once, retry.
- HTML instead of JSON → the browser security system is blocking API clients (Troubleshooting).

---

## Step 6 — Point the Flutter app at the hosted API

In `lib/databases/constants.dart` change the IP-based URLs to your subdomain, e.g.:

```dart
static const String hostedBase = 'http://janry-attendance.infinityfreeapp.com';

static String get loginUrl => '$hostedBase/api/login.php';
static String get registerUrl => '$hostedBase/api/register.php';
static String get profileUrl => '$hostedBase/api/profile.php';
static String get changePasswordUrl => '$hostedBase/api/change_password.php';
static String get attendanceUrl => '$hostedBase/api/attendance.php';
static const String biometricUrl = '$hostedBase/api/enable_biometric.php';
static String get apiBaseUrlForUploads => '$hostedBase/api/';
```

Then run `flutter run` (full restart is enough — no native changes).

---

## Troubleshooting

**Browser shows "DNS Resolution Error - Domain Not Found"** — the hosting account
isn't finished activating, or the subdomain isn't attached yet. Wait, then re-check
the account's status in the panel.

**HTML security-check page instead of JSON** — InfinityFree's browser security system
is filtering non-browser requests. Known workarounds:
- Send browser-like headers from the app (`User-Agent`, `Accept`).
- Register/visit the site once in a phone browser first (some checks relax after that).
- If it still blocks API calls, InfinityFree simply isn't viable for a REST backend —
  plan B is exposing your XAMPP server with a tunnel (e.g. `cloudflared tunnel`) which
  gives a public HTTPS URL from your PC.

**500 error** — open the endpoint in a browser to see the real message; the panel's
"Logs" or phpMyAdmin help diagnose. Common cause: database tables missing → re-run
Step 2's import.

**404 on `/api/...`** — the files must be inside `htdocs/api/`, not `htdocs/api/api/`.
Check the folder nesting in the file manager.

**Pictures 404** — `uploads/` is created on first upload; make sure the folder has
write permission (the file manager shows file permissions).

---

## Security notes (school project level)

- `config.php` contains your real DB password — it's in the project folder. If you push
  this repo to GitHub, move the password out or add the repo to private first.
- `seed.php` creates a known demo user; delete it from the server after first use if
  you don't want that account.
- `profile.php` returns the password column to the app (you asked for that earlier).
  On shared hosting anyone with the URL can query it — fine for a demo, not for real users.
