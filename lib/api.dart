import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class PortalError implements Exception {
  const PortalError(this.status);
  final int status;
}

class PortalUnavailable implements Exception {
  const PortalUnavailable();
}

class PortalApi {
  PortalApi(this.base);
  final Uri base;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  String? token;
  String? role;

  Future<Uint8List> _request(
    String route, {
    String method = 'GET',
    Object? body,
    Uint8List? pdf,
    String? pdfName,
  }) async {
    final HttpClientRequest request;
    try {
      request = await _client.openUrl(method, base.resolve(route));
    } on SocketException {
      throw const PortalUnavailable();
    }
    request.followRedirects = false;
    final session = token;
    if (session != null)
      request.headers.set('Authorization', 'Bearer $session');
    if (pdf != null) {
      final boundary = 'mar-${DateTime.now().microsecondsSinceEpoch}';
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: {'boundary': boundary},
      );
      final rawName = (pdfName ?? 'ficha.pdf').replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final stem = rawName.replaceFirst(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      final filename =
          '${stem.isEmpty ? 'ficha' : stem.substring(0, stem.length > 180 ? 180 : stem.length)}.pdf';
      request.add(
        utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="entrega"\r\nContent-Type: application/json\r\n\r\n${jsonEncode(body)}\r\n',
        ),
      );
      request.add(
        utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="ficha"; filename="$filename"\r\nContent-Type: application/pdf\r\n\r\n',
        ),
      );
      request.add(pdf);
      request.add(utf8.encode('\r\n--$boundary--\r\n'));
    } else if (body != null) {
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
      if ((login['permissoes'] == 'field' || login['permissoes'] == 'ADM') &&
          login['nome'] is String) {
        role = login['permissoes'] as String;
        return login['nome'] as String;
      }
      final user = jsonDecode(utf8.decode(await _request('auth/me'))) as Map;
      if (user['permissoes'] != 'field' && user['permissoes'] != 'ADM')
        throw const PortalError(403);
      role = user['permissoes'] as String;
      return user['nome'] as String;
    } catch (_) {
      token = null;
      role = null;
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
      role = null;
    }
  }

  Future<List<Map<String, dynamic>>> list(String path) async {
    final result =
        jsonDecode(utf8.decode(await _request('portal/$path'))) as List;
    return result.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminList(String resource) async {
    final result =
        jsonDecode(utf8.decode(await _request('admin/$resource'))) as List;
    return result.cast<Map<String, dynamic>>();
  }

  Future<void> adminSave(
    String resource,
    Map<String, dynamic> data, {
    int? id,
    Uint8List? pdf,
    String? pdfName,
  }) async {
    await _request(
      id == null ? 'admin/$resource' : 'admin/$resource/$id',
      method: id == null ? 'POST' : 'PUT',
      body: data,
      pdf: pdf,
      pdfName: pdfName,
    );
  }

  Future<void> adminDeleteNr(int id) async {
    await _request('admin/nrs/$id', method: 'DELETE');
  }

  Future<void> definePassword(int id, String password) async {
    await _request(
      'admin/funcionarios/$id/senha',
      method: 'POST',
      body: {'senha': password},
    );
  }

  Future<List<Map<String, dynamic>>> availableEpis() async {
    final result = jsonDecode(
      utf8.decode(await _request('admin/epis/disponiveis')),
    ) as List;
    return result.cast<Map<String, dynamic>>();
  }

  Future<void> epiOperation(
    int id,
    String operation,
    Map<String, dynamic> data,
  ) async {
    await _request('admin/epis/$id/$operation', method: 'POST', body: data);
  }

  Future<void> adminPresence(
    int turmaId,
    int funcionarioId,
    bool presente,
  ) async {
    await _request(
      'admin/turmas/$turmaId/participantes/$funcionarioId',
      method: 'PATCH',
      body: {'presente': presente},
    );
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
