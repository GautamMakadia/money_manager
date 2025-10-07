import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GroupDetailScreen extends StatelessWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({super.key, required this.groupId, required this.groupName});

  Future<Map<String, Map<String, dynamic>>> _loadMemberProfiles(
    List<String> memberIds,
  ) async {
    if (memberIds.isEmpty) return {};

    final firestore = FirebaseFirestore.instance;
    const batchSize = 10;
    final Map<String, Map<String, dynamic>> members = {};

    for (var i = 0; i < memberIds.length; i += batchSize) {
      final batch = memberIds.sublist(i, i + batchSize > memberIds.length ? memberIds.length : i + batchSize);
      if (batch.isEmpty) continue;
      final snapshot = await firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snapshot.docs) {
        members[doc.id] = doc.data();
      }
    }

    return members;
  }

  String _memberLabel(
    String uid,
    Map<String, Map<String, dynamic>> profiles,
  ) {
    final profile = profiles[uid] ?? const {};
    final displayName = profile['displayName'] as String?;
    final email = profile['email'] as String?;
    if (displayName != null && displayName.trim().isNotEmpty) return displayName.trim();
    if (email != null && email.trim().isNotEmpty) return email.trim();
    if (uid == FirebaseAuth.instance.currentUser?.uid) return 'You';
    return uid;
  }

  void _addMember(BuildContext context) {
    final emailController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Member Email',
            hintText: 'user@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                messenger.showSnackBar(const SnackBar(content: Text('Enter an email to continue.')));
                return;
              }

              try {
                final normalizedEmail = email.toLowerCase();
                final firestore = FirebaseFirestore.instance;
                
                print('DEBUG: Searching for user with email: $email (normalized: $normalizedEmail)');
                
                QuerySnapshot<Map<String, dynamic>> userQuery = await firestore
                    .collection('users')
                    .where('emailLower', isEqualTo: normalizedEmail)
                    .limit(1)
                    .get();

                print('DEBUG: First query (emailLower) found ${userQuery.docs.length} users');

                if (userQuery.docs.isEmpty) {
                  print('DEBUG: Trying fallback query with original email field');
                  userQuery = await firestore
                      .collection('users')
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();
                  print('DEBUG: Fallback query (email) found ${userQuery.docs.length} users');
                }

                if (userQuery.docs.isEmpty) {
                  print('DEBUG: No user found in either query');
                  messenger.showSnackBar(SnackBar(content: Text('No user found with email $email. Make sure they have signed up first.')));
                  return;
                }

                final newMemberId = userQuery.docs.first.id;
                final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
                final groupDoc = await groupRef.get();
                final currentMembers = List<String>.from(
                  (groupDoc.data()?['members'] as List?)?.map((member) => member as String) ?? const [],
                );

                if (currentMembers.contains(newMemberId)) {
                  messenger.showSnackBar(const SnackBar(content: Text('This user is already a member.')));
                  return;
                }

                await groupRef.update({'members': FieldValue.arrayUnion([newMemberId])});
                Navigator.of(dialogCtx).pop();
                messenger.showSnackBar(SnackBar(content: Text('Added ${emailController.text.trim()} to the group.')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed to add member: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addGroupExpense(
    BuildContext context,
    List<String> memberIds,
    Map<String, Map<String, dynamic>> memberProfiles,
  ) {
    if (memberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add members to the group before creating shared expenses.'),
      ));
      return;
    }

    final descController = TextEditingController();
    final amountController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    String? selectedPayer =
        currentUserId != null && memberIds.contains(currentUserId) ? currentUserId : memberIds.first;
    final selectedMembers = memberIds.toSet();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              title: const Text('Add Group Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Total Amount'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPayer,
                      decoration: const InputDecoration(labelText: 'Paid by'),
                      items: memberIds
                          .map(
                            (id) => DropdownMenuItem(
                              value: id,
                              child: Text(_memberLabel(id, memberProfiles)),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => selectedPayer = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Split between',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ...memberIds.map(
                      (memberId) => CheckboxListTile(
                        value: selectedMembers.contains(memberId),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              selectedMembers.add(memberId);
                            } else if (selectedMembers.length > 1) {
                              selectedMembers.remove(memberId);
                              if (selectedPayer != null && !selectedMembers.contains(selectedPayer)) {
                                selectedPayer = selectedMembers.isEmpty ? null : selectedMembers.first;
                              }
                            }
                          });
                        },
                        title: Text(_memberLabel(memberId, memberProfiles)),
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final description = descController.text.trim();
                    final amount = double.tryParse(amountController.text.trim());

                    if (amount == null || amount <= 0) {
                      messenger.showSnackBar(const SnackBar(content: Text('Enter a valid amount greater than 0.')));
                      return;
                    }

                    if (selectedMembers.isEmpty) {
                      messenger.showSnackBar(const SnackBar(content: Text('Select at least one participant.')));
                      return;
                    }

                    if (selectedPayer == null) {
                      messenger.showSnackBar(const SnackBar(content: Text('Select who paid for the expense.')));
                      return;
                    }

                    try {
                      final splits = <String, double>{};
                      final participants = selectedMembers.toList();
                      final equalShare = amount / participants.length;

                      for (var i = 0; i < participants.length; i++) {
                        final participantId = participants[i];
                        final share = i == participants.length - 1
                            ? amount - splits.values.fold(0, (prev, element) => prev + element)
                            : equalShare;
                        splits[participantId] = share;
                      }

                      await FirebaseFirestore.instance.collection('groupExpenses').add({
                        'groupId': groupId,
                        'paidBy': selectedPayer,
                        'description': description.isEmpty ? 'Shared expense' : description,
                        'amount': amount,
                        'date': Timestamp.now(),
                        'splits': splits,
                        'participants': participants,
                      });

                      Navigator.of(dialogCtx).pop();
                      messenger.showSnackBar(const SnackBar(content: Text('Expense added successfully.')));
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Failed to add expense: $e')));
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('groups').doc(groupId).snapshots(),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (groupSnapshot.hasError || !groupSnapshot.hasData || !groupSnapshot.data!.exists) {
          final message = groupSnapshot.hasError
              ? 'Failed to load group details. Please try again later.\n${groupSnapshot.error}'
              : 'Group not found or has been deleted.';
          return Scaffold(
            appBar: AppBar(title: Text(groupName)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(message, textAlign: TextAlign.center),
              ),
            ),
          );
        }

        final groupData = groupSnapshot.data!.data() ?? const {};
        final memberIds = List<String>.from((groupData['members'] as List?)?.map((id) => id as String) ?? const []);
        final resolvedGroupName = groupData['name'] as String? ?? groupName;

        return FutureBuilder<Map<String, Map<String, dynamic>>>(
          future: _loadMemberProfiles(memberIds),
          builder: (context, membersSnapshot) {
            final membersLoading = membersSnapshot.connectionState == ConnectionState.waiting;
            final memberProfiles = membersSnapshot.data ?? {};

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('groupExpenses')
                  .where('groupId', isEqualTo: groupId)
                  .snapshots(),
              builder: (context, expenseSnapshot) {
                final expensesLoading = expenseSnapshot.connectionState == ConnectionState.waiting;

                if (expensesLoading && expenseSnapshot.data == null) {
                  return Scaffold(
                    appBar: AppBar(
                      title: Text(resolvedGroupName),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.person_add),
                          tooltip: 'Add member',
                          onPressed: () => _addMember(context),
                        ),
                      ],
                    ),
                    body: const Center(child: CircularProgressIndicator()),
                  );
                }

                if (expenseSnapshot.hasError) {
                  return Scaffold(
                    appBar: AppBar(
                      title: Text(resolvedGroupName),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.person_add),
                          tooltip: 'Add member',
                          onPressed: () => _addMember(context),
                        ),
                      ],
                    ),
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Failed to load group expenses. Please try again later.\n${expenseSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }

                final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  expenseSnapshot.data?.docs ?? const [],
                )
                  ..sort((a, b) {
                    final bDate = _parseDate(b.data()['date']);
                    final aDate = _parseDate(a.data()['date']);
                    return bDate.compareTo(aDate);
                  });

                final total = docs.fold<double>(
                  0,
                  (sum, doc) => sum + _parseAmount(doc.data()['amount']),
                );

                final content = <Widget>[
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Group Members',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          if (membersLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (memberIds.isEmpty)
                            const Text('No members yet. Tap the add icon to invite friends.')
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: memberIds
                                  .map((id) => Chip(label: Text(_memberLabel(id, memberProfiles))))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    color: Colors.orange,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Group Expense',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ];

                if (docs.isEmpty) {
                  content.add(
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Column(
                        children: const [
                          Icon(Icons.receipt_long, color: Colors.grey, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'No expenses added for this group yet. Tap the + button to add one.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  for (final doc in docs) {
                    final data = doc.data();
                    final date = _parseDate(data['date']);
                    final paidBy = data['paidBy'] as String?;
                    final splitsRaw = data['splits'];
                    final participantsRaw = data['participants'];
                    final Map<String, dynamic> splits =
                        splitsRaw is Map<String, dynamic> ? splitsRaw : <String, dynamic>{};
                    final participants = participantsRaw is List
                        ? participantsRaw.map((e) => e.toString()).toList()
                        : splits.keys.toList();
                    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                    final myShare = currentUserId != null && splits[currentUserId] != null
                        ? _parseAmount(splits[currentUserId])
                        : null;

                    content.add(
                      Card(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(child: Icon(Icons.receipt)),
                                title: Text(data['description'] ?? 'Shared expense'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Paid by ${_memberLabel(paidBy ?? 'Unknown', memberProfiles)} on ${DateFormat('MMM dd, yyyy').format(date)}',
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: participants
                                          .map(
                                            (participant) => Chip(
                                              label: Text(
                                                '${_memberLabel(participant, memberProfiles)}: '
                                                '\$${_parseAmount(splits[participant]).toStringAsFixed(2)}',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                    if (myShare != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Your share: \$${myShare.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  '\$${_parseAmount(data['amount']).toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                }

                return Scaffold(
                  appBar: AppBar(
                    title: Text(resolvedGroupName),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.person_add),
                        tooltip: 'Add member',
                        onPressed: () => _addMember(context),
                      ),
                    ],
                  ),
                  floatingActionButton: membersLoading
                      ? null
                      : FloatingActionButton.extended(
                          onPressed: () => _addGroupExpense(context, memberIds, memberProfiles),
                          label: const Text('Add Expense'),
                          icon: const Icon(Icons.add),
                        ),
                  body: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: content,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}