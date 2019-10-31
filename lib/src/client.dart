part of wetransfer;

/// Main entry point of the library.
///
/// Create a new instance with :
///
/// ```dart
/// WeTransferClient client = await WeTransferClient.create('<api_key>');
/// ```
/// Check in the README file for a more in-depth explanation
///

class WeTransferException implements Exception {
  final String cause;
  WeTransferException(this.cause);

  @override
  String toString() {
    return "WeTransferException : $cause";
  }
}

class WeTransferClient {
  final http.Client client = http.Client();
  final Credentials credentials;
  final JsonDecoder decoder = JsonDecoder();
  final JsonEncoder encoder = JsonEncoder();
  final Map<String, String> _auth;
  static const Map<String, RemoteState> _stringToState = {
    'uploading': RemoteState.uploading,
    'downloadable': RemoteState.downloadable,
    'processing': RemoteState.processing,
    "unknown": RemoteState.unknown
  };

  WeTransferClient({this.credentials})
      : assert(credentials != null),
        _auth = {
          "x-api-key": credentials.apiKey,
          "Authorization": "Bearer ${credentials.userToken}",
          "Content-Type": "application/json"
        };

  /// Creates an instance of [WeTransferClient].
  /// Internally registers the device as a user and stores a user token

  static Future<WeTransferClient> create(String apiKey) async {
    var request = http.Request(
        "POST", Uri.parse("https://dev.wetransfer.com/v2/authorize"));

    request.headers
        .addAll({"x-api-key": apiKey, "Content-Type": "application/json"});

    // generate uuid
    String uuid;
    try {
      uuid = await UniqueIds.uuid;
    } on WeTransferException {
      throw WeTransferException("Failed to create a UUID for this device !");
    }

    request.body = JsonEncoder().convert({'user_indentifier': uuid});
    var resp = await request.send();
    String respString = await resp.stream.bytesToString();
    Map<String, dynamic> respBody = JsonDecoder().convert(respString);

    if (!(respBody['success'] ?? false))
      throw WeTransferException(
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

    request.headers.addAll(_auth);

    List<Map<String, dynamic>> filesField = await Stream.fromIterable(files)
        .asyncMap(
            (f) async => {'name': basename(f.path), 'size': await f.length()})
        .toList();
    request.body = encoder.convert({'message': message, 'files': filesField});
    var resp = await client.send(request);
    String respString = await resp.stream.bytesToString();
    Map<String, dynamic> respBody = decoder.convert(respString);

    if (!(respBody['success'] ?? false))
      throw WeTransferException(
          "Error while creating the transfer : ${resp.statusCode} ${respBody['message']}");

    return Transfer(
      id: respBody['id'],
      files: (respBody['files'] as List)
          .map((m) => LocalWeTransferFile.fromJSON(
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
    request.headers.addAll(_auth);

    var resp = await client.send(request);
    String respString = await resp.stream.bytesToString();
    Map<String, dynamic> respBody = decoder.convert(respString);

    if (!(respBody['success'] ?? false))
      throw WeTransferException(
          "Error while requesting '${file.name}' upload url : ${respBody['message']}");

    return respBody['url'];
  }

  /// Uploads all files of the provided [Transfer]
  Stream<FileTransferState> uploadFiles(
    Transfer transfer,
  ) async* {
    for (var f in transfer.files) {
      yield FileUploadState(f, 0, false);
      yield* uploadFile(transfer.id, f);
    }
  }

  /// Uploads a single file
  Stream<FileTransferState> uploadFile(
      String transferId, LocalWeTransferFile file) async* {
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

        throw WeTransferException(
            "Error while uploading '${file.name}' upload : ${doc.children}");
      }

      yield FileUploadState(file, end, i + 1 == file.partNumbers);
    }
    yield* completeFileUpload(transferId, file);
    _client.close();
  }

  /// Informs the server that all the uploads of this transfer are done.
  Stream<CompleteFileUploadState> completeFileUpload(
      String transferId, WeTransferFile file) async* {
    yield CompleteFileUploadState(file, false);
    var request = http.Request(
        "PUT",
        Uri.parse(
            "https://dev.wetransfer.com/v2/transfers/$transferId/files/${file.id}/upload-complete"));

    request.headers.addAll(_auth);

    request.body = encoder.convert({'part_numbers': file.partNumbers});
    var resp = await client.send(request);
    String respString = await resp.stream.bytesToString();

    Map<String, dynamic> respBody = decoder.convert(respString);

    if (!(respBody['success'] ?? false)) {
      throw WeTransferException(
          "Error while completing '${file.name}' upload : ${respBody['message']}");
    }
    yield CompleteFileUploadState(file, true);
  }

  /// Closes the transfer for modification, and makes it available for download.
  Future<String> finalizeTransfer(Transfer transfer) async {
    var request = http.Request(
        "PUT",
        Uri.parse(
            "https://dev.wetransfer.com/v2/transfers/${transfer.id}/finalize"));

    request.headers.addAll(_auth);

    var resp = await client.send(request);
    String respString = await resp.stream.bytesToString();
    Map<String, dynamic> respBody = decoder.convert(respString);
    return respBody['url'];
  }

  /// Gets the download url of a transfer
  Future<Transfer> getTransferInfo(String transferId) async {
    var request = http.Request("GET",
        Uri.parse("https://dev.wetransfer.com/v2/transfers/$transferId"));

    request.headers.addAll(_auth);
    request.headers.remove("Content-Type");

    var resp = await client.send(request);
    String respString = await resp.stream.bytesToString();
    Map<String, dynamic> respBody = decoder.convert(respString);
    String url = respBody['url'];
    if (url == null)
      throw WeTransferException(
          "Couldn't retrieve transfer infos $transferId !");
    List<WeTransferFile> files = respBody['files']
        .map<WeTransferFile>((f) => RemoteWeTransferFile.fromJSON(f))
        .toList();
    return Transfer(
        id: transferId,
        message: respBody['message'],
        url: respBody['url'],
        state: _stringToState[respBody['state'] ?? "uknown"],
        expiresAt: DateTime.parse(respBody['expires_at']),
        files: files);
  }

  /// Closes the client and cleans up any resources associated with it.
  /// It's important to close each client when it's done being used;
  /// failing to do so can cause the Dart process to hang.
  ///
  /// *Copied from package:http/src/client.dart*
  void close() => client?.close();
}
