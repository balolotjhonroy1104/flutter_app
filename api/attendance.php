<?php
// Attendance endpoint used by lib/views/pages/time_page.dart.
// POST JSON: { action: 'status',   username }                        -> current open session + recent history
// POST JSON: { action: 'time_in',  username, latitude?, longitude? } -> starts a new session (rejected if already timed in)
// POST JSON: { action: 'time_out', username }                        -> closes the open session
require 'config.php';

$input = json_decode(file_get_contents('php://input'), true);
$action = trim($input['action'] ?? '');
$username = trim($input['username'] ?? '');

if ($username === '') {
    echo json_encode(['success' => false, 'message' => 'Username is required']);
    exit;
}

$conn = db_connect();

// Makes sure the attendance table and its location columns exist, so the
// app works even if the statements in api/setup.sql were not run yet.
//
// Fast path: one tiny SELECT verifies the table AND its columns in a single
// query; the CREATE/ALTER DDL only runs when something is actually missing
// (important on free hosts, where per-request DDL invites gateway timeouts).
function ensure_attendance_table(mysqli $conn): void {
    $probe = @$conn->query('SELECT id, time_in_lat, time_in_lng FROM attendance LIMIT 1');
    if ($probe !== false) {
        $probe->free();
        return; // Table and columns are all present.
    }

    $conn->query(
        'CREATE TABLE IF NOT EXISTS attendance (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(50) NOT NULL,
            time_in DATETIME NOT NULL,
            time_out DATETIME DEFAULT NULL,
            time_in_lat DOUBLE DEFAULT NULL,
            time_in_lng DOUBLE DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_attendance_username (username)
        )'
    );

    // Older installs may be missing the location columns. MariaDB (XAMPP)
    // supports ADD COLUMN IF NOT EXISTS; other MySQL builds throw, which we
    // ignore because the columns would already exist in that case.
    try {
        $conn->query(
            'ALTER TABLE attendance
                ADD COLUMN IF NOT EXISTS time_in_lat DOUBLE DEFAULT NULL AFTER time_out,
                ADD COLUMN IF NOT EXISTS time_in_lng DOUBLE DEFAULT NULL AFTER time_in_lat'
        );
    } catch (mysqli_sql_exception $e) {
        // Columns already exist (or MySQL build without IF NOT EXISTS support).
    }
}

ensure_attendance_table($conn);

// Returns the session the user is currently clocked into, if any.
function find_open_session(mysqli $conn, string $username): ?array {
    $stmt = $conn->prepare(
        'SELECT id, time_in, time_in_lat, time_in_lng FROM attendance
         WHERE username = ? AND time_out IS NULL
         ORDER BY time_in DESC LIMIT 1'
    );
    if (!$stmt) {
        return null;
    }
    $stmt->bind_param('s', $username);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

if ($action === 'time_in') {
    if (find_open_session($conn, $username)) {
        echo json_encode([
            'success' => false,
            'message' => 'You are already timed in. Please time out first.',
        ]);
        $conn->close();
        exit;
    }

    // Location at punch time (optional; used to pin the time in on the map).
    $latitude = isset($input['latitude']) && is_numeric($input['latitude'])
        ? (float) $input['latitude']
        : null;
    $longitude = isset($input['longitude']) && is_numeric($input['longitude'])
        ? (float) $input['longitude']
        : null;

    $stmt = $conn->prepare(
        'INSERT INTO attendance (username, time_in, time_in_lat, time_in_lng)
         VALUES (?, NOW(), ?, ?)'
    );
    if (!$stmt) {
        echo json_encode(['success' => false, 'message' => 'Prepare failed: ' . $conn->error]);
        $conn->close();
        exit;
    }
    // 'ssdd': username, time_in (NOW() is SQL-side), latitude, longitude.
    $stmt->bind_param('sdd', $username, $latitude, $longitude);

    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'message' => 'Timed in successfully.',
        ]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to save time in']);
    }
    $stmt->close();
    $conn->close();
    exit;
}

if ($action === 'time_out') {
    $open = find_open_session($conn, $username);
    if (!$open) {
        echo json_encode([
            'success' => false,
            'message' => 'You are not timed in yet.',
        ]);
        $conn->close();
        exit;
    }

    $stmt = $conn->prepare('UPDATE attendance SET time_out = NOW() WHERE id = ?');
    if (!$stmt) {
        echo json_encode(['success' => false, 'message' => 'Prepare failed: ' . $conn->error]);
        $conn->close();
        exit;
    }
    $stmt->bind_param('i', $open['id']);

    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'message' => 'Timed out successfully.',
        ]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to save time out']);
    }
    $stmt->close();
    $conn->close();
    exit;
}

if ($action === 'status') {
    $stmt = $conn->prepare(
        'SELECT id, time_in, time_out, time_in_lat, time_in_lng FROM attendance
         WHERE username = ? ORDER BY time_in DESC LIMIT 10'
    );
    if (!$stmt) {
        echo json_encode(['success' => false, 'message' => 'Prepare failed: ' . $conn->error]);
        $conn->close();
        exit;
    }
    $stmt->bind_param('s', $username);
    $stmt->execute();
    $result = $stmt->get_result();

    $records = [];
    while ($row = $result->fetch_assoc()) {
        $records[] = [
            'id' => (int) $row['id'],
            'time_in' => $row['time_in'],
            'time_out' => $row['time_out'],
            'time_in_lat' => $row['time_in_lat'] !== null ? (float) $row['time_in_lat'] : null,
            'time_in_lng' => $row['time_in_lng'] !== null ? (float) $row['time_in_lng'] : null,
        ];
    }

    // Look up the open session before closing the connection.
    $open = find_open_session($conn, $username);

    $stmt->close();
    $conn->close();

    echo json_encode([
        'success' => true,
        'message' => 'Attendance status loaded',
        'is_timed_in' => $open !== null,
        'current_time_in' => $open['time_in'] ?? null,
        'current_time_in_lat' => isset($open['time_in_lat']) && $open['time_in_lat'] !== null
            ? (float) $open['time_in_lat']
            : null,
        'current_time_in_lng' => isset($open['time_in_lng']) && $open['time_in_lng'] !== null
            ? (float) $open['time_in_lng']
            : null,
        'records' => $records,
    ]);
    exit;
}

// Unknown action.
echo json_encode(['success' => false, 'message' => 'Unknown action']);
$conn->close();
