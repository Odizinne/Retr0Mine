import re
import sys

def markdown_to_steam_bbcode(markdown_text):
    markdown_text = re.sub(r'^# (.+)$', r'[h1]\1[/h1]', markdown_text, flags=re.MULTILINE)
    markdown_text = re.sub(r'^## (.+)$', r'[h2]\1[/h2]', markdown_text, flags=re.MULTILINE)
    markdown_text = re.sub(r'^### (.+)$', r'[h3]\1[/h3]', markdown_text, flags=re.MULTILINE)
    
    markdown_text = re.sub(r'^\*\*# (.+)\*\*$', r'[h1]\1[/h1]', markdown_text, flags=re.MULTILINE)
    markdown_text = re.sub(r'^\*\*## (.+)\*\*$', r'[h2]\1[/h2]', markdown_text, flags=re.MULTILINE)
    markdown_text = re.sub(r'^\*\*### (.+)\*\*$', r'[h3]\1[/h3]', markdown_text, flags=re.MULTILINE)
    
    markdown_text = re.sub(r'\*\*(.+?)\*\*', r'[b]\1[/b]', markdown_text)
    markdown_text = re.sub(r'\*(.+?)\*', r'[i]\1[/i]', markdown_text)
    
    list_items = []
    in_list = False
    bbcode_text = []
    
    for line in markdown_text.split('\n'):
        list_match = re.match(r'^[*-] (.+)$', line)
        if list_match:
            if not in_list:
                in_list = True
                list_items = []
            list_items.append(list_match.group(1))
        else:
            if in_list:
                in_list = False
                bbcode_list = "[list]\n"
                for item in list_items:
                    bbcode_list += f"    [*]{item}\n"
                bbcode_list += "[/list]"
                bbcode_text.append(bbcode_list)
            bbcode_text.append(line)
    
    if in_list:
        bbcode_list = "[list]\n"
        for item in list_items:
            bbcode_list += f"    [*]{item}\n"
        bbcode_list += "[/list]"
        bbcode_text.append(bbcode_list)
    
    list_items = []
    in_list = False
    markdown_text = '\n'.join(bbcode_text)
    bbcode_text = []
    
    for line in markdown_text.split('\n'):
        list_match = re.match(r'^(\d+)\. (.+)$', line)
        if list_match:
            if not in_list:
                in_list = True
                list_items = []
            list_items.append(list_match.group(2))
        else:
            if in_list:
                in_list = False
                bbcode_list = "[olist]\n"
                for item in list_items:
                    bbcode_list += f"    [*]{item}\n"
                bbcode_list += "[/olist]"
                bbcode_text.append(bbcode_list)
            bbcode_text.append(line)
    
    if in_list:
        bbcode_list = "[olist]\n"
        for item in list_items:
            bbcode_list += f"    [*]{item}\n"
        bbcode_list += "[/olist]"
        bbcode_text.append(bbcode_list)
    
    markdown_text = '\n'.join(bbcode_text)
    markdown_text = re.sub(r'```(?:\w+)?\n([\s\S]+?)\n```', r'[code]\1[/code]', markdown_text)
    markdown_text = re.sub(r'`([^`]+)`', r'[code]\1[/code]', markdown_text)
    
    markdown_text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'[url=\2]\1[/url]', markdown_text)
    
    markdown_text = re.sub(r'^---+$', r'[hr][/hr]', markdown_text, flags=re.MULTILINE)
    
    markdown_text = re.sub(r'~~(.+?)~~', r'[strike]\1[/strike]', markdown_text)
    
    return markdown_text

def convert_file(input_file, output_file=None):
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            markdown_content = f.read()
        
        bbcode_content = markdown_to_steam_bbcode(markdown_content)
        
        if output_file:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(bbcode_content)
            print(f"Conversion successful. Output written to {output_file}")
        else:
            output_file = input_file.rsplit('.', 1)[0] + '.bbcode'
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(bbcode_content)
            print(f"Conversion successful. Output written to {output_file}")
            
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found.")
    except Exception as e:
        print(f"Error during conversion: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python md2steam.py input_file.md [output_file.bbcode]")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    convert_file(input_file, output_file)