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
        myFiles.toList(), "Test transfer.");

    print("Transfer with id ${transfer.id} created");
    print("Uploading ${transfer.files.length} files");

    await client.uploadFiles(transfer).forEach((state) =>
        print('${state.file.name} : ${state.type}'));

    print('Uploaded all files');

    print("Finalizing transfer");

    String url = await client.finalizeTransfer(transfer);

    //Dont forget to close the client when you don't need it anymore
    client?.close();
 ```
