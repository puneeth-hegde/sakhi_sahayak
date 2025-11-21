import 'package:flutter/material.dart';
import '../services/pictogram_mapper.dart';
import '../platform/sakhi_platform.dart';
import 'package:provider/provider.dart';

class AssistResultScreen extends StatelessWidget {
  final List<StoryboardCard> cards;

  AssistResultScreen({required this.cards});

  @override
  Widget build(BuildContext context) {
    final platform = Provider.of<SakhiPlatform>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: Text("Your Steps"), backgroundColor: Colors.purple),
      backgroundColor: Colors.purple[50],
      body: ListView.builder(
        itemCount: cards.length,
        padding: EdgeInsets.all(16),
        itemBuilder: (_, i) {
          final card = cards[i];
          return Card(
            child: ListTile(
              leading: Image.asset(card.iconPath, width: 50, height: 50),
              title: Text(card.text),
              trailing: IconButton(
                icon: Icon(
                  Icons.play_circle_fill,
                  size: 32,
                  color: Colors.purple,
                ),
                onPressed: () => platform.speakText(card.text, 1.0),
              ),
            ),
          );
        },
      ),
    );
  }
}
