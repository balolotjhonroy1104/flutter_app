<?php
// Registration endpoint.
// Accepts multipart/form-data or JSON/form-encoded POST.
require 'config.php';
header('Content-Type: application/json');
// ============================================================
// GET INPUT
// ===========================================================
$isMultipart = !empty($_FILES)
    || (
        isset($_SERVER['CONTENT_TYPE'])
        && strpos(
            $_SERVER['CONTENT_TYPE'],
            'multipart/form-data'
        ) !== false
    );
if ($isMultipart) {
    $fullName = trim($_POST['full_name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';
    $confirmPassword = $_POST['confirm_password'] ?? '';
} else {
    $input = json_decode(
        file_get_contents('php://input'),
        true
    );
    $fullName = trim(
        $input['full_name'] ?? ($_POST['full_name'] ?? '')
    );
    $email = trim(
        $input['email'] ?? ($_POST['email'] ?? '')
    );
    $username = trim(
        $input['username'] ?? ($_POST['username'] ?? '')
    );
    $password =
        $input['password']
        ?? ($_POST['password'] ?? '');

    $confirmPassword =
        $input['confirm_password']
        ?? ($_POST['confirm_password'] ?? '');
}
// ============================================================
// VALIDATION
// ============================================================
if ($username === '' || $password === '') {
    echo json_encode([
        'success' => false,
        'message' => 'Username and password are required'
    ]);
    exit;
}
if (strlen($password) < 6) {
    echo json_encode([
        'success' => false,
        'message' => 'Password must be at least 6 characters'
    ]);
    exit;
}
if (
    $confirmPassword !== ''
    && $password !== $confirmPassword
) {
    echo json_encode([
        'success' => false,
        'message' => 'Passwords do not match'
    ]);
    exit;
}
if (
    $email !== ''
    && !filter_var($email, FILTER_VALIDATE_EMAIL)
) {
    echo json_encode([
        'success' => false,
        'message' => 'Please enter a valid email address'
    ]);
    exit;
}
// ============================================================
// PROFILE PICTURE
// ============================================================
$profilePicture = null;
if (
    !empty($_FILES['profile_picture'])
    && $_FILES['profile_picture']['error'] === UPLOAD_ERR_OK
) {
    $uploadDir = __DIR__ . '/uploads/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0775, true);
    }
    $ext = strtolower(
        pathinfo(
            $_FILES['profile_picture']['name'],
            PATHINFO_EXTENSION
        )
    );
    $allowed = [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp'
    ];
    if (!in_array($ext, $allowed)) {

        echo json_encode([
            'success' => false,
            'message' =>
                'Profile picture must be a JPG, PNG, GIF or WEBP image'
        ]);
        exit;
    }
    $profilePicture =
        'uploads/' .
        uniqid('pic_', true) .
        '.' .
        $ext;
    if (
        !move_uploaded_file(
            $_FILES['profile_picture']['tmp_name'],
            __DIR__ . '/' . $profilePicture
        )
    ) {
        echo json_encode([
            'success' => false,
            'message' => 'Failed to save the profile picture'
        ]);
        exit;
    }
}
// ============================================================
// DATABASE CONNECTION
// ============================================================
$conn = db_connect();

// Self-heal: older installs may be missing the biometric column and
// the auth_tokens table used below. (XAMPP's MariaDB supports
// ADD COLUMN IF NOT EXISTS; other MySQL builds throw, which we
// ignore because then the column already exists.)
try {
    $conn->query(
        'ALTER TABLE users
            ADD COLUMN IF NOT EXISTS biometric_enabled
            TINYINT(1) NOT NULL DEFAULT 0 AFTER password'
    );
} catch (mysqli_sql_exception $e) {
    // Column already exists.
}
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
// ============================================================
// CHECK DUPLICATE USERNAME
// ============================================================
$stmt = $conn->prepare(
    'SELECT id FROM users WHERE username = ? LIMIT 1'
);
if (!$stmt) {
    echo json_encode([
        'success' => false,
        'message' => 'Prepare failed: ' . $conn->error
    ]);

    exit;
}
$stmt->bind_param(
    's',
    $username
);
$stmt->execute();
$stmt->store_result();
if ($stmt->num_rows > 0) {
    $stmt->close();
    $conn->close();
    // Delete uploaded picture if username already exists.
    if (
        $profilePicture !== null
        && file_exists(__DIR__ . '/' . $profilePicture)
    ) {
        unlink(__DIR__ . '/' . $profilePicture);
    }
    echo json_encode([
        'success' => false,
        'message' => 'Username already taken'
    ]);
    exit;
}
$stmt->close();
// ============================================================
// CREATE USER
// ============================================================
// Biometric is OFF by default.
$biometricEnabled = 0;
$stmt = $conn->prepare(
    'INSERT INTO users
    (
        full_name,
        email,
        profile_picture,
        username,
        password,
        biometric_enabled
    )
    VALUES (?, ?, ?, ?, ?, ?)'
);
if (!$stmt) {
    echo json_encode([
        'success' => false,
        'message' =>
            'Insert prepare failed: ' . $conn->error
    ]);
    exit;
}
$stmt->bind_param(
    'sssssi',
    $fullName,
    $email,
    $profilePicture,
    $username,
    $password,
    $biometricEnabled
);
// ============================================================
// INSERT USER
// ============================================================
if ($stmt->execute()) {
    // Get the ID of the newly created user.
    $userId = $conn->insert_id;
    // ========================================================
    // GENERATE AUTHENTICATION TOKEN
    // ========================================================
    $token = bin2hex(random_bytes(32));
    // ========================================================
    // CREATE TOKEN TABLE RECORD
    // ========================================================
    $tokenStmt = $conn->prepare(
        'INSERT INTO auth_tokens
        (user_id, token)
        VALUES (?, ?)'
    );
    if (!$tokenStmt) {
        // Delete user if token creation cannot be prepared.
        $deleteStmt = $conn->prepare(
            'DELETE FROM users WHERE id = ?'
        );
        if ($deleteStmt) {
            $deleteStmt->bind_param('i', $userId);
            $deleteStmt->execute();
            $deleteStmt->close();
        }
        if (
            $profilePicture !== null
            && file_exists(__DIR__ . '/' . $profilePicture)
        ) {
            unlink(__DIR__ . '/' . $profilePicture);
        }
        echo json_encode([
            'success' => false,
            'message' =>
                'Failed to create authentication token: '
                . $conn->error
        ]);
        exit;
    }
    $tokenStmt->bind_param(
        'is',
        $userId,
        $token
    );
    if (!$tokenStmt->execute()) {
        $tokenStmt->close();
        echo json_encode([
            'success' => false,
            'message' =>
                'Failed to save authentication token'
        ]);
        exit;
    }
    $tokenStmt->close();
    // ========================================================
    // RETURN RESULT TO FLUTTER
    // ========================================================
    echo json_encode([
        'success' => true,
        'message' => 'Account created successfully.',
        'user_id' => $userId,
        'username' => $username,
        'token' => $token,
        'biometric_enabled' => false,
        'profile_picture' => $profilePicture
    ]);
} else {
    // Delete image if database insertion failed.
    if (
        $profilePicture !== null
        && file_exists(__DIR__ . '/' . $profilePicture)
    ) {
        unlink(__DIR__ . '/' . $profilePicture);
    }
    echo json_encode([
        'success' => false,
        'message' =>
            'Registration failed, please try again'
    ]);
}
$stmt->close();
$conn->close();