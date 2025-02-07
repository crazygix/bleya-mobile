import 'package:flutter/material.dart';
import 'chats_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Bleya'),
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
              Tab(icon: Icon(Icons.home), text: 'Home'),
              Tab(icon: Icon(Icons.favorite), text: 'Favorites'),
            ],
          ),
        ),
      ),
    );
  }
}
