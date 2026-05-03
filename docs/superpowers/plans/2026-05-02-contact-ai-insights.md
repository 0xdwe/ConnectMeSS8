# Contact AI Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add AI Insights to each personal connection dashboard using a hybrid mock-now, future-AI-ready insight model.

**Architecture:** Add small domain fields to `Connection`, add `ContactInsight`, compute insights in `AppState.contactInsightFor(contactId)`, then render the Insight-First Hybrid dashboard in `ContactProfileScreen`. Keep current Riverpod/local mock architecture; no backend or real AI API.

**Tech Stack:** Flutter, Dart, Riverpod, go_router, flutter_test.

---

## File Map

- Modify `lib/src/models/social_models.dart`: add `ContactInsight`, `knownSince`, `preferredChannels`, copyWith fields.
- Modify `lib/src/state/app_state.dart`: seed new fields and add `contactInsightFor(contactId)` rule generator.
- Modify `lib/src/widgets/crm_widgets.dart`: add reusable insight/action/facts/channel/frequency widgets.
- Modify `lib/src/features/contact_profile_screen.dart`: replace current simple profile layout with Insight-First Hybrid dashboard.
- Modify `test/state/app_state_test.dart`: add insight generator state test.
- Modify `test/widget_test.dart`: add profile rendering + expandable insight widget tests.

---

### Task 1: Add Insight Domain Model

**Files:**
- Modify: `lib/src/models/social_models.dart`
- Test: `test/state/app_state_test.dart`

- [ ] **Step 1: Write failing state test for new insight API**

Append this test to `test/state/app_state_test.dart`:

```dart
test('contactInsightFor returns future-AI-shaped insight data', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  final state = container.read(appControllerProvider);
  final insight = state.contactInsightFor('jessica');

  expect(insight.contactId, 'jessica');
  expect(insight.summary, isNotEmpty);
  expect(insight.why, isNotEmpty);
  expect(insight.recommendedAction, isNotEmpty);
  expect(insight.potentialScoreGain, greaterThan(0));
  expect(insight.relationshipLabel, 'College');
  expect(insight.knownSinceYears, greaterThanOrEqualTo(1));
  expect(insight.preferredChannels, contains('FaceTime'));
  expect(insight.frequencyByMonth, hasLength(12));
});
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
flutter test test/state/app_state_test.dart
```

Expected: FAIL because `contactInsightFor`, `ContactInsight`, `knownSince`, or `preferredChannels` do not exist.

- [ ] **Step 3: Update `Connection` and add `ContactInsight`**

In `lib/src/models/social_models.dart`, replace the `Connection` class with this version and add `ContactInsight` after `Recommendation`:

```dart
class Connection {
  const Connection({
    required this.id,
    required this.name,
    required this.email,
    required this.category,
    required this.avatar,
    required this.bondScore,
    required this.nextStep,
    required this.lastContact,
    required this.notes,
    required this.knownSince,
    required this.preferredChannels,
  });

  final String id;
  final String name;
  final String email;
  final String category;
  final String avatar;
  final int bondScore;
  final String nextStep;
  final DateTime lastContact;
  final String notes;
  final DateTime knownSince;
  final List<String> preferredChannels;

  String get role => category;
  String get company => email;
  String get avatarSeed => avatar;
  int get closeness => bondScore;
  List<String> get tags => [category];

  Connection copyWith({
    String? name,
    String? email,
    String? category,
    String? avatar,
    int? bondScore,
    String? nextStep,
    DateTime? lastContact,
    String? notes,
    DateTime? knownSince,
    List<String>? preferredChannels,
  }) {
    return Connection(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      category: category ?? this.category,
      avatar: avatar ?? this.avatar,
      bondScore: bondScore ?? this.bondScore,
      nextStep: nextStep ?? this.nextStep,
      lastContact: lastContact ?? this.lastContact,
      notes: notes ?? this.notes,
      knownSince: knownSince ?? this.knownSince,
      preferredChannels: preferredChannels ?? this.preferredChannels,
    );
  }
}
```

