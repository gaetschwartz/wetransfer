library wetransfer;

import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart' as xml;
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'package:unique_ids/unique_ids.dart';
import 'package:flutter/services.dart';
import 'dart:math';

@immutable
@visibleForOverriding
class FileTransferState {
  final WeTransferFile file;

  FileTransferState(this.file);
}

@immutable
class FileUploadCompleteState extends FileTransferState {
  final bool done;

  FileUploadCompleteState(WeTransferFile file, this.done) : super(file);
}

@immutable
class FileUploadState extends FileTransferState {
  final int sent;

  FileUploadState(WeTransferFile file, this.sent) : super(file);
}

/// Characterizes a WeTransfer file
///
/// *You shouldn't need to use this class.*
class WeTransferFile {
  final String name;
  final int size;
  final String id;
  final String type;
  final int partNumbers;
  final int chunkSize;
  final File file;

  WeTransferFile(
      {this.name,
      this.size,
      this.id,
      this.type,
      this.partNumbers,
      this.file,
      this.chunkSize});

  WeTransferFile.fromJSON(Map<String, dynamic> map, this.file)
      : id = map['id'],
        size = map['size'],
        name = map['name'],
        type = map['type'] ?? 'file',
        chunkSize = map['multipart']['chunk_size'],
        partNumbers = map['multipart']['part_numbers'];
}

/// Characterizes WeTransfer credentials.
///
/// *You shouldn't need to use this class.*
class Credentials {
  final String apiKey;
  final String userToken;

  Credentials({@required this.apiKey, @required this.userToken})
      : assert(apiKey != null),
        assert(userToken != null);
}

/// Characterizes a WeTransfer transfer
@immutable
class Transfer {
  final String message;
  final String id;
  final List<WeTransferFile> files;

  Transfer({this.id, this.message, this.files});
}

/// Main entry point of the library.
///
/// Create a new instance with :
///
/// ```dart
/// WeTransferClient client = await WeTransferClient.create('<api_key>');
/// ```
/// Check in the README file for a more in-depth explanation
class WeTransferClient {
  final http.Client client = http.Client();
  final Credentials credentials;
  final JsonDecoder decoder = JsonDecoder();
  final JsonEncoder encoder = JsonEncoder();
  final Map<String, String> auth;

  WeTransferClient({@required this.credentials})
      : auth = {
          "x-api-key": credentials.apiKey,
          "Authorization": "Bearer ${credentials.userToken}",
          "Content-Type": "application/json"
        };

  /// Creates an instance of [WeTransferClient].
  /// Internally registers the device as a user and stores a user token
  @factory
  static Future<WeTransferClient> create(String apiKey) async {
    var request = http.Request(
        "POST", Uri.parse("https://dev.wetransfer.com/v2/authorize"));

    request.headers
        .addAll({"x-api-key": apiKey, "Content-Type": "application/json"});

    // generate uuid
    String uuid;
    try {
      uuid = await UniqueIds.uuid;
    } on PlatformException {
      throw Exception("Failed to create a UUID for this device !");
    }

    request.body = JsonEncoder().convert({'user_indentifier': uuid});
    var resp = await request.send();
    String respString = await resp.stream.bytesToString();
    Map<String, dynamic> respBody = JsonDecoder().convert(respString);

    if (!(respBody['success'] ?? false))
      throw Exception(
          "Error while authorizing user '$uuid' : ${respBody['message']}");

    String userToken = respBody['token'];
    return WeTransferClient(
        credentials: Credentials(apiKey: apiKey, userToken: userToken));
  }

  /// Creates a new [Transfer] from a list of files to upload.
  /// [message] is the message the user who downloads the files will see.
  Future<Transfer> createTransfer(
    List<File> files, [
    String message = "Sample WeTransfer transfer ;)",
  ]) async {
    var request = http.Request(
        "POST", Uri.parse("https://dev.wetransfer.com/v2/transfers"));

    request.headers.addAll(auth);

    List<Map<String, dynamic>> filesField = await Stream.fromIterable(files)
        .asyncMap(
            (f) async => {'name': basename(f.path), 'size': await f.length()})
        .toList();
    request.body = encoder.convert({'message': message, 'files': filesField});
    var resp = await client.send(request);
    String respString = await resp.stream.bytesToString();
    Map<String, dynamic> respBody = decoder.convert(respString);

    if (!(respBody['success'] ?? false))
      throw Exception(
          "Error while creating the transfer : ${resp.statusCode} ${respBody['message']}");

    return Transfer(
      id: respBody['id'],
      files: (respBody['files'] as List)
          .map((m) => WeTransferFile.fromJSON(
              m, files.firstWhere((f) => m['name'] == basename(f.path))))
          .toList(),
      message: respBody['message'],
    );
  }

