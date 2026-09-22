import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:http/http.dart' as http;

/// Central HTTP client for every call to the PHP API.
///
/// Why it exists: shared hosting providers (e.g. InfinityFree) put every
/// non-browser client through a JavaScript "browser security check". The
/// check is solvable without a browser, though: the challenge page contains
/// an AES-128-CBC puzzle (key, IV, ciphertext) whose decrypted bytes are
/// exactly the value of the `__test` cookie a browser would set. This
/// client does what the browser does:
///
/// 1. Sends browser-like headers on every request.
/// 2. When it receives the challenge HTML, parses the key/IV/ciphertext,
///    decrypts them, caches the `__test` cookie, and retries the original
///    request — transparently.
/// 3. Every later request reuses the cached cookie, so the challenge is
///    solved at most once per app session.
/// 4. Detects leftover HTML responses and throws a friendly
///    [ApiChallengeException] instead of a raw `FormatException`.
///
/// Use [post] / [sendMultipart] instead of `http.post` / `request.send()`,
/// and [decodeJson] instead of a bare `jsonDecode(response.body)`.
class ApiClient {
  ApiClient._();

  static final BrowserHeaderClient _client = BrowserHeaderClient();

  /// The solved security-check cookie (`__test=<hex>`), cached for the
  /// whole app session once it has been computed.
  static String? _testCookie;

  /// POST with browser-like headers and automatic challenge solving.
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    http.Response response = await _client.post(
      url,
      headers: _withCookie(headers),
      body: body,
    );

    // Security-check page? Solve it, cache the cookie, retry once.
    if (_isChallenge(response.body)) {
      final String? cookie = await _solveChallenge(response.body);
      if (cookie != null) {
        _testCookie = cookie;
        response = await _client.post(
          url,
          headers: _withCookie(headers),
          body: body,
        );
      }
    }

    return response;
  }

  /// Sends a multipart request (file upload) with browser-like headers and
  /// challenge handling. The multipart Content-Type (with its boundary) set
  /// by the request itself is preserved.
  ///
  /// A MultipartRequest can only be sent once (its body stream is consumed
  /// by finalize), so the security-check cookie is primed with a small JSON
  /// call *before* the upload whenever it is not cached yet. That way the
  /// upload itself passes the check on its first and only send.
  static Future<http.Response> sendMultipart(http.MultipartRequest request) async {
    if (_testCookie == null) {
      await post(request.url, body: '');
    }

    if (_testCookie != null) {
      final hasCookie = request.headers.keys
          .any((existing) => existing.toLowerCase() == 'cookie');
      if (!hasCookie) request.headers['Cookie'] = _testCookie!;
    }

    final response =
        await http.Response.fromStream(await _client.send(request));

    // Should not happen thanks to priming, but if the check still fires we
    // at least solve it for the next attempt instead of failing forever.
    if (_isChallenge(response.body)) {
      final String? cookie = await _solveChallenge(response.body);
      if (cookie != null) _testCookie = cookie;
      throw ApiChallengeException(
        'The upload was stopped by the server security check. '
        'Please try again.',
      );
    }

    return response;
  }

  /// Merges the caller's headers with the cached security-check cookie.
  static Map<String, String> _withCookie(Map<String, String>? headers) {
    final merged = <String, String>{...?headers};
    if (_testCookie != null &&
        !merged.keys.any((k) => k.toLowerCase() == 'cookie')) {
      merged['Cookie'] = _testCookie!;
    }
    return merged;
  }

  /// True when the body is the hosting provider's browser security-check
  /// page instead of the JSON we asked for.
  static bool _isChallenge(String body) {
    return body.trimLeft().startsWith('<') &&
        (body.contains('/aes.js') || body.contains('toNumbers'));
  }

  /// Solves the challenge: parses the AES puzzle from the HTML and computes
  /// the `__test` cookie value (`__test=<hex>`), or null when the page
  /// could not be parsed.
  static Future<String?> _solveChallenge(String html) async {
    try {
      final matches = RegExp(r'toNumbers\("([0-9a-fA-F]+)"\)')
          .allMatches(html)
          .map((m) => m.group(1)!)
          .toList();
      if (matches.length < 3) return null;

      final key = _hexToBytes(matches[0]);
      final iv = _hexToBytes(matches[1]);
      final cipherText = _hexToBytes(matches[2]);

      // The challenge's slowAES.decrypt(c, 2, a, b) is AES-128-CBC without
      // padding; the raw decrypted bytes are the cookie value.
      final plain = enc.Encrypter(
        enc.AES(
          enc.Key(key),
          mode: enc.AESMode.cbc,
          padding: null,
        ),
      ).decryptBytes(
        enc.Encrypted(cipherText),
        iv: enc.IV(iv),
      );

      return '__test=${plain.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    } catch (_) {
      return null;
    }
  }

  /// Converts a hex string like "f655ba9d..." into its raw bytes
  /// (the Dart equivalent of PHP's hex2bin / JS toNumbers).
  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  /// Decodes a JSON API response and turns HTML responses into a friendly
  /// exception instead of a raw FormatException.
  static Map<String, dynamic> decodeJson(http.Response response) {
    final body = response.body.trimLeft();

    if (body.startsWith('<')) {
      if (body.contains('/aes.js') || body.contains('__test')) {
        throw ApiChallengeException();
      }
      throw ApiChallengeException(
        'The server returned an HTML error page instead of JSON '
        '(HTTP ${response.statusCode}).',
      );
    }

    return jsonDecode(body) as Map<String, dynamic>;
  }
}

/// Thrown when the server answers with its browser security-check page
/// (or any HTML page) instead of the expected JSON.
class ApiChallengeException implements Exception {
  ApiChallengeException([this.message]);

  final String? message;

  @override
  String toString() =>
      message ??
      'The hosting server requires a browser security check, so the app '
      'cannot talk to it directly. Use a host that allows API calls.';
}

/// An http.Client that adds browser-like headers to every request.
///
/// Headers a request already set (like the multipart Content-Type) are
/// never overridden.
class BrowserHeaderClient extends http.BaseClient {
  BrowserHeaderClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;

  /// Headers that make the request look like it comes from a mobile browser.
  static const Map<String, String> browserHeaders = {
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,'
        'image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Upgrade-Insecure-Requests': '1',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    browserHeaders.forEach((name, value) {
      // Do not override anything the caller set explicitly (multipart
      // requests manage their own Content-Type).
      final isSet = request.headers.keys
          .any((existing) => existing.toLowerCase() == name.toLowerCase());
      if (!isSet) {
        request.headers[name] = value;
      }
    });
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
