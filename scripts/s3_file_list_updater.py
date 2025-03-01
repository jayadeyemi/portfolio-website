import os
import re
import sys

def list_relative_paths(app_dir):
    """
    Walks through the app_dir and returns a sorted list of all file paths relative to app_dir.
    """
    relative_paths = []
    for root, dirs, files in os.walk(app_dir):
        for file in files:
            full_path = os.path.join(root, file)
            rel_path = os.path.relpath(full_path, app_dir)
            relative_paths.append(rel_path)
    return sorted(relative_paths)

def get_app_dir_from_tfvars(tfvars_file):
    """
    Reads the tfvars file, extracts the 'frontend_path' value,
    removes the first dot if it exists, and returns it.
    """
    with open(tfvars_file, "r", encoding="utf-8") as f:
        content = f.read()
    
    match = re.search(r'frontend_path\s*=\s*"(.*?)"', content)
    if match:
        app_dir = match.group(1)
        # Remove the first dot if present.
        if app_dir.startswith(".."):
            app_dir = app_dir[1:]
        return app_dir
    else:
        print("Error: 'frontend_path' not found in the tfvars file.")
        sys.exit(1)

def update_secrets_file(secrets_file, file_list):
    """
    Reads the secrets file, replaces the s3_file_list block with a new block
    containing the file_list, and writes the updated content back.
    """
    with open(secrets_file, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Build the new s3_file_list block.
    new_list_lines = "s3_file_list = [\n"
    for path in file_list:
        new_list_lines += f'  "{path}",\n'
    new_list_lines += "]"
    
    # Use regex to replace the existing s3_file_list block.
    new_content, count = re.subn(
        r"s3_file_list\s*=\s*\[.*?\]",
        new_list_lines,
        content,
        flags=re.DOTALL
    )
    
    if count == 0:
        print("No s3_file_list block found in the secrets file. Appending it at the end.")
        new_content += "\n" + new_list_lines
    
    with open(secrets_file, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("Updated secrets file with the new s3_file_list.")



def main():
    if len(sys.argv) < 2:
        print("Usage: python3 update_s3_file_list.py <TFVARS_FILE>")
        sys.exit(1)

    secrets_file = sys.argv[1]
    app_dir = get_app_dir_from_tfvars(secrets_file)

    # List all relative file paths under the app_dir.
    file_list = list_relative_paths(app_dir)
    if not file_list:
        print("No files found in the app directory. Check the path in the tfvars file.")
        sys.exit(1)
    print("Found the following files:")
    for path in file_list:
        print("  ", path)
    
    # Update the secrets file with the new list.
    update_secrets_file(secrets_file, file_list)

if __name__ == "__main__":
    main()