Add after `Recommendation`:

```dart
class ContactInsight {
  const ContactInsight({
    required this.contactId,
    required this.summary,
    required this.why,
    required this.recommendedAction,
    required this.potentialScoreGain,
    required this.relationshipLabel,
    required this.knownSinceYears,
    required this.preferredChannels,
    required this.frequencyByMonth,
    this.aiConfidence,
  });

  final String contactId;
  final String summary;
  final String why;
  final String recommendedAction;
  final int potentialScoreGain;
  final String relationshipLabel;
  final int knownSinceYears;
  final List<String> preferredChannels;
  final List<int> frequencyByMonth;
  final double? aiConfidence;
}
```

- [ ] **Step 4: Run analyzer to see required constructor updates**

Run:

```bash
flutter analyze
```

Expected: FAIL for missing `knownSince` and `preferredChannels` in `Connection(...)` calls.

- [ ] **Step 5: Commit domain model change after Task 2 passes**

Do not commit yet if tests fail. Commit after Task 2 completes.

---

### Task 2: Add Mock Insight Generator

**Files:**
- Modify: `lib/src/state/app_state.dart`
- Test: `test/state/app_state_test.dart`

- [ ] **Step 1: Update seeded connections**

In each `Connection(...)` seed in `AppState.seeded()`, add fields:

```dart
knownSince: DateTime(2012, 1, 1),
preferredChannels: const ['Text', 'FaceTime', 'Instagram'],
```

Use these exact values per contact:

```dart
// David
knownSince: DateTime(1998, 5, 1),
preferredChannels: const ['Text', 'Phone', 'FaceTime'],

// Emily
knownSince: DateTime(2023, 9, 1),
preferredChannels: const ['Slack', 'Email', 'Text'],

// Jessica
knownSince: DateTime(2012, 9, 1),
preferredChannels: const ['Instagram', 'Text', 'FaceTime'],

// Mike
knownSince: DateTime(2010, 9, 1),
preferredChannels: const ['Text', 'Instagram', 'Phone'],

// Sarah
knownSince: DateTime(2020, 6, 1),
preferredChannels: const ['Text', 'Instagram', 'Coffee'],
```

In `addConnection(...)`, add:

```dart
knownSince: DateTime.now(),
preferredChannels: const ['Text'],
```

In `runAiUpdate(...)`, preserve channels with existing `copyWith`; no channel update yet.

- [ ] **Step 2: Add `contactInsightFor` to `AppState`**

Add this method inside `AppState`:

```dart
ContactInsight contactInsightFor(String contactId) {
  final contact = connections.firstWhere((connection) => connection.id == contactId);
  final contactInteractions = interactions.where((interaction) => interaction.contactId == contactId).toList();
  final now = DateTime.now();
  final daysSinceContact = now.difference(contact.lastContact).inDays;
  final knownSinceYears = (now.difference(contact.knownSince).inDays / 365).floor().clamp(1, 99);
  final gain = _potentialGain(contact.bondScore, daysSinceContact);
  final frequency = _frequencyByMonth(contactInteractions, now);
  final channel = contact.preferredChannels.isEmpty ? 'Text' : contact.preferredChannels.first;
  final stalePhrase = daysSinceContact >= 28 ? "It's been almost a month" : "You have recent momentum";

  return ContactInsight(
    contactId: contact.id,
    summary: '$stalePhrase. A $channel message could be a nice way to reconnect!',
    why: 'AI looked at last contact timing, ${contact.category} relationship context, bond score ${contact.bondScore}, and recent interaction frequency.',
    recommendedAction: contact.nextStep,
    potentialScoreGain: gain,
    relationshipLabel: contact.category,
    knownSinceYears: knownSinceYears,
    preferredChannels: contact.preferredChannels,
    frequencyByMonth: frequency,
    aiConfidence: 0.82,
  );
}

static int _potentialGain(int bondScore, int daysSinceContact) {
  if (daysSinceContact >= 30 && bondScore < 75) return 10;
  if (daysSinceContact >= 21) return 8;
  if (bondScore >= 85) return 4;
  return 6;
}

static List<int> _frequencyByMonth(List<CrmInteraction> contactInteractions, DateTime now) {
  return List<int>.generate(12, (index) {
    final month = DateTime(now.year, now.month - 11 + index);
    return contactInteractions.where((interaction) {
      return interaction.date.year == month.year && interaction.date.month == month.month;
    }).length;
  });
}
```

