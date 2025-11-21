class StoryboardCard {
  final int id;
  final String text;
  final String iconPath;

  StoryboardCard({
    required this.id,
    required this.text,
    required this.iconPath,
  });
}

class PictogramMapper {
  static final Map<String, String> _icons = {
    'help': 'assets/icons/help.png',
    'call': 'assets/icons/phone.png',
    'phone': 'assets/icons/phone.png',
    'fever': 'assets/icons/thermometer.png',
    'temperature': 'assets/icons/thermometer.png',
    'hospital': 'assets/icons/hospital.png',
    'doctor': 'assets/icons/doctor.png',
    'safe': 'assets/icons/shield.png',
    'danger': 'assets/icons/warning.png',
    'warning': 'assets/icons/warning.png',
    'people': 'assets/icons/people.png',
  };

  List<StoryboardCard> mapStepsToCards(List steps) {
    final List<StoryboardCard> cards = [];
    for (var step in steps) {
      final text = step['text'] ?? "";
      final icon = _findIcon(text);
      cards.add(StoryboardCard(id: step['id'], text: text, iconPath: icon));
    }
    return cards;
  }

  String _findIcon(String text) {
    final t = text.toLowerCase();
    for (final e in _icons.entries) {
      if (t.contains(e.key)) return e.value;
    }
    return 'assets/icons/action.png';
  }
}
