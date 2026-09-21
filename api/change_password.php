<?php
// Change password endpoint used by the ChangePasswordSheet in
// lib/views/pages/profile_page.dart.
// POST JSON: { username, current_password, new_password, confirm_password }
require 'config.php';

$input = json_decode(file_get_contents('php://input'), true);
$username        = trim($input['username'] ?? ($_POST['username'] ?? ''));
$currentPassword = $input['current_password'] ?? ($_POST['current_password'] ?? '');
$newPassword     = $input['new_password'] ?? ($_POST['new_password'] ?? '');
$confirmPassword = $input['confirm_password'] ?? ($_POST['confirm_password'] ?? '');

if ($username === '' || $currentPassword === '' || $newPassword === '') {
    echo json_encode(['success' => false, 'message' => 'Username, current password and new password are required']);
    exit;
}
if (strlen($newPassword) < 6) {
    echo json_encode(['success' => false, 'message' => 'New password must be at least 6 characters']);
    exit;
}
if ($confirmPassword !== '' && $newPassword !== $confirmPassword) {
    echo json_encode(['success' => false, 'message' => 'Passwords do not match']);
    exit;
}

$conn = db_connect();

$stmt = $conn->prepare('SELECT password FROM users WHERE username = ? LIMIT 1');
if (!$stmt) {
    echo json_encode(['success' => false, 'message' => 'Prepare failed: ' . $conn->error]);
    exit;
}
$stmt->bind_param('s', $username);
$stmt->execute();
$result = $stmt->get_result();

if (!$row = $result->fetch_assoc()) {
    echo json_encode(['success' => false, 'message' => 'User not found']);
    $stmt->close();
    $conn->close();
    exit;
}

// Passwords are stored in plain text (same as login.php).
if ($currentPassword !== $row['password']) {
    echo json_encode(['success' => false, 'message' => 'Current password is incorrect']);
    $stmt->close();
    $conn->close();
    exit;
}
$stmt->close();

if ($newPassword === $row['password']) {
    echo json_encode(['success' => false, 'message' => 'New password must be different from the current password']);
    $conn->close();
    exit;
}

$stmt = $conn->prepare('UPDATE users SET password = ? WHERE username = ?');
if (!$stmt) {
    echo json_encode(['success' => false, 'message' => 'Update prepare failed: ' . $conn->error]);
    $conn->close();
    exit;
}
$stmt->bind_param('ss', $newPassword, $username);

if ($stmt->execute()) {
    echo json_encode([
        'success' => true,
        'message' => 'Password changed successfully.',
        'password' => $newPassword,
    ]);
} else {
    echo json_encode(['success' => false, 'message' => 'Failed to change password']);
}

$stmt->close();
$conn->close();