- [ ] **Step 3: Run state test**

Run:

```bash
flutter test test/state/app_state_test.dart
```

Expected: PASS.

- [ ] **Step 4: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: PASS.

- [ ] **Step 5: Commit model + generator**

Run:

```bash
git add lib/src/models/social_models.dart lib/src/state/app_state.dart test/state/app_state_test.dart
git commit -m "feat: add contact insight model"
```

---

### Task 3: Add Reusable Dashboard Widgets

**Files:**
- Modify: `lib/src/widgets/crm_widgets.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Add widget test for insight UI pieces**

Append to `test/widget_test.dart`:

```dart
testWidgets('contact profile renders AI insight dashboard cards', (tester) async {
  await pumpConnectMe(tester);
  await tester.tap(find.byKey(const Key('sign-in-button')));
  await tester.pumpAndSettle();

  await tester.tap(find.text('People'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Jessica Taylor'));
  await tester.pumpAndSettle();

  expect(find.text('Recommended Action!'), findsOneWidget);
  expect(find.text('AI Insight'), findsOneWidget);
  expect(find.text('Top Communication Channels'), findsOneWidget);
  expect(find.text('Interaction Frequency (12 months)'), findsOneWidget);
});
```

- [ ] **Step 2: Add reusable widgets**

Append to `lib/src/widgets/crm_widgets.dart`:

```dart
class RecommendedActionCard extends StatelessWidget {
  const RecommendedActionCard({super.key, required this.insight});
  final ContactInsight insight;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: const Color(0xFFFF9583), borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          const Text('Recommended Action!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text('You can gain ${insight.potentialScoreGain}% Connection Score', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(insight.recommendedAction, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class InsightCard extends StatefulWidget {
  const InsightCard({super.key, required this.insight});
  final ContactInsight insight;

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('ai-insight-card'),
      onTap: () => setState(() => expanded = !expanded),
      borderRadius: BorderRadius.circular(22),
      child: CardBox(
        border: Border.all(color: const Color(0xFFFFE45C)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.lightbulb_outline, color: Color(0xFF9A5A00)), SizedBox(width: 12), Text('AI Insight', style: TextStyle(color: Color(0xFF7A3F00), fontSize: 22, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 12),
          Text(widget.insight.summary, style: const TextStyle(color: Color(0xFF8A4B00), fontSize: 20, height: 1.35, fontWeight: FontWeight.w700)),
          if (expanded) ...[
            const SizedBox(height: 14),
            Text(widget.insight.why, key: const Key('ai-insight-why'), style: const TextStyle(color: Color(0xFF6B3A00), fontSize: 16, height: 1.35)),
          ],
        ]),
      ),
    );
  }
}

class RelationshipFactsCard extends StatelessWidget {
  const RelationshipFactsCard({super.key, required this.connection, required this.insight});
  final Connection connection;
  final ContactInsight insight;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _Fact(label: 'Relationship', value: insight.relationshipLabel)),
          Expanded(child: _Fact(label: 'Known Since', value: '${insight.knownSinceYears} years')),
        ]),
        const SizedBox(height: 18),
        Row(children: [const Icon(Icons.calendar_today_outlined, color: Color(0xFF4B5563)), const SizedBox(width: 12), Text('Last contact: ${DateFormat('yyyy-MM-dd').format(connection.lastContact)}', style: const TextStyle(fontSize: 19, color: Color(0xFF4B5563), fontWeight: FontWeight.w700))]),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 18, color: Color(0xFF4B5563), fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 23, color: Colors.black, fontWeight: FontWeight.w900)),
      ]);
}

