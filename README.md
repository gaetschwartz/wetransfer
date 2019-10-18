# WeTransfer for Flutter

A Flutter package that allows upload and dowload files to Wetransfer.

## How to create a new instance

 Create a new instance with :

 ```dart
 WeTransferClient client = await WeTransferClient.create('<api_key>');
 ```

 ## Example

 ```dart
    WeTransferClient client = await WeTransferClient.create('<api_key>');
    
    print("Creating transfer");

    Transfer transfer = await client.createTransfer(
        myFiles.toList(), "Test transfer yayyy");

    print("Transfer with id ${transfer.id} created");
    print("Uploading ${transfer.files.length} files");

    await client.uploadFiles(transfer).forEach((state) =>
        print('${state.file.name} : ${state.sent}/${state.file.size} bytes'));

    print('Uploaded all files');
    print("Completing file uploads");
  
    await client.completeFilesUpload(transfer).forEach((state) => print(
        '${state.done ? 'Completed' : 'Started completing'} ${state.file.name} upload'));

    print('Completed all uploads');
    print("Finalizing transfer");

    String url = await client.finalizeTransfer(transfer);
 ```
