<?php
// One-time setup script: creates the demo user used by the Flutter login page.
// Open http://localhost/app_api/seed.php once after running setup.sql.
require 'config.php';

$conn = db_connect();

$username = 'janry123';
$password = 'password123';
$hash = password_hash($password, PASSWORD_DEFAULT);

$stmt = $conn->prepare(
    'INSERT INTO users (username, password) VALUES (?, ?)
     ON DUPLICATE KEY UPDATE password = VALUES(password)'
);
$stmt->bind_param('ss', $username, $hash);
$stmt->execute();
$stmt->close();
$conn->close();

echo json_encode([
    'success' => true,
    'message' => 'Demo user created: janry123 / password123',
]);