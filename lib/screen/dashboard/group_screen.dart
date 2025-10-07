import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:money_manager/screen/dashboard/group_details_screen.dart';

class GroupsScreen extends StatelessWidget {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  void _createGroup(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Group'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: 'Group Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('groups').add({
                'name': nameController.text,
                'createdBy': userId,
                'members': [userId],
                'createdAt': Timestamp.now(),
              });
              Navigator.pop(context);
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Split Groups')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .where('members', arrayContains: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final groups = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final data = groups[index].data() as Map<String, dynamic>;
              final members = (data['members'] as List).length;

              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Icons.group)),
                  title: Text(data['name'] ?? 'Unnamed Group'),
                  subtitle: Text('$members members'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupDetailScreen(
                        groupId: groups[index].id,
                        groupName: data['name'],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createGroup(context),
        child: Icon(Icons.add),
      ),
    );
  }
}