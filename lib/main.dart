import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const ThompsonApp());
}

// ============================================================
// APP
// ============================================================

class ThompsonApp extends StatelessWidget {
  const ThompsonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Thompson Construction Engine",
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const ThompsonHomePage(),
    );
  }
}

// ============================================================
// MODELS
// ============================================================

class Transition {
  final int from;
  final int to;
  final String symbol;

  Transition({
    required this.from,
    required this.to,
    required this.symbol,
  });
}

class Fragment {
  final int start;
  final int end;

  Fragment(this.start, this.end);
}

class NfaResult {
  final int startState;
  final int finalState;
  final List<Transition> transitions;
  final List<String> steps;
  final String postfix;

  NfaResult({
    required this.startState,
    required this.finalState,
    required this.transitions,
    required this.steps,
    required this.postfix,
  });
}

// ============================================================
// STATE DISPLAY MAPPING
// ============================================================
//
// IMPORTANT:
// This class ONLY changes how states are DISPLAYED.
//
// The actual Thompson construction still uses the original
// internal state numbers.
//
// Display order:
//
//     actual start  -> q0
//     intermediate  -> q1, q2, q3, ...
//     actual final   -> q(last)
//
// This keeps the mathematical construction untouched while
// making the graph easier to understand.
// ============================================================

class StateDisplayMap {
  final int startState;
  final int finalState;
  final int count;

  late final Map<int, int> internalToDisplay;
  late final Map<int, int> displayToInternal;

  StateDisplayMap({
    required this.startState,
    required this.finalState,
    required this.count,
  }) {
    internalToDisplay = {};
    displayToInternal = {};

    int display = 0;

    // Start state is always q0.
    internalToDisplay[startState] = display;
    displayToInternal[display] = startState;
    display++;

    // Intermediate states.
    for (int internal = 0; internal < count; internal++) {
      if (internal == startState ||
          internal == finalState) {
        continue;
      }

      internalToDisplay[internal] = display;
      displayToInternal[display] = internal;
      display++;
    }

    // Final state is always the last state.
    internalToDisplay[finalState] = count - 1;
    displayToInternal[count - 1] = finalState;
  }

  int displayState(int internalState) {
    return internalToDisplay[internalState] ?? internalState;
  }

  int internalState(int displayState) {
    return displayToInternal[displayState] ?? displayState;
  }

  String displayLabel(int internalState) {
    return "q${displayState(internalState)}";
  }

  String convertStep(String step) {
    return step.replaceAllMapped(
      RegExp(r'q(\d+)'),
      (match) {
        final internalState =
            int.tryParse(match.group(1)!);

        if (internalState == null) {
          return match.group(0)!;
        }

        return "q${displayState(internalState)}";
      },
    );
  }
}

// ============================================================
// THOMPSON CONSTRUCTION ENGINE
// ============================================================

class ThompsonEngine {
  int nextState = 0;

  final List<Transition> transitions = [];
  final List<String> steps = [];

  int newState() => nextState++;

  void addTransition(
    int from,
    int to,
    String symbol,
  ) {
    transitions.add(
      Transition(
        from: from,
        to: to,
        symbol: symbol,
      ),
    );
  }

  bool isSymbol(String c) {
    return c != '.' &&
        c != '|' &&
        c != '*' &&
        c != '(' &&
        c != ')';
  }

  bool needsConcatenation(
    String a,
    String b,
  ) {
    final left =
        isSymbol(a) || a == ')' || a == '*';

    final right =
        isSymbol(b) || b == '(';

    return left && right;
  }

  String addExplicitConcatenation(
    String regex,
  ) {
    final chars = regex.split('');
    final output = StringBuffer();

    for (int i = 0; i < chars.length; i++) {
      output.write(chars[i]);

      if (i < chars.length - 1 &&
          needsConcatenation(
            chars[i],
            chars[i + 1],
          )) {
        output.write('.');
      }
    }

    return output.toString();
  }

  int precedence(String op) {
    if (op == '|') return 1;
    if (op == '.') return 2;
    if (op == '*') return 3;
    return 0;
  }

