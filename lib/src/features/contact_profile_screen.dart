import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
import '../widgets/crm_widgets.dart';
import 'modals/edit_connection_modal.dart';

class ContactProfileScreen extends ConsumerWidget {
  const ContactProfileScreen({super.key, required this.contactId});
  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final person = state.connections.firstWhere((c) => c.id == contactId);
    final history = state.interactions.where((i) => i.contactId == contactId).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      body: ListView(padding: const EdgeInsets.all(26), children: [
        SafeArea(child: Row(children: [IconButton.filledTonal(onPressed: Navigator.of(context).pop, icon: const Icon(Icons.arrow_back)), const Spacer(), IconButton.filledTonal(onPressed: () => showEditConnectionModal(context, person), icon: const Icon(Icons.edit)), IconButton.filled(onPressed: () => context.push('/ai-update/${person.id}'), icon: const Icon(Icons.auto_awesome))])),
        CardBox(child: Column(children: [CircleAvatar(radius: 54, backgroundColor: const Color(0xFFE0F0F0), child: Text(person.avatar, style: const TextStyle(fontSize: 46))), const SizedBox(height: 12), Text(person.name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)), Text(person.email, style: const TextStyle(fontSize: 21, color: Colors.black54)), const SizedBox(height: 18), ScoreRing(score: person.bondScore, size: 118, stroke: 12), const SizedBox(height: 14), Chip(label: Text(person.category)), Text(person.notes, textAlign: TextAlign.center)])),
        SectionTitle('Next Step'),
        CardBox(child: Text(person.nextStep, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
        SectionTitle('History'),
        for (final item in history) CardBox(child: ListTile(leading: Icon(item.type.icon), title: Text(item.title), subtitle: Text(item.note))),
      ]),
    );
  }
}
