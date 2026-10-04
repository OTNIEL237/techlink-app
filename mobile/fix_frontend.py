import os
import re

def fix_flutter_code(directory):
    count_catches = 0
    count_prints = 0
    count_buttons = 0

    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Fix empty catch blocks: catch (_) {} or catch (e) {}
                # Be careful not to replace multi-line empty catches or single-line.
                # Regex for `catch (_) {}` or `catch(e) {}` or `catch (e) { }`
                new_content, n_catches = re.subn(r'catch\s*\([^)]+\)\s*\{\s*\}', r"catch (e) { print('Erreur silencieuse interceptée: $e'); }", content)
                count_catches += n_catches

                # Replace empty onPressed: () {} with a snackbar.
                # Only if the file imports flutter/material.dart
                if 'package:flutter/material.dart' in new_content:
                    snackbar_code = r"onPressed: () { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚧 Fonctionnalité bientôt disponible'))); }"
                    # Match `onPressed: () {},` or `onPressed: () {}`
                    new_content, n_buttons = re.subn(r'onPressed:\s*\(\)\s*\{\s*\},?', snackbar_code + ',', new_content)
                    count_buttons += n_buttons

                if new_content != content:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)

    print(f"Fixed {count_catches} empty catch blocks.")
    print(f"Fixed {count_buttons} empty onPressed buttons.")

if __name__ == '__main__':
    fix_flutter_code('c:/Users/Lenovo/techlink-app/mobile/lib')