class CommunicationChannelsCard extends StatelessWidget {
  const CommunicationChannelsCard({super.key, required this.channels});
  final List<String> channels;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.chat_bubble_outline, color: AppTheme.moss), SizedBox(width: 12), Expanded(child: Text('Top Communication Channels', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)))]),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: channels.map((channel) => Chip(label: Text(channel, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), backgroundColor: AppTheme.moss, side: BorderSide.none)).toList()),
      ]),
    );
  }
}

class InteractionFrequencyCard extends StatelessWidget {
  const InteractionFrequencyCard({super.key, required this.frequencyByMonth});
  final List<int> frequencyByMonth;

  @override
  Widget build(BuildContext context) {
    final maxValue = frequencyByMonth.fold<int>(1, (max, value) => value > max ? value : max);
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Interaction Frequency (12 months)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        Row(children: List.generate(12, (index) {
          final alpha = 0.35 + (frequencyByMonth[index] / maxValue) * 0.55;
          return Expanded(child: Column(children: [
            Container(key: Key('frequency-bar-$index'), height: 32, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: AppTheme.moss.withValues(alpha: alpha), borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 8),
            Text('${index + 1}', style: const TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w700)),
          ]));
        })),
      ]),
    );
  }
}
```

- [ ] **Step 3: Run widget test to verify failure remains until screen uses widgets**

Run:

```bash
flutter test test/widget_test.dart --plain-name 'contact profile renders AI insight dashboard cards'
```

Expected: FAIL because contact profile does not render new widgets yet.

- [ ] **Step 4: Commit widgets after Task 4 passes**

Do not commit yet if screen test still fails. Commit after Task 4.

---

### Task 4: Replace Contact Profile Layout

**Files:**
- Modify: `lib/src/features/contact_profile_screen.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Replace `ContactProfileScreen.build` body**

