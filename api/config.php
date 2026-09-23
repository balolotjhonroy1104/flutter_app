<?php

// Database configuration - auto-detects the environment:
//   - Running on InfinityFree hosting -> InfinityFree MySQL credentials
//   - Running anywhere else (localhost / LAN IP via XAMPP) -> XAMPP MySQL
// This lets the exact same api/ folder be uploaded to InfinityFree
// and still work on your local XAMPP server.
$host = strtolower($_SERVER['HTTP_HOST'] ?? '');

$isInfinityFree =
    strpos($host, 'infinityfreeapp.com') !== false
    || strpos($host, 'epizy.com') !== false
    || strpos($host, 'rf.gd') !== false
    || strpos($host, 'infinityfree') !== false;

if ($isInfinityFree) {
    // InfinityFree MySQL (from the hosting control panel).
    define('DB_HOST', 'sql110.infinityfree.com');
    define('DB_NAME', 'if0_42978499_app_db');
    define('DB_USER', 'if0_42978499');
    define('DB_PASS', 'janry123456');
} else {
    // XAMPP defaults.
    define('DB_HOST', 'localhost');
    define('DB_NAME', 'app_db');
    define('DB_USER', 'root');
    define('DB_PASS', '');
}

function db_connect() {
    try {
        $conn = new mysqli(
            DB_HOST,
            DB_USER,
            DB_PASS,
            DB_NAME
        );

        $conn->set_charset('utf8mb4');

        // Use Philippine time (UTC+8) for NOW() and every DATETIME the
        // server returns, so punches match the user's wall clock on any
        // host (InfinityFree servers run on UTC, 8 hours behind).
        $conn->query("SET time_zone = '+08:00'");

        return $conn;

    } catch (mysqli_sql_exception $e) {
        http_response_code(500);

        echo json_encode([
            'success' => false,
            'message' => 'Database connection failed: ' . $e->getMessage(),
        ]);

        exit;
    }
}

// Allow requests from the Flutter app.
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

// Preflight request from the browser.
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}