  List<String> toPostfix(String regex) {
    final prepared =
        addExplicitConcatenation(regex);

    final output = <String>[];
    final operators = <String>[];

    for (final token in prepared.split('')) {
      if (isSymbol(token)) {
        output.add(token);
      } else if (token == '(') {
        operators.add(token);
      } else if (token == ')') {
        while (
            operators.isNotEmpty &&
            operators.last != '(') {
          output.add(operators.removeLast());
        }

        if (operators.isEmpty) {
          throw Exception("Unmatched ')'.");
        }

        operators.removeLast();
      } else if (token == '*') {
        output.add(token);
      } else {
        while (
            operators.isNotEmpty &&
            operators.last != '(' &&
            precedence(operators.last) >=
                precedence(token)) {
          output.add(operators.removeLast());
        }

        operators.add(token);
      }
    }

    while (operators.isNotEmpty) {
      if (operators.last == '(') {
        throw Exception("Unmatched '('.");
      }

      output.add(operators.removeLast());
    }

    return output;
  }

  NfaResult build(String regex) {
    final postfix = toPostfix(regex);

    steps.add("Input: $regex");
    steps.add("Postfix: ${postfix.join(' ')}");
    steps.add("");

    final stack = <Fragment>[];

    for (final token in postfix) {
      // ======================================================
      // SYMBOL
      // ======================================================

      if (isSymbol(token)) {
        final start = newState();
        final end = newState();

        addTransition(
          start,
          end,
          token,
        );

        stack.add(
          Fragment(start, end),
        );

        steps.add(
          "Symbol '$token': q$start --$token--> q$end",
        );
      }

      // ======================================================
      // CONCATENATION
      // ======================================================

      else if (token == '.') {
        if (stack.length < 2) {
          throw Exception(
            "Invalid concatenation.",
          );
        }

        final right = stack.removeLast();
        final left = stack.removeLast();

        addTransition(
          left.end,
          right.start,
          "ε",
        );

        stack.add(
          Fragment(
            left.start,
            right.end,
          ),
        );

        steps.add(
          "Concatenation: "
          "q${left.end} --ε--> q${right.start}",
        );
      }

      // ======================================================
      // UNION
      // ======================================================

      else if (token == '|') {
        if (stack.length < 2) {
          throw Exception(
            "Invalid union.",
          );
        }

        final right = stack.removeLast();
        final left = stack.removeLast();

        final start = newState();
        final end = newState();

        addTransition(
          start,
          left.start,
          "ε",
        );

        addTransition(
          start,
          right.start,
          "ε",
        );

        addTransition(
          left.end,
          end,
          "ε",
        );

        addTransition(
          right.end,
          end,
          "ε",
        );

        stack.add(
          Fragment(
            start,
            end,
          ),
        );

        steps.add(
          "Union: q$start splits to "
          "q${left.start} and q${right.start}",
        );

        steps.add(
          "Union branches join at q$end",
        );
      }

      // ======================================================
      // KLEENE STAR
      // ======================================================

      else if (token == '*') {
        if (stack.isEmpty) {
          throw Exception(
            "Invalid Kleene star.",
          );
        }

        final fragment =
            stack.removeLast();

        final start = newState();
        final end = newState();

        addTransition(
          start,
          fragment.start,
          "ε",
        );

        addTransition(
          start,
          end,
          "ε",
        );

        addTransition(
          fragment.end,
          fragment.start,
          "ε",
        );

        addTransition(
          fragment.end,
          end,
          "ε",
        );

        stack.add(
          Fragment(
            start,
            end,
          ),
        );

        steps.add(
          "Kleene Star: q$start --ε--> "
          "q${fragment.start}",
        );

        steps.add(
          "Kleene Star: q${fragment.end} loops back "
          "to q${fragment.start}",
        );

        steps.add(
          "Kleene Star: q$start and "
          "q${fragment.end} can reach q$end",
        );
      }
    }

    if (stack.length != 1) {
      throw Exception(
        "Invalid regular expression.",
      );
    }

    final fragment = stack.single;

    steps.add("");
    steps.add(
      "Start state: q${fragment.start}",
    );
    steps.add(
      "Final state: q${fragment.end}",
    );

    return NfaResult(
      startState: fragment.start,
      finalState: fragment.end,
      transitions: transitions,
      steps: steps,
      postfix: postfix.join(' '),
    );
  }
}

