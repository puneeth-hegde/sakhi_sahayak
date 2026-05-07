import 'package:flutter/material.dart';
import '../services/pictogram_mapper.dart';
import '../platform/sakhi_platform.dart';
import 'package:provider/provider.dart';

class AssistResultScreen extends StatefulWidget {
  final List<StoryboardCard> cards;

  AssistResultScreen({required this.cards});

  @override
  _AssistResultScreenState createState() => _AssistResultScreenState();
}

class _AssistResultScreenState extends State<AssistResultScreen> {
  bool _hasSpoken = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasSpoken && widget.cards.isNotEmpty) {
        _speakResponse();
      }
    });
  }

  void _speakResponse() {
    final platform = Provider.of<SakhiPlatform>(context, listen: false);
    String fullText = "";
    for (var card in widget.cards) {
      fullText += "${card.text}. ";
    }
    platform.speakText(fullText, 1.0);
    if (mounted) {
      setState(() {
        _hasSpoken = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sakhi's Advice"),
        backgroundColor: Colors.purple,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.grey[100],
      body: widget.cards.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No advice could be generated for this request.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.black87),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.cards.length,
                    padding: EdgeInsets.all(16),
                    itemBuilder: (_, i) {
                      final card = widget.cards[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.purple[100],
                              child: Image.asset(
                                card.iconPath,
                                width: 24,
                                height: 24,
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(20),
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Text(
                                  card.text,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(20),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      FloatingActionButton(
                        heroTag: "replay",
                        backgroundColor: Colors.orange,
                        onPressed: () => _speakResponse(),
                        child: Icon(Icons.replay),
                      ),
                      FloatingActionButton.extended(
                        heroTag: "home",
                        backgroundColor: Colors.purple,
                        onPressed: () => Navigator.popUntil(
                          context,
                          (route) => route.isFirst,
                        ),
                        label: Text("Done"),
                        icon: Icon(Icons.check),
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }
}
