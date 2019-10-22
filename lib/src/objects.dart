part of wetransfer;

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

  Credentials({this.apiKey, this.userToken})
      : assert(apiKey != null),
        assert(userToken != null);
}

/// Characterizes a WeTransfer transfer

class Transfer {
  final String message;
  final String id;
  final List<WeTransferFile> files;

  Transfer({
    this.files,
    this.id,
    this.message,
  })  : assert(id != null),
        assert(files != null);
}
