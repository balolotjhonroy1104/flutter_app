<?php
// Login endpoint used by lib/views/pages/login_page.dart.
// Accepts JSON or form-encoded POST: { username, password }
//
// On success it also returns user_id + a fresh auth token so the app can
// offer "Enable biometric authentication?" afterwards (the token is stored
// in auth_tokens and validated by enable_biometric.php).
require 'config.php';

$input = json_decode(file_get_contents('php://input'), true);
$username = trim($input['username'] ?? ($_POST['username'] ?? ''));
$password = $input['password'] ?? ($_POST['password'] ?? '');

if ($username === '' || $password === '') {
    echo json_encode(['success' => false, 'message' => 'Username and password are required']);
    exit;
}

$conn = db_connect();

// Self-heal: make sure the token table exists even on installs that
// never re-ran api/setup.sql.
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

$stmt = $conn->prepare('SELECT id, password FROM users WHERE username = ? LIMIT 1');
if (!$stmt) {
    echo json_encode(['success' => false, 'message' => 'Prepare failed: ' . $conn->error]);
    exit;
}
$stmt->bind_param('s', $username);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    if ($password === $row['password']) {
        $userId = (int) $row['id'];

        // Fresh token for this session; used to enable biometric login.
        $token = bin2hex(random_bytes(32));
        $tokenStmt = $conn->prepare(
            'INSERT INTO auth_tokens (user_id, token) VALUES (?, ?)'
        );
        if ($tokenStmt) {
            $tokenStmt->bind_param('is', $userId, $token);
            $tokenStmt->execute();
            $tokenStmt->close();
        }

        echo json_encode([
            'success' => true,
            'message' => 'Login successful',
            'username' => $username,
            'user_id' => $userId,
            'token' => $token,
        ]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Incorrect password']);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'User not found']);
}

$stmt->close();
$conn->close();
