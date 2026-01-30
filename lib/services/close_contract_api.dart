import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

String _apiHost() {
  return kIsWeb
      ? 'http://localhost:5000'
      : (defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:5000' : 'http://localhost:5000');
}

class CloseContractApi {
  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${_apiHost()}$path').replace(queryParameters: query);
  }

  static Future<List<Map<String, dynamic>>> listRequests({String? role, String? createdByEmail, bool includeActions = false}) async {
    final query = <String, String>{};
    if (role != null && role.isNotEmpty) query['role'] = role;
    if (createdByEmail != null && createdByEmail.isNotEmpty) query['created_by_email'] = createdByEmail;
    if (includeActions) query['include_actions'] = '1';
    final resp = await http.get(_uri('/api/close-contracts', query));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load requests: ${resp.body}');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return items;
  }

  static Future<Map<String, dynamic>> getRequest(int id) async {
    final resp = await http.get(_uri('/api/close-contracts/$id'));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load request: ${resp.body}');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    return (data['item'] as Map<String, dynamic>?) ?? {};
  }

  static Future<Map<String, dynamic>> createRequest({required Map<String, dynamic> payload, PlatformFile? attachment}) async {
    http.BaseRequest request;
    if (attachment != null) {
      final req = http.MultipartRequest('POST', _uri('/api/close-contracts'));
      req.fields.addAll(payload.map((key, value) => MapEntry(key, value?.toString() ?? '')));
      if (attachment.bytes != null) {
        req.files.add(http.MultipartFile.fromBytes('attachment', attachment.bytes!, filename: attachment.name));
      } else if (attachment.path != null) {
        req.files.add(await http.MultipartFile.fromPath('attachment', attachment.path!, filename: attachment.name));
      }
      request = req;
    } else {
      request = http.Request('POST', _uri('/api/close-contracts'))
        ..headers['Content-Type'] = 'application/json'
        ..body = json.encode(payload);
    }

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 201) {
      throw Exception('Create failed: ${resp.body}');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    return (data['item'] as Map<String, dynamic>?) ?? {};
  }

  static Future<Map<String, dynamic>> actOnRequest(int id, {required String result, String? comment, String? actorEmail, int? actorId, String? actorName, String? actorRole}) async {
    final body = {
      'result': result,
      if (comment != null) 'comment': comment,
      if (actorEmail != null) 'actor_email': actorEmail,
      if (actorId != null) 'actor_id': actorId,
      if (actorName != null) 'actor_name': actorName,
      if (actorRole != null) 'actor_role': actorRole,
    };
    final resp = await http.post(_uri('/api/close-contracts/$id/action'), headers: {'Content-Type': 'application/json'}, body: json.encode(body));
    if (resp.statusCode != 200) {
      throw Exception('Action failed: ${resp.body}');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    return (data['item'] as Map<String, dynamic>?) ?? {};
  }
}