// ============================================================
// MAIN SCREEN
// ============================================================

class ThompsonHomePage extends StatefulWidget {
  const ThompsonHomePage({super.key});

  @override
  State<ThompsonHomePage> createState() =>
      _ThompsonHomePageState();
}

class _ThompsonHomePageState
    extends State<ThompsonHomePage> {
  final controller =
      TextEditingController();

  NfaResult? result;
  String? error;

  void buildNfa() {
    final regex =
        controller.text.trim();

    if (regex.isEmpty) {
      setState(() {
        error =
            "Please enter a regular expression.";
        result = null;
      });

      return;
    }

    try {
      final engine =
          ThompsonEngine();

      final nfa =
          engine.build(regex);

      setState(() {
        result = nfa;
        error = null;
      });
    } catch (e) {
      setState(() {
        error = e
            .toString()
            .replaceFirst(
              "Exception: ",
              "",
            );

        result = null;
      });
    }
  }

  void clearAll() {
    controller.clear();

    setState(() {
      result = null;
      error = null;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Thompson Construction Engine",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 1200,
          ),
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Regular Expression → ε-NFA",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.bold,
                  ),
                  textAlign:
                      TextAlign.center,
                ),

                const SizedBox(height: 10),

                Text(
                  "Enter any basic regular expression dynamically.",
                  style: TextStyle(
                    color:
                        Colors.grey.shade400,
                    fontSize: 16,
                  ),
                  textAlign:
                      TextAlign.center,
                ),

                const SizedBox(height: 30),

                // ==================================================
                // INPUT CARD
                // ==================================================

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .stretch,
                      children: [
                        const Text(
                          "Regular Expression",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        TextField(
                          controller:
                              controller,
                          decoration:
                              InputDecoration(
                            hintText:
                                "Enter regex, e.g. ((a|b)*.c)|(d.e)",
                            prefixIcon:
                                const Icon(
                              Icons.functions,
                            ),
                            border:
                                const OutlineInputBorder(),
                            suffixIcon:
                                IconButton(
                              icon:
                                  const Icon(
                                Icons.clear,
                              ),
                              onPressed:
                                  clearAll,
                            ),
                          ),
                          onSubmitted:
                              (_) =>
                                  buildNfa(),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        const Text(
                          "Supported operators: .  |  *  ( )",
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        Row(
                          children: [
                            Expanded(
                              child:
                                  FilledButton
                                      .icon(
                                onPressed:
                                    buildNfa,
                                icon:
                                    const Icon(
                                  Icons
                                      .account_tree,
                                ),
                                label:
                                    const Text(
                                  "Build ε-NFA",
                                ),
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            OutlinedButton
                                .icon(
                              onPressed:
                                  clearAll,
                              icon:
                                  const Icon(
                                Icons.refresh,
                              ),
                              label:
                                  const Text(
                                "Clear",
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (error != null)
                  _buildError(),

                if (result != null) ...[
                  _buildOverview(
                    result!,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  NfaGraph(
                    nfa: result!,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _buildTransitionTable(
                    result!,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _buildConstructionSteps(
                    result!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  Widget _buildError() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error,
              color: Colors.red,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                "Invalid Input\n\n$error",
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // OVERVIEW
  // ==========================================================

  Widget _buildOverview(
    NfaResult nfa,
  ) {
    final map =
        _createDisplayMap(nfa);

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              "ε-NFA Result",
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              "✓ Thompson's Construction completed successfully.",
              style: TextStyle(
                color:
                    Colors.green.shade300,
                fontSize: 16,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statBox(
                  "Start State",
                  map.displayLabel(
                    nfa.startState,
                  ),
                ),

                _statBox(
                  "Final State",
                  map.displayLabel(
                    nfa.finalState,
                  ),
                ),

                _statBox(
                  "States",
                  "${_stateCount(nfa)}",
                ),

                _statBox(
                  "Transitions",
                  "${nfa.transitions.length}",
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              "Postfix Expression",
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            SelectableText(
              nfa.postfix,
            ),
          ],
        ),
      ),
    );
  }

  StateDisplayMap _createDisplayMap(
    NfaResult nfa,
  ) {
    return StateDisplayMap(
      startState: nfa.startState,
      finalState: nfa.finalState,
      count: _stateCount(nfa),
    );
  }

  int _stateCount(
    NfaResult nfa,
  ) {
    int highest = 0;

    for (final t
        in nfa.transitions) {
      highest =
          math.max(highest, t.from);

      highest =
          math.max(highest, t.to);
    }

    return highest + 1;
  }

  // ==========================================================
  // STAT BOX
  // ==========================================================

  Widget _statBox(
    String title,
    String value,
  ) {
    return Container(
      width: 180,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple
            .withValues(alpha: 0.15),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.deepPurple
              .withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color:
                  Colors.grey.shade400,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // TRANSITION TABLE
  // ==========================================================

  Widget _buildTransitionTable(
    NfaResult nfa,
  ) {
    final map =
        _createDisplayMap(nfa);

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              "Transition Table",
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            SingleChildScrollView(
              scrollDirection:
                  Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(
                    label: Text("From"),
                  ),
                  DataColumn(
                    label: Text("Input"),
                  ),
                  DataColumn(
                    label: Text("To"),
                  ),
                ],
                rows: nfa.transitions
                    .map(
                  (t) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            map.displayLabel(
                              t.from,
                            ),
                          ),
                        ),

                        DataCell(
                          Text(
                            t.symbol,
                            style: TextStyle(
                              color:
                                  t.symbol ==
                                          "ε"
                                      ? Colors
                                          .amber
                                      : Colors
                                          .white,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),

                        DataCell(
                          Text(
                            map.displayLabel(
                              t.to,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // CONSTRUCTION STEPS
  // ==========================================================

  Widget _buildConstructionSteps(
    NfaResult nfa,
  ) {
    final map =
        _createDisplayMap(nfa);

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              "Construction Steps",
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            ...nfa.steps
                .asMap()
                .entries
                .map(
              (entry) {
                final index =
                    entry.key;

                final originalStep =
                    entry.value;

                if (originalStep
                    .isEmpty) {
                  return const SizedBox(
                    height: 8,
                  );
                }

                final step =
                    map.convertStep(
                  originalStep,
                );

                return Padding(
                  padding:
                      const EdgeInsets
                          .only(
                    bottom: 10,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        child: Text(
                          "${index + 1}",
                          style:
                              const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Expanded(
                        child:
                            SelectableText(
                          step,
                          style:
                              const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

// ============================================================
// GRAPH WIDGET
// ============================================================

class NfaGraph
    extends StatelessWidget {
  final NfaResult nfa;

  const NfaGraph({
    super.key,
    required this.nfa,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final count =
        _stateCount();

    // More space than the states need so that
    // curves and labels do not get clipped.
    final width = math.max(
      1200.0,
      (count * 165.0) + 220.0,
    );

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              "ε-NFA Graph",
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            Container(
              height: 620,
              width: double.infinity,
              decoration:
                  BoxDecoration(
                color:
                    const Color(0xFF151218),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                border: Border.all(
                  color: Colors.white
                      .withValues(
                    alpha: 0.08,
                  ),
                ),
              ),
              child:
                  InteractiveViewer(
                constrained: false,

                minScale: 0.25,

                maxScale: 4.0,

                boundaryMargin:
                    const EdgeInsets.all(
                  300,
                ),

                panEnabled: true,

                scaleEnabled: true,

                child: CustomPaint(
                  size: Size(
                    width,
                    600,
                  ),
                  painter:
                      NfaGraphPainter(
                    nfa,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _legend(
                  "Start",
                  Colors.green,
                ),
                _legend(
                  "Final",
                  Colors.red,
                ),
                _legend(
                  "ε-transition",
                  Colors.amber,
                ),
                _legend(
                  "Normal transition",
                  Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _stateCount() {
    int highest = 0;

    for (final t
        in nfa.transitions) {
      highest =
          math.max(highest, t.from);

      highest =
          math.max(highest, t.to);
    }

    return highest + 1;
  }

  Widget _legend(
    String text,
    Color color,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(
            color: color,
            shape:
                BoxShape.circle,
          ),
        ),

        const SizedBox(
          width: 6,
        ),

        Text(text),
      ],
    );
  }
}

// ============================================================
// GRAPH PAINTER
// ============================================================

class NfaGraphPainter
    extends CustomPainter {
  final NfaResult nfa;

  NfaGraphPainter(this.nfa);

  static const double radius = 34;
  static const double stateY = 310;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final count =
        _stateCount();

    final displayMap =
        _createDisplayMap(count);

    final positions =
        _createPositions(
      count,
      size,
    );

    // ========================================================
    // DRAW TRANSITIONS FIRST
    // ========================================================

    final pairSeen =
        <String, int>{};

    for (final t
        in nfa.transitions) {
      final fromIndex =
          displayMap.displayState(
        t.from,
      );

      final toIndex =
          displayMap.displayState(
        t.to,
      );

      final key =
          '$fromIndex-$toIndex';

      final lane =
          pairSeen[key] ?? 0;

      pairSeen[key] =
          lane + 1;

      _drawTransition(
        canvas,
        positions[fromIndex]!,
        positions[toIndex]!,
        t.symbol,
        fromIndex,
        toIndex,
        lane,
      );
    }

    // ========================================================
    // DRAW STATES AFTER TRANSITIONS
    // ========================================================

    for (int internal = 0;
        internal < count;
        internal++) {
      final displayIndex =
          displayMap.displayState(
        internal,
      );

      _drawState(
        canvas,
        positions[displayIndex]!,
        displayIndex,
        internal ==
            nfa.startState,
        internal ==
            nfa.finalState,
      );
    }
  }

  // ==========================================================
  // DISPLAY MAP
  // ==========================================================

  StateDisplayMap _createDisplayMap(
    int count,
  ) {
    return StateDisplayMap(
      startState:
          nfa.startState,
      finalState:
          nfa.finalState,
      count: count,
    );
  }

  // ==========================================================
  // STATE POSITIONS
  // ==========================================================

  Map<int, Offset> _createPositions(
    int count,
    Size size,
  ) {
    final positions =
        <int, Offset>{};

    const double spacing =
        165;

    for (int i = 0;
        i < count;
        i++) {
      positions[i] =
          Offset(
        100 +
            (i * spacing),
        stateY,
      );
    }

    return positions;
  }

  // ==========================================================
  // DRAW STATE
  // ==========================================================

  void _drawState(
    Canvas canvas,
    Offset position,
    int state,
    bool isStart,
    bool isFinal,
  ) {
    final borderColor =
        isFinal
            ? Colors.red
            : isStart
                ? Colors.green
                : Colors
                    .deepPurple
                    .shade300;

    final fill =
        Paint()
          ..color =
              const Color(
            0xFF29232F,
          )
          ..style =
              PaintingStyle.fill;

    final border =
        Paint()
          ..color =
              borderColor
          ..strokeWidth =
              3.5
          ..style =
              PaintingStyle.stroke;

    // Main circle.
    canvas.drawCircle(
      position,
      radius,
      fill,
    );

    canvas.drawCircle(
      position,
      radius,
      border,
    );

    // Final-state double circle.
    if (isFinal) {
      canvas.drawCircle(
        position,
        radius - 8,
        border,
      );
    }

    // State label.
    _drawText(
      canvas,
      'q$state',
      position,
      fontSize: 16,
      fontWeight:
          FontWeight.bold,
      color: Colors.white,
    );

    // ========================================================
    // START INDICATOR
    // ========================================================

    if (isStart) {
      final startPoint =
          Offset(
        position.dx -
            radius -
            70,
        position.dy,
      );

      final endPoint =
          Offset(
        position.dx -
            radius -
            4,
        position.dy,
      );

      final paint =
          Paint()
            ..color =
                Colors.green
            ..strokeWidth =
                3
            ..style =
                PaintingStyle.stroke;

      canvas.drawLine(
        startPoint,
        endPoint,
        paint,
      );

      _drawArrowHead(
        canvas,
        endPoint,
        endPoint -
            startPoint,
        Colors.green,
      );

      _drawBadge(
        canvas,
        'START',
        Offset(
          position.dx -
              radius -
              68,
          position.dy -
              38,
        ),
        Colors.green,
      );
    }

    // ========================================================
    // FINAL INDICATOR
    // ========================================================

    if (isFinal) {
      _drawBadge(
        canvas,
        'FINAL',
        Offset(
          position.dx,
          position.dy +
              radius +
              42,
        ),
        Colors.red,
      );
    }
  }

  // ==========================================================
  // TRANSITION
  // ==========================================================

  void _drawTransition(
    Canvas canvas,
    Offset from,
    Offset to,
    String symbol,
    int fromState,
    int toState,
    int lane,
  ) {
    final color =
        symbol == 'ε'
            ? Colors.amber
            : Colors.white;

    // ========================================================
    // SELF LOOP
    // ========================================================

    if (fromState ==
        toState) {
      _drawSelfLoop(
        canvas,
        from,
        symbol,
        color,
      );

      return;
    }

    // IMPORTANT:
    // fromState and toState here are DISPLAY positions.
    //
    // Therefore arrows are now calculated using the new
    // q0 -> q1 -> q2 -> ... order.
    final forward =
        toState > fromState;

    final start =
        forward
            ? Offset(
                from.dx + radius,
                from.dy,
              )
            : Offset(
                from.dx - radius,
                from.dy,
              );

    final end =
        forward
            ? Offset(
                to.dx - radius,
                to.dy,
              )
            : Offset(
                to.dx + radius,
                to.dy,
              );

    final distance =
        (end.dx - start.dx)
            .abs();

    // ========================================================
    // ADJACENT FORWARD TRANSITION
    // ========================================================

    if (forward &&
        distance <= 190) {
      _drawSimpleForward(
        canvas,
        start,
        end,
        symbol,
        color,
      );

      return;
    }

    // ========================================================
    // CURVED TRANSITION
    //
    // Forward = ABOVE
    // Backward = BELOW
    // ========================================================

    final direction =
        forward
            ? -1.0
            : 1.0;

    final baseHeight =
        forward
            ? 55.0
            : 75.0;

    final curveHeight =
        baseHeight +
        (distance / 180)
                .clamp(
              0.0,
              4.0,
            ) *
            18 +
        lane * 28;

    final control =
        Offset(
      (start.dx +
              end.dx) /
          2,
      stateY +
          direction *
              curveHeight,
    );

    final path =
        Path();

    path.moveTo(
      start.dx,
      start.dy,
    );

    path.quadraticBezierTo(
      control.dx,
      control.dy,
      end.dx,
      end.dy,
    );

    final paint =
        Paint()
          ..color =
              color
          ..strokeWidth =
              2.8
          ..style =
              PaintingStyle.stroke;

    canvas.drawPath(
      path,
      paint,
    );

    // Arrowhead.
    _drawArrowHead(
      canvas,
      end,
      end - control,
      color,
    );

    // Transition label.
    _drawLabel(
      canvas,
      symbol,
      Offset(
        control.dx,
        control.dy,
      ),
      color,
    );
  }

  // ==========================================================
  // SIMPLE FORWARD TRANSITION
  // ==========================================================

  void _drawSimpleForward(
    Canvas canvas,
    Offset start,
    Offset end,
    String symbol,
    Color color,
  ) {
    final path =
        Path();

    path.moveTo(
      start.dx,
      start.dy,
    );

    path.lineTo(
      end.dx,
      end.dy,
    );

    final paint =
        Paint()
          ..color =
              color
          ..strokeWidth =
              2.8
          ..style =
              PaintingStyle.stroke;

    canvas.drawPath(
      path,
      paint,
    );

    _drawArrowHead(
      canvas,
      end,
      end - start,
      color,
    );

    _drawLabel(
      canvas,
      symbol,
      Offset(
        (start.dx +
                end.dx) /
            2,
        start.dy - 30,
      ),
      color,
    );
  }

  // ==========================================================
  // SELF LOOP
  // ==========================================================

  void _drawSelfLoop(
    Canvas canvas,
    Offset position,
    String symbol,
    Color color,
  ) {
    final paint =
        Paint()
          ..color =
              color
          ..strokeWidth =
              2.8
          ..style =
              PaintingStyle.stroke;

    final rect =
        Rect.fromCenter(
      center: Offset(
        position.dx,
        position.dy - 60,
      ),
      width: 75,
      height: 75,
    );

    canvas.drawArc(
      rect,
      math.pi * 0.15,
      math.pi * 1.65,
      false,
      paint,
    );

    final tip =
        Offset(
      position.dx + 34,
      position.dy - 82,
    );

    _drawArrowHead(
      canvas,
      tip,
      const Offset(
        -8,
        8,
      ),
      color,
    );

    _drawLabel(
      canvas,
      symbol,
      Offset(
        position.dx,
        position.dy - 125,
      ),
      color,
    );
  }

  // ==========================================================
  // ARROW HEAD
  // ==========================================================

  void _drawArrowHead(
    Canvas canvas,
    Offset tip,
    Offset direction,
    Color color,
  ) {
    final length =
        direction.distance;

    if (length < 0.1) {
      return;
    }

    final unit =
        direction / length;

    final perpendicular =
        Offset(
      -unit.dy,
      unit.dx,
    );

    const arrowLength =
        13.0;

    const arrowWidth =
        7.0;

    final p1 =
        tip -
        unit * arrowLength +
        perpendicular *
            arrowWidth;

    final p2 =
        tip -
        unit * arrowLength -
        perpendicular *
            arrowWidth;

    final path =
        Path()
          ..moveTo(
            tip.dx,
            tip.dy,
          )
          ..lineTo(
            p1.dx,
            p1.dy,
          )
          ..lineTo(
            p2.dx,
            p2.dy,
          )
          ..close();

    final paint =
        Paint()
          ..color =
              color
          ..style =
              PaintingStyle.fill;

    canvas.drawPath(
      path,
      paint,
    );
  }

  // ==========================================================
  // TRANSITION LABEL
  // ==========================================================

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset position,
    Color color,
  ) {
    final painter =
        TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight:
              FontWeight.bold,
        ),
      ),
      textDirection:
          TextDirection.ltr,
    );

    painter.layout();

    final background =
        Rect.fromCenter(
      center: position,
      width:
          painter.width + 20,
      height:
          painter.height + 12,
    );

    // Background.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        background,
        const Radius.circular(
          7,
        ),
      ),
      Paint()
        ..color =
            const Color(
          0xFF151218,
        )
        ..style =
            PaintingStyle.fill,
    );

    // Border.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        background,
        const Radius.circular(
          7,
        ),
      ),
      Paint()
        ..color =
            color
        ..strokeWidth =
            1.5
        ..style =
            PaintingStyle.stroke,
    );

    painter.paint(
      canvas,
      position -
          Offset(
            painter.width / 2,
            painter.height / 2,
          ),
    );
  }

  // ==========================================================
  // START / FINAL BADGE
  // ==========================================================

  void _drawBadge(
    Canvas canvas,
    String text,
    Offset position,
    Color color,
  ) {
    final painter =
        TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight:
              FontWeight.bold,
        ),
      ),
      textDirection:
          TextDirection.ltr,
    );

    painter.layout();

    final background =
        Rect.fromCenter(
      center: position,
      width:
          painter.width + 14,
      height:
          painter.height + 8,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        background,
        const Radius.circular(
          6,
        ),
      ),
      Paint()
        ..color =
            const Color(
          0xFF151218,
        )
        ..style =
            PaintingStyle.fill,
    );

    painter.paint(
      canvas,
      position -
          Offset(
            painter.width / 2,
            painter.height / 2,
          ),
    );
  }

  // ==========================================================
  // TEXT
  // ==========================================================

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    final painter =
        TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize:
              fontSize,
          fontWeight:
              fontWeight,
        ),
      ),
      textDirection:
          TextDirection.ltr,
    );

    painter.layout();

    painter.paint(
      canvas,
      position -
          Offset(
            painter.width / 2,
            painter.height / 2,
          ),
    );
  }

  // ==========================================================
  // STATE COUNT
  // ==========================================================

  int _stateCount() {
    int highest = 0;

    for (final t
        in nfa.transitions) {
      highest =
          math.max(
        highest,
        t.from,
      );

      highest =
          math.max(
        highest,
        t.to,
      );
    }

    return highest + 1;
  }

  @override
  bool shouldRepaint(
    covariant NfaGraphPainter
        oldDelegate,
  ) {
    return oldDelegate.nfa != nfa;
  }
}