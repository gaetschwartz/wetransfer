part of wetransfer;

/// Characterizes a WeTransfer file
///
/// *You shouldn't need to use this class.*
class LocalWeTransferFile extends WeTransferFile {
  final File file;

  LocalWeTransferFile(
      {this.file,
      String name,
      int size,
      String id,
      String type,
      int partNumbers,
      int chunkSize})
      : super(
            name: name,
            size: size,
            id: id,
            type: type,
            partNumbers: partNumbers,
            chunkSize: chunkSize);

  LocalWeTransferFile.fromJSON(Map<String, dynamic> map, this.file)
      : super.fromJSON(map);
}

class RemoteWeTransferFile extends WeTransferFile {
  RemoteWeTransferFile(
      {String name,
      int size,
      String id,
      String type,
      int partNumbers,
      int chunkSize})
      : super(
            name: name,
            size: size,
            id: id,
            type: type,
            partNumbers: partNumbers,
            chunkSize: chunkSize);

  RemoteWeTransferFile.fromJSON(Map<String, dynamic> map) : super.fromJSON(map);
}

abstract class WeTransferFile {
  final String name;
  final int size;
  final String id;
  final String type;
  final int partNumbers;
  final int chunkSize;

  WeTransferFile(
      {this.name,
      this.size,
      this.id,
      this.type,
      this.partNumbers,
      this.chunkSize});

  WeTransferFile.fromJSON(
    Map<String, dynamic> map,
  )   : id = map['id'],
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

  Credentials({this.apiKey, this.userToken})
      : assert(apiKey != null),
        assert(userToken != null);
}

/// Characterizes a WeTransfer transfer

class Transfer {
  final String message;
  final String id;
  final List<WeTransferFile> files;
  final RemoteState state;
  final String url;
  final DateTime expiresAt;

  Transfer(
      {this.files, this.expiresAt, this.id, this.message, this.state, this.url})
      : assert(id != null),
        assert(files != null);
}

enum RemoteState { uploading, processing, downloadable, unknown }
