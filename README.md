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
    
    Transfer transfer = await client.createTransfer(
        myFiles, "Test transfer.");

    await client.uploadFiles(transfer).forEach((state) =>
        print('${state.file.name} : ${state.type}'));

    String url = await client.finalizeTransfer(transfer);

    client?.close();
 ```