In `lib/src/features/contact_profile_screen.dart`, keep imports and class shell. Replace `build` with:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final state = ref.watch(appControllerProvider);
  final person = state.connections.firstWhere((connection) => connection.id == contactId);
  final insight = state.contactInsightFor(contactId);
  final history = state.interactions.where((interaction) => interaction.contactId == contactId).toList();

  return Scaffold(
    backgroundColor: const Color(0xFFF5F6F7),
    body: ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: const Color(0xFF008B83),
          padding: const EdgeInsets.fromLTRB(28, 34, 28, 30),
          child: SafeArea(
            bottom: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: Navigator.of(context).pop,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.arrow_back, color: Colors.white, size: 32),
                  SizedBox(width: 10),
                  Text('Back', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 26),
              Row(children: [
                CircleAvatar(radius: 52, backgroundColor: Colors.white, child: Text(person.avatar, style: const TextStyle(fontSize: 44))),
                const SizedBox(width: 24),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(person.name, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(person.email, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
                ])),
              ]),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Icon(Icons.trending_up, color: Colors.white), SizedBox(width: 8), Text('Bond Score', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))]),
                const SizedBox(height: 18),
                Text('${person.bondScore}', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                const Text('Strong connection!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ]), padding: const EdgeInsets.all(22), border: null)),
              const SizedBox(width: 12),
              Expanded(child: RecommendedActionCard(insight: insight)),
            ]),
            InsightCard(insight: insight),
            RelationshipFactsCard(connection: person, insight: insight),
            CommunicationChannelsCard(channels: insight.preferredChannels),
            InteractionFrequencyCard(frequencyByMonth: insight.frequencyByMonth),
            if (history.isNotEmpty) ...[
              SectionTitle('History'),
              for (final item in history) CardBox(child: ListTile(leading: Icon(item.type.icon), title: Text(item.title), subtitle: Text(item.note))),
            ],
          ]),
        ),
      ],
    ),
  );
}
```

Then adjust the Bond Score card because `CardBox` is white by default. Replace that first `Expanded(child: CardBox(...))` with a teal `Container` if the analyzer/UI complains. Preferred exact replacement:

```dart
Expanded(
  child: Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: AppTheme.moss, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 7, offset: Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.trending_up, color: Colors.white), SizedBox(width: 8), Text('Bond Score', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 18),
      Text('${person.bondScore}', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
      const Text('Strong connection!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    ]),
  ),
),
```

Add import if needed:

```dart
import '../theme/app_theme.dart';
```

- [ ] **Step 2: Run targeted widget test**

Run:

```bash
flutter test test/widget_test.dart --plain-name 'contact profile renders AI insight dashboard cards'
```

Expected: PASS.

- [ ] **Step 3: Write expand/collapse widget test**

Append to `test/widget_test.dart`:

```dart
testWidgets('AI insight card expands why details', (tester) async {
  await pumpConnectMe(tester);
  await tester.tap(find.byKey(const Key('sign-in-button')));
  await tester.pumpAndSettle();

  await tester.tap(find.text('People'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Jessica Taylor'));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('ai-insight-why')), findsNothing);
  await tester.tap(find.byKey(const Key('ai-insight-card')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('ai-insight-why')), findsOneWidget);
});
```

- [ ] **Step 4: Run targeted expand/collapse test**

Run:

```bash
flutter test test/widget_test.dart --plain-name 'AI insight card expands why details'
```

Expected: PASS.

- [ ] **Step 5: Run full checks**

Run:

```bash
flutter analyze
flutter test
```

Expected: analyzer PASS, all tests PASS.

- [ ] **Step 6: Commit UI implementation**

Run:

```bash
git add lib/src/features/contact_profile_screen.dart lib/src/widgets/crm_widgets.dart test/widget_test.dart
git commit -m "feat: add contact ai insight dashboard"
```

---

### Task 5: Polish Data/Visual Details

**Files:**
- Modify: `lib/src/features/contact_profile_screen.dart`
- Modify: `lib/src/widgets/crm_widgets.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Verify screenshot parity manually**

Run app:

```bash
flutter run -d chrome
```

Navigate: sign in -> People -> Jessica Taylor.

Expected visual order:
1. Teal header with Jessica avatar/name/email.
2. Bond Score + Recommended Action top row.
3. Yellow AI Insight card.
4. Relationship facts.
5. Communication channels.
6. Interaction frequency.
7. History.

- [ ] **Step 2: Fix overflow if small widths fail**

If top row overflows on mobile width, replace row with responsive `LayoutBuilder`:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final narrow = constraints.maxWidth < 430;
    final cards = [
      _BondScorePanel(score: person.bondScore),
      RecommendedActionCard(insight: insight),
    ];
    if (narrow) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards);
    }
    return Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]);
  },
),
```

If using `_BondScorePanel`, create it in `contact_profile_screen.dart`:

```dart
class _BondScorePanel extends StatelessWidget {
  const _BondScorePanel({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppTheme.moss, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 7, offset: Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.trending_up, color: Colors.white), SizedBox(width: 8), Text('Bond Score', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 18),
        Text('$score', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
        const Text('Strong connection!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
```

- [ ] **Step 3: Re-run full checks**

Run:

```bash
flutter analyze
flutter test
```

Expected: analyzer PASS, all tests PASS.

- [ ] **Step 4: Commit polish if changes made**

Run only if Task 5 changed files:

```bash
git add lib/src/features/contact_profile_screen.dart lib/src/widgets/crm_widgets.dart test/widget_test.dart
git commit -m "polish: refine contact insight dashboard layout"
```

---

## Self-Review

Spec coverage:
- Hybrid model: Task 1 + Task 2.
- Insight-first UI: Task 3 + Task 4.
- Expandable why details: Task 3 + Task 4.
- Recommended gain, channels, 12-month frequency: Task 1 + Task 2 + Task 3.
- Tests: Task 1, Task 3, Task 4.
- No real AI API/backend: preserved by AppState mock generator.

Placeholder scan:
- No TBD/TODO placeholders.
- All new method/type names defined before use.
- Exact commands provided.

Type consistency:
- `ContactInsight`, `contactInsightFor`, `preferredChannels`, `frequencyByMonth`, and `potentialScoreGain` names match across tasks.
