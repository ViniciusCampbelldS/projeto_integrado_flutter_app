import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class PortalError implements Exception {
  const PortalError(this.status);
  final int status;
}

class PortalApi {
  PortalApi(this.base);
  final Uri base;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  String? token;

  Future<Uint8List> _request(
    String route, {
    String method = 'GET',
    Object? body,
  }) async {
    final request = await _client.openUrl(method, base.resolve(route));
    request.followRedirects = false;
    final session = token;
    if (session != null)
      request.headers.set('Authorization', 'Bearer $session');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(
      const Duration(seconds: 80),
      onTimeout: () {
        request.abort();
        throw const PortalError(504);
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw PortalError(response.statusCode);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 35))) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  Future<String> login(String cpf, String senha) async {
    try {
      final login = jsonDecode(
        utf8.decode(
          await _request(
            'auth/login',
            method: 'POST',
            body: {'cpf': cpf, 'senha': senha},
          ),
        ),
      ) as Map;
      token = login['access_token'] as String;
      final user = jsonDecode(utf8.decode(await _request('auth/me'))) as Map;
      if (user['permissoes'] != 'field') throw const PortalError(403);
      return user['nome'] as String;
    } catch (_) {
      token = null;
      rethrow;
    }
  }

  Future<String> recoverPassword(String email) async {
    final response = await _request(
      'auth/recuperar-senha',
      method: 'POST',
      body: {'email': email},
    );
    return (jsonDecode(utf8.decode(response)) as Map)['mensagem'] as String;
  }

  Future<void> logout() async {
    try {
      await _request('auth/logout', method: 'POST');
    } finally {
      token = null;
    }
  }

  Future<List<Map<String, dynamic>>> list(String path) async {
    final result =
        jsonDecode(utf8.decode(await _request('portal/$path'))) as List;
    return result.cast<Map<String, dynamic>>();
  }

  Future<Uint8List> ficha(int id) => _request('portal/fichas-epi/$id');

  Future<void> relato(int id, String situacao, String comentario) async {
    await _request(
      'portal/relatos',
      method: 'POST',
      body: {'epiId': id, 'situacao': situacao, 'comentario': comentario},
    );
  }
}
