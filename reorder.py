import re
import os

filepath = 'clock/AddTaskView.swift'
with open(filepath, 'r') as f:
    content = f.read()

pattern = r"(VStack\(spacing: 32\) \{)(.*?)(                    \}\n                    \.padding\(32\))"

match = re.search(pattern, content, re.DOTALL)
if not match:
    print("Pattern not found!")
    exit(1)

inner_content = match.group(2)

categories_idx = inner_content.find("                        // Categories")
color_idx = inner_content.find("                        // Color Selection")
title_idx = inner_content.find("                        // Title Input")
date_idx = inner_content.find("                        // Date Selection")
time_idx = inner_content.find("                        // Time Selection")

if -1 in [categories_idx, color_idx, title_idx, date_idx, time_idx]:
    print("Could not find all sections.")
    exit(1)

categories_block = inner_content[categories_idx:color_idx]
color_block = inner_content[color_idx:title_idx]
title_block = inner_content[title_idx:date_idx]
date_block = inner_content[date_idx:time_idx]
time_block = inner_content[time_idx:]

new_inner_content = "\n" + title_block + date_block + time_block + categories_block + color_block

new_content = content[:match.start(2)] + new_inner_content + content[match.end(2):]

with open(filepath, 'w') as f:
    f.write(new_content)

print("Successfully reordered!")
