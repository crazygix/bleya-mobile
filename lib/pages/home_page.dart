import 'package:flutter/material.dart';
import 'chats_page.dart';
import 'settings_page.dart';
import 'join_room_dialog.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Bleya'),
          actions: [
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => JoinRoomDialog(),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              ChatsPage(),
              SettingsPage(),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat), text: 'Chats'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
