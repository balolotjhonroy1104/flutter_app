<?php
// Database configuration for XAMPP (default credentials).
// Change these if your MySQL setup differs.
define('DB_HOST', 'localhost');
define('DB_NAME', 'app_db');
define('DB_USER', 'root');
define('DB_PASS', '');

function db_connect() {
    try {
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