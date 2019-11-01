import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wetransfer/wetransfer.dart';
import 'dart:io';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: App(),
    );
  }
}

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  WeTransferClient client;
  String _url;

  @override
  void initState() {
    super.initState();
    WeTransferClient.create('<your api key>')
        .then((cli) => setState(() => client = cli));
  }

  @override
  void dispose() {
    client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          "Let's Share !",
          style: Theme.of(context).textTheme.title,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          RaisedButton(
            onPressed: _send,
            child: Text("Choose and send files"),
          ),
          if (_url != null)
            Center(
              child: Text(
                _url,
                style: Theme.of(context).textTheme.title.copyWith(fontSize: 18),
              ),
            ),
        ],
      ),
    );
  }

  void _send() async {
    print("Gonna choose files");
    setState(() {
      _url = null;
    });

    Map<String, String> files = await FilePicker.getMultiFilePath();
    print("Got files");

    print("Creating transfer");

    Transfer transfer = await client.createTransfer(
        files.values.map<File>((f) => File(f)).toList(), "Test transfer yayyy");

    print("Transfer with id ${transfer.id} created");

    print("Uploading ${transfer.files.length} files");

    await client.uploadFiles(transfer).forEach(
        (s) => "${s.file.name} : ${s.type} ${s.done ? "done" : "in progress"}");

    print('Completed all uploads');
    print("Finalizing transfer");

    String url = await client.finalizeTransfer(transfer);

    setState(() {
      _url = url;
    });

    print("Transfer ${transfer.id} ready : $url");
  }
}
