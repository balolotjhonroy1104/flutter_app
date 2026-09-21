<?php
// Enables (or disables) biometric login for a user.
// Called by lib/functions/biometric_function.dart after the user
// authenticates with fingerprint/face on the device.
//
// POST JSON: {
//   user_id: int,
//   biometric_enabled: 1,
//   Authorization header: 'Bearer <token>'  (or 'token' in the body)
// }
require 'config.php';

$input = json_decode(file_get_contents('php://input'), true);

$userId = (int) ($input['user_id'] ?? 0);
$enabled = !empty($input['biometric_enabled']) ? 1 : 0;

// Bearer token proves this device is the one that just registered
// (the same token register.php returned and stored in auth_tokens).
$authHeader = $_SERVER['HTTP_AUTHORIZATION']
    ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
$token = '';
if (preg_match('/Bearer\s+(\S+)/i', $authHeader, $m)) {
    $token = $m[1];
}
// Fallback: some Apache setups strip the Authorization header,
// so also accept the token in the JSON body.
if ($token === '') {
    $token = trim($input['token'] ?? '');
}

if ($userId <= 0 || $token === '') {
    echo json_encode([
        'success' => false,
        'message' => 'user_id and token are required',
    ]);
    exit;
}

$conn = db_connect();

// Makes sure the auth_tokens table exists (older installs that never
// ran the updated api/setup.sql).
$conn->query(
    'CREATE TABLE IF NOT EXISTS auth_tokens (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        token VARCHAR(128) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_auth_tokens_token (token),
        INDEX idx_auth_tokens_user (user_id)
    )'
);

// The token must belong to this exact user.
$stmt = $conn->prepare(
    'SELECT id FROM auth_tokens WHERE token = ? AND user_id = ? LIMIT 1'
);
if (!$stmt) {
    echo json_encode([
        'success' => false,
        'message' => 'Prepare failed: ' . $conn->error,
    ]);
    exit;
}
$stmt->bind_param('si', $token, $userId);
$stmt->execute();
if ($stmt->get_result()->num_rows === 0) {
    $stmt->close();
    $conn->close();
    echo json_encode([
        'success' => false,
        'message' => 'Invalid or expired token. Please sign up again.',
    ]);
    exit;
}
$stmt->close();

// Older installs may be missing the biometric column on users.
try {
    $conn->query(
        'ALTER TABLE users
            ADD COLUMN IF NOT EXISTS biometric_enabled
            TINYINT(1) NOT NULL DEFAULT 0 AFTER password'
    );
} catch (mysqli_sql_exception $e) {
    // Column already exists (or MySQL build without IF NOT EXISTS support).
}

$stmt = $conn->prepare(
    'UPDATE users SET biometric_enabled = ? WHERE id = ?'
);
if (!$stmt) {
    echo json_encode([
        'success' => false,
        'message' => 'Prepare failed: ' . $conn->error,
    ]);
    exit;
}
$stmt->bind_param('ii', $enabled, $userId);

if ($stmt->execute()) {
    echo json_encode([
        'success' => true,
        'message' => $enabled
            ? 'Biometric login enabled'
            : 'Biometric login disabled',
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to update the biometric setting',
    ]);
}

$stmt->close();
$conn->close();
