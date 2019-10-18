# WeTransfer for Flutter

A Flutter package that allows upload and dowload files to Wetransfer.

## How to create a new instance

 Create a new instance with :

 ```dart
 WeTransferClient client = await WeTransferClient.create('<api_key>');
 ```

 ## Example

 ```dart
 Map<String, String> files = await FilePicker.getMultiFilePath();

 Transfer transfer = await client.createTransfer(
     files.values.map<File>((f) => File(f)).toList(), "Test transfer yayyy");

 print("Transfer with id ${transfer.id} created");
 print("Uploading ${transfer.files.length} files");

 await client
     .uploadFiles(transfer)
     .forEach((state) => print('${state.file.name} : ${state.sent}'));

 print('Uploaded all files');
 print("Completing file uploads");

   await client
       .completeFilesUpload(transfer)
       .forEach((state) => print('${state.file.name} : ${state.sent}'));

 String url = await client.finalizeTransfer(transfer);

 ```
