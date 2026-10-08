import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinKeypad extends StatelessWidget {
  final int pinLength;
  final String currentPin;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool showBiometric;

  const PinKeypad({
    super.key,
    this.pinLength = 6,
    required this.currentPin,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.showBiometric = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.backspace) {
            onBackspace();
            return KeyEventResult.handled;
          }
          final digitChar = event.character;
          if (digitChar != null && digitChar.length == 1) {
            final digit = int.tryParse(digitChar);
            if (digit != null) {
              onDigit(digit);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // PIN Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pinLength, (index) {
              final isFilled = index < currentPin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: isFilled ? 18 : 14,
                height: isFilled ? 18 : 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? theme.primary : Colors.white24,
                  boxShadow: isFilled
                      ? [
                          BoxShadow(
                            color: theme.primary.withOpacity(0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                  border: Border.all(
                    color: isFilled ? theme.primary : Colors.white38,
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 36),

          // Numeric Pad Grid
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              children: [
                _buildRow(context, [1, 2, 3]),
                const SizedBox(height: 16),
                _buildRow(context, [4, 5, 6]),
                const SizedBox(height: 16),
                _buildRow(context, [7, 8, 9]),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    showBiometric && onBiometric != null
                        ? _buildActionButton(
                            icon: Icons.fingerprint,
                            color: theme.secondary,
                            onTap: onBiometric!,
                            tooltip: 'Biometric Login',
                          )
                        : const SizedBox(width: 72, height: 72),
                    _buildNumberButton(context, 0),
                    _buildActionButton(
                      icon: Icons.backspace_outlined,
                      color: Colors.white70,
                      onTap: onBackspace,
                      tooltip: 'Backspace',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<int> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildNumberButton(context, n)).toList(),
    );
  }

  Widget _buildNumberButton(BuildContext context, int number) {
    final theme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white.withOpacity(0.06),
      shape: const CircleBorder(side: BorderSide(color: Colors.white12, width: 1)),
      child: InkWell(
        customBorder: const CircleBorder(),
        splashColor: theme.primary.withOpacity(0.3),
        highlightColor: theme.primary.withOpacity(0.1),
        onTap: () => onDigit(number),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.04),
      shape: const CircleBorder(side: BorderSide(color: Colors.white10, width: 1)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}
