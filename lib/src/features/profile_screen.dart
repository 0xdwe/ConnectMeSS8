import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../widgets/crm_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: const Color(0xFF008B83),
            padding: const EdgeInsets.fromLTRB(30, 38, 30, 34),
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                Align(alignment: Alignment.centerLeft, child: InkWell(onTap: Navigator.of(context).pop, child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.arrow_back, color: Colors.white, size: 34), SizedBox(width: 12), Text('Back', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800))]))),
                const SizedBox(height: 34),
                const CircleAvatar(radius: 66, backgroundColor: Colors.white, child: Text('👤', style: TextStyle(fontSize: 54))),
                const SizedBox(height: 24),
                const Text('Alex Martinez', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                const Text('alex.martinez@email.com', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(26),
            child: Column(children: [
              Row(children: [
                Expanded(child: CardBox(child: Column(children: [Text('${state.averageConnectionScore}', style: const TextStyle(color: Color(0xFF008B83), fontSize: 46, fontWeight: FontWeight.w900)), const Text('Connection Score', style: TextStyle(fontSize: 21, color: Colors.black54, fontWeight: FontWeight.w700))]))),
                const SizedBox(width: 20),
                Expanded(child: CardBox(child: Column(children: [Text('${state.connections.length}', style: const TextStyle(color: Color(0xFFFF784E), fontSize: 46, fontWeight: FontWeight.w900)), const Text('Total Connections', style: TextStyle(fontSize: 21, color: Colors.black54, fontWeight: FontWeight.w700))]))),
              ]),
              const SizedBox(height: 20),
              HeatmapCard(connections: state.connections),
            ]),
          ),
        ],
      ),
    );
  }
}
