part of wetransfer;

enum TransferType { completeUpload, fileUpload, unknown }

abstract class TransferState {
  final TransferType type;
  final bool done;

  TransferState(
    this.done,
    this.type,
  );
}

abstract class FileTransferState extends TransferState {
  final WeTransferFile file;

  FileTransferState(this.file, bool done, TransferType type)
      : super(done, type);
}

class CompleteFileUploadState extends FileTransferState {
  CompleteFileUploadState(WeTransferFile file, bool done)
      : super(file, done, TransferType.completeUpload);
}

class FileUploadState extends FileTransferState {
  final int sent;

  FileUploadState(WeTransferFile file, this.sent, bool done)
      : super(file, done, TransferType.fileUpload);
}
