<?php
// Profile endpoint used by lib/views/pages/profile_page.dart.
// POST JSON: { username }                -> returns the user's profile data.
// POST multipart (username + profile_picture file) -> updates the profile picture.
require 'config.php';

$isMultipart = !empty($_FILES)
    || (isset($_SERVER['CONTENT_TYPE'])
        && strpos($_SERVER['CONTENT_TYPE'], 'multipart/form-data') !== false);

if ($isMultipart) {
    $username = trim($_POST['username'] ?? '');

    if ($username === '') {
        echo json_encode(['success' => false, 'message' => 'Username is required']);
        exit;
    }

    if (empty($_FILES['profile_picture']) || $_FILES['profile_picture']['error'] !== UPLOAD_ERR_OK) {
        echo json_encode(['success' => false, 'message' => 'No profile picture received']);
        exit;
    }

    $uploadDir = __DIR__ . '/uploads/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0775, true);
    }
    $ext = strtolower(pathinfo($_FILES['profile_picture']['name'], PATHINFO_EXTENSION));
    $allowed = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    if (!in_array($ext, $allowed)) {
        echo json_encode(['success' => false, 'message' => 'Profile picture must be a JPG, PNG, GIF or WEBP image']);
        exit;
    }
    $profilePicture = 'uploads/' . uniqid('pic_', true) . '.' . $ext;
    if (!move_uploaded_file($_FILES['profile_picture']['tmp_name'], __DIR__ . '/' . $profilePicture)) {
        echo json_encode(['success' => false, 'message' => 'Failed to save the profile picture']);
        exit;
    }

    $conn = db_connect();

    // Keep the old picture so it can be deleted after a successful update.
    $stmt = $conn->prepare('SELECT profile_picture FROM users WHERE username = ? LIMIT 1');
    if (!$stmt) {
        echo json_encode(['success' => false, 'message' => 'Prepare failed: ' . $conn->error]);
        exit;
    }
    $stmt->bind_param('s', $username);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    $stmt->close();

    if (!$row) {
        if (file_exists(__DIR__ . '/' . $profilePicture)) {
            unlink(__DIR__ . '/' . $profilePicture);
        }
        echo json_encode(['success' => false, 'message' => 'User not found']);
        exit;
    }

    $stmt = $conn->prepare('UPDATE users SET profile_picture = ? WHERE username = ?');
    if (!$stmt) {
        echo json_encode(['success' => false, 'message' => 'Update prepare failed: ' . $conn->error]);
        exit;
    }
    $stmt->bind_param('ss', $profilePicture, $username);

    if ($stmt->execute()) {
        // Remove the replaced picture file, if any.
        $oldPicture = $row['profile_picture'];
        if ($oldPicture && file_exists(__DIR__ . '/' . $oldPicture)) {
            unlink(__DIR__ . '/' . $oldPicture);
        }
        echo json_encode([
            'success' => true,
            'message' => 'Profile picture updated.',
            'profile_picture' => $profilePicture,
        ]);
    } else {
        if (file_exists(__DIR__ . '/' . $profilePicture)) {
            unlink(__DIR__ . '/' . $profilePicture);
        }
        echo json_encode(['success' => false, 'message' => 'Failed to update profile picture']);
    }

    $stmt->close();
    $conn->close();
    exit;
}

// JSON request: return the user's profile data.
$input = json_decode(file_get_contents('php://input'), true);
$username = trim($input['username'] ?? ($_POST['username'] ?? ''));

if ($username === '') {
    echo json_encode(['success' => false, 'message' => 'Username is required']);
    exit;
}

$conn = db_connect();

$stmt = $conn->prepare('SELECT full_name, email, profile_picture, username, password FROM users WHERE username = ? LIMIT 1');
if (!$stmt) {
    echo json_encode(['success' => false, 'message' => 'Prepare failed: ' . $conn->error]);
    exit;
}
$stmt->bind_param('s', $username);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    echo json_encode([
        'success' => true,
        'message' => 'Profile loaded',
        'username' => $row['username'],
        'full_name' => $row['full_name'] ?? '',
        'email' => $row['email'] ?? '',
        'profile_picture' => $row['profile_picture'],
        'password' => $row['password'] ?? '',
    ]);
} else {
    echo json_encode(['success' => false, 'message' => 'User not found']);
}

$stmt->close();
$conn->close();
