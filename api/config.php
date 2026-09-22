<?php
// Database configuration for InfinityFree MySQL.
// Change these if your MySQL setup differs.
define('DB_HOST', 'sql105.infinityfree.me');
define('DB_NAME', 'if0_42976992_app_db');
define('DB_USER', 'if0_42976992');
define('DB_PASS', 'YOUR_DATABASE_PASSWORD');

function db_connect() {
    try {git commit -m "Update API URLs for online server"
        $conn = new mysqli (
            DB_HOST,DB_USER,DB_PASS,DB_NAME
        );
        $conn->set_charset('utf8mb4');
        return $conn;
    }catch (mysqli_sql_exception $e) {
        http_response_code(500);

        echo json_encode([
            'success' => false,
            'message' => 'Database connection failed'
        ]);
        exit;
    }
}
// Allow requests from the Flutter app (web needs CORS).
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

// Preflight request from the browser.
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}