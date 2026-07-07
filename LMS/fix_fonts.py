import os
import re

directory = '/Users/apple/Desktop/Sprint 1/LMS/LMS'
for root, dirs, files in os.walk(directory):
    for filename in files:
        if filename.endswith('.swift'):
            filepath = os.path.join(root, filename)
            with open(filepath, 'r') as f:
                content = f.read()
            
            # Regex: \.font\( (anything not containing .fontDesign) \.fontDesign\( (\.[a-zA-Z]+) \) \)
            # Replace with: .font(\1).fontDesign(\2)
            new_content = re.sub(r'\.font\(((?:(?!\.fontDesign).)*?)\.fontDesign\((\.[a-zA-Z]+)\)\)', r'.font(\1).fontDesign(\2)', content)
            
            if new_content != content:
                print(f"Fixed {filepath}")
                with open(filepath, 'w') as f:
                    f.write(new_content)