  /// Gets the designated server url for a specific file part
  ///
  /// *You shouldn't need to use this method.*
  Future<String> requestUploadURL(
      String transferId, WeTransferFile file, int part) async {
    var request = http.Request(
        "GET",
        Uri.parse(
            "https://dev.wetransfer.com/v2/transfers/$transferId/files/${file.id}/upload-url/$part"));
    request.headers.addAll(auth);

    var resp = await client.send(request);
    String respString = await resp.stream.bytesToString();
    Map<String, dynamic> respBody = decoder.convert(respString);

    if (!(respBody['success'] ?? false))
      throw Exception(
          "Error while requesting '${file.name}' upload url : ${respBody['message']}");

    return respBody['url'];
  }

  /// Uploads all files of the provided [Transfer]
  Stream<FileUploadState> uploadFiles(
    Transfer transfer,
  ) async* {
    for (var f in transfer.files) {
      yield FileUploadState(
        f,
        0,
      );
      yield* uploadFile(f, transfer.id);
    }
  }

  /// Uploads a single file
  Stream<FileUploadState> uploadFile(
      WeTransferFile file, String transferId) async* {
    http.Client _client = http.Client();
    final openedFile = await file.file.open();
    for (var i = 0; i < file.partNumbers; i++) {
      String url = await requestUploadURL(transferId, file, i + 1);

      int start = i * file.chunkSize;
      int end = min(start + file.chunkSize, file.size);

      final req = http.Request("PUT", Uri.parse(url));

      // Don't use the client as it's not the wetransfer server

      await openedFile.setPosition(start);
      req.bodyBytes = await openedFile.read(end - start);

      http.StreamedResponse resp;

      resp = await _client.send(req);

      //Waits for the response
      String respString = await resp.stream.bytesToString();

      if (resp.statusCode != 200) {
        xml.XmlDocument doc = xml.parse(respString);

        throw Exception(
            "Error while uploading '${file.name}' upload : ${doc.children}");
      }

      yield FileUploadState(
        file,
        end,
      );
    }
    _client.close();
  }

  /// Informs the server that all the uploads of this transfer are done.
  Stream<FileUploadCompleteState> completeFilesUpload(
    Transfer transfer,
  ) async* {
    if (transfer.files?.isEmpty ?? true)
      throw Exception("No files to complete !");
    for (var f in transfer.files) {
      yield FileUploadCompleteState(f, false);
      var request = http.Request(
          "PUT",
          Uri.parse(
              "https://dev.wetransfer.com/v2/transfers/${transfer.id}/files/${f.id}/upload-complete"));

      request.headers.addAll(auth);

      request.body = encoder.convert({'part_numbers': f.partNumbers});
      var resp = await client.send(request);
      String respString = await resp.stream.bytesToString();

      Map<String, dynamic> respBody = decoder.convert(respString);

      if (!(respBody['success'] ?? false)) {
        throw Exception(
            "Error while completing '${f.name}' upload : ${respBody['message']}");
      }
      yield FileUploadCompleteState(f, true);
    }
  }

  /// Closes the transfer for modification, and makes it available for download.
  Future<String> finalizeTransfer(Transfer transfer) async {
    var request = http.Request(
        "PUT",
        Uri.parse(
            "https://dev.wetransfer.com/v2/transfers/${transfer.id}/finalize"));

    request.headers.addAll(auth);

    var resp = await client.send(request);
    String respString = await resp.stream.bytesToString();
    Map<String, dynamic> respBody = decoder.convert(respString);
    return respBody['url'];
  }

  /// Gets the download url of a transfer
  Future<String> getTransferInfo(Transfer transfer) async {
    var request = http.Request("PUT",
        Uri.parse("https://dev.wetransfer.com/v2/transfers/${transfer.id}"));

    request.headers.addAll(auth);

    var resp = await client.send(request);
    String respString = await resp.stream.bytesToString();
    Map<String, dynamic> respBody = decoder.convert(respString);
    String url = respBody['url'];
    if (url == null)
      throw Exception("Couldn't retrieve transfer infos ${transfer.id} !");
    return url;
  }

  /// Closes the client and cleans up any resources associated with it.
  /// It's important to close each client when it's done being used;
  /// failing to do so can cause the Dart process to hang.
  ///
  /// *Copied from package:http/src/client.dart*
  void close() => client.close();
}
