# app

A Flutter app whose login page authenticates against a MySQL database through
PHP served by XAMPP.

## Connecting the login page to the database (XAMPP)

### 1. Copy the PHP files into XAMPP

Copy the `api/` folder into XAMPP's web root so the URL below works:

```
C:\xampp\htdocs\app_api\    <- contains config.php, login.php, register.php, seed.php, setup.sql
```

### 2. Start Apache and MySQL

Open the XAMPP Control Panel and start both **Apache** and **MySQL**.

### 3. Create the database and table

Open phpMyAdmin at http://localhost/phpmyadmin, go to the **SQL** tab, paste the
contents of `api/setup.sql`, and run it. This creates the `app_db` database with
a `users` table whose columns follow the sign-up form order: `full_name`,
`email`, `profile_picture`, `username`, `password` (confirm password is only
checked before saving and never stored).

> Already ran an older version of `setup.sql`? Run this instead to add any
> missing columns and reorder them to match the form (works on XAMPP's MariaDB):
>
> ```sql
> ALTER TABLE users
>     ADD COLUMN IF NOT EXISTS full_name VARCHAR(100) DEFAULT NULL AFTER id,
>     ADD COLUMN IF NOT EXISTS email VARCHAR(100) DEFAULT NULL AFTER full_name,
>     ADD COLUMN IF NOT EXISTS profile_picture VARCHAR(255) DEFAULT NULL AFTER email,
>     MODIFY COLUMN username VARCHAR(50) NOT NULL AFTER profile_picture,
>     MODIFY COLUMN password VARCHAR(255) NOT NULL AFTER username;
> ```

### 4. Seed the demo user

Open http://localhost/app_api/seed.php once in your browser. It inserts the
account the login page ships with, using a hashed password:

- username: `janry123`
- password: `password123`

### 5. Signing up new users

The sign-up page in the app posts to `register.php`, which inserts the new
account (username, full name, email, and an optional profile picture) straight
into MySQL with a hashed password — no code changes needed to add users.
Accounts created there can log in immediately.

Profile pictures are saved to `C:\xampp\htdocs\app_api\uploads\` and only the
file path is stored in the database. Make sure that folder is writable (Apache
creates it automatically on first upload).

### 6. Run the app

- **Android emulator**: works out of the box (the app reaches the host PC via
  `10.0.2.2`).
- **Web / desktop**: works out of the box (`localhost`).
- **Physical phone**: edit `apiBaseUrl` in `lib/databases/constants.dart` to
  your PC's LAN IP, e.g. `http://192.168.1.10`, and make sure the phone and PC
  are on the same network.

### Testing the endpoint manually

```bash
curl -X POST http://localhost/app_api/login.php \
  -H "Content-Type: application/json" \
  -d '{"username":"janry123","password":"password123"}'
```

Expected response: `{"success":true,"message":"Login successful",...}`

Register with a profile picture (multipart, fields in form order):

```bash
curl -X POST http://localhost/app_api/register.php \
  -F "full_name=Jane Doe" \
  -F "email=jane@example.com" \
  -F "username=jane" \
  -F "password=secret123" \
  -F "confirm_password=secret123" \
  -F "profile_picture=@myphoto.jpg"
```

## Getting Started

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
