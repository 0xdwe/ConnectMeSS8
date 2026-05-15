import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../theme/app_tokens.dart';
import '../widgets/crm_widgets.dart';
import 'modals/edit_user_profile_modal.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(appControllerProvider);
    final user = state.user;
    return Scaffold(
      backgroundColor: tokens.surface,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: tokens.primary,
            padding: const EdgeInsets.fromLTRB(30, 38, 30, 34),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: InkWell(
                            onTap: Navigator.of(context).pop,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back,
                                  color: tokens.primaryOn,
                                  size: 34,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                    color: tokens.primaryOn,
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => showEditUserProfileModal(context),
                        icon: const Icon(Icons.edit),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  CircleAvatar(
                    radius: 66,
                    backgroundColor: tokens.surfaceRaised,
                    child: Text(
                      user.avatar,
                      style: const TextStyle(fontSize: 54),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    user.name,
                    style: TextStyle(
                      color: tokens.primaryOn,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.email,
                    style: TextStyle(
                      color: tokens.primaryOn,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CardBox(
                        child: Column(
                          children: [
                            Text(
                              '${state.averageConnectionScore}',
                              style: TextStyle(
                                color: tokens.primary,
                                fontSize: 46,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Connection Score',
                              style: TextStyle(
                                fontSize: 21,
                                color: tokens.inkMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: CardBox(
                        child: Column(
                          children: [
                            Text(
                              '${state.connections.length}',
                              style: TextStyle(
                                color: tokens.secondary,
                                fontSize: 46,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Total Connections',
                              style: TextStyle(
                                fontSize: 21,
                                color: tokens.inkMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                HeatmapCard(connections: state.connections),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
