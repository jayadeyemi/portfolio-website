import os
import re
import sys
import shutil

# Define variables
if len(sys.argv) < 5:
    print("Usage: python3 root_outputs_tf_updater.py <PROJECT_ROOT> <EXTRACTION_FOLDER> <EXTRACTED_FILE> <INFRASTRUCTURE_FOLDER>")
    sys.exit(1)

PROJECT_ROOT = sys.argv[1]
EXTRACTION_FOLDER = sys.argv[2]
EXTRACTED_FILE = sys.argv[3]
INFRASTRUCTURE_FOLDER = sys.argv[4]
IAC_FOLDER_NAME = INFRASTRUCTURE_FOLDER.replace("./", "")
OUTPUT_FILENAME = os.path.join(INFRASTRUCTURE_FOLDER, "outputs.tf")

# Debug print for initial variables
# print(f"DEBUG: PROJECT_ROOT: {PROJECT_ROOT}")
# print(f"DEBUG: EXTRACTION_FOLDER: {EXTRACTION_FOLDER}")
# print(f"DEBUG: EXTRACTED_FILE: {EXTRACTED_FILE}")
# print(f"DEBUG: INFRASTRUCTURE_FOLDER: {INFRASTRUCTURE_FOLDER}")
# print(f"DEBUG: IAC_FOLDER_NAME: {IAC_FOLDER_NAME}")
# print(f"DEBUG: OUTPUT_FILENAME: {OUTPUT_FILENAME}")

def main(PROJECT_ROOT=PROJECT_ROOT, EXTRACTION_FOLDER=EXTRACTION_FOLDER, EXTRACTED_FILE=EXTRACTED_FILE, OUTPUT_FILENAME=OUTPUT_FILENAME, INFRASTRUCTURE_FOLDER=INFRASTRUCTURE_FOLDER, IAC_FOLDER_NAME=IAC_FOLDER_NAME):
    """Main function to extract files from the project directory."""
    
    def create_extraction_folder(extraction_path):
        """Create the extraction folder if it doesn't exist."""
        if not os.path.exists(extraction_path):
            # print(f"DEBUG: Creating extraction folder: {extraction_path}")
            os.makedirs(extraction_path)


    def copy_files_by_extension(source_dir, dest_dir, extensions, include_subdirs=False):
        """Copy files with specified extensions from source_dir to dest_dir."""
        # print(f"DEBUG: copy_files_by_extension: source_dir={source_dir}, dest_dir={dest_dir}, extensions={extensions}, include_subdirs={include_subdirs}")
        if include_subdirs:
            for root, _, files in os.walk(source_dir):
                for file in files:
                    if file.endswith(tuple(extensions)):
                        src_file = os.path.join(root, file)
                        dest_file = os.path.join(dest_dir, file)
                        # print(f"DEBUG: Copying file from {src_file} to {dest_file}")
                        shutil.copy2(src_file, dest_file)
                        print(f"Copied: {src_file} -> {dest_file}")
        else:
            for file in os.listdir(source_dir):
                src_file = os.path.join(source_dir, file)
                if os.path.isfile(src_file) and file.endswith(tuple(extensions)):
                    dest_file = os.path.join(dest_dir, file)
                    # print(f"DEBUG: Copying file from {src_file} to {dest_file}")
                    shutil.copy2(src_file, dest_file)
                    print(f"Copied: {src_file} -> {dest_file}")

    def copy_subfolders(source_dir, dest_dir, subfolders):
        """Copy specific subfolders from source_dir to dest_dir."""
        # print(f"DEBUG: copy_subfolders: source_dir={source_dir}, dest_dir={dest_dir}, subfolders={subfolders}")
        for subfolder in subfolders:
            src_path = os.path.join(source_dir, subfolder)
            dest_path = os.path.join(dest_dir, subfolder)
            # print(f"DEBUG: Preparing to copy subfolder from {src_path} to {dest_path}")
            if os.path.exists(src_path):
                shutil.copytree(src_path, dest_path, dirs_exist_ok=True)
                print(f"Copied folder: {src_path} -> {dest_path}")
            else:
                print(f"WARNING: Subfolder not found: {src_path}")

    def copy_specific_file(source_dir, dest_dir, filename):
        """Copy a specific file from source_dir to dest_dir."""
        src_file = os.path.join(source_dir, filename)
        dest_file = os.path.join(dest_dir, filename)
        # print(f"DEBUG: copy_specific_file: source file: {src_file}, destination file: {dest_file}")
        if os.path.exists(src_file):
            shutil.copy2(src_file, dest_file)
            print(f"Copied: {src_file} -> {dest_file}")
        else:
            print(f"File not found: {src_file}")

    def gather_files(root_directory, output_file):
        if os.path.exists(output_file):
            # print(f"DEBUG: Removing existing output file: {output_file}")
            os.remove(output_file)
        # print(f"DEBUG: Gathering files from {root_directory} into {output_file}")
        with open(output_file, 'w', encoding='utf-8') as out:
            for dirpath, _, filenames in os.walk(root_directory):
                # print(f"DEBUG: Walking through directory: {dirpath}")
                for filename in filenames:
                    file_path = os.path.join(dirpath, filename)
                    # Optionally skip the output file if it happens to reside in the same folder
                    if file_path == os.path.abspath(output_file):
                        continue
                    # Write a header for the file
                    out.write(f"# File: {file_path}\n")
                    out.write("# --------------------------------------------------\n")
                    # Read and write the file contents
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            out.write(content)
                    except Exception as e:
                        out.write(f"[Error reading file: {e}]\n")
                    # Add some spacing before the next file’s content
                    out.write("\n\n")

    # Calculate Terraform paths and print debug info
    TERRAFORM_SUBFOLDER = os.path.join(EXTRACTION_FOLDER, IAC_FOLDER_NAME)
    TERRAFORM_PATH = os.path.join(PROJECT_ROOT, IAC_FOLDER_NAME)
    # print(f"DEBUG: TERRAFORM_SUBFOLDER: {TERRAFORM_SUBFOLDER}")
    # print(f"DEBUG: TERRAFORM_PATH: {TERRAFORM_PATH}")

    def update_tf_output_variables(root_directory, output_file, excluded_subfolders=None):
        if os.path.exists(output_file):
            # print(f"DEBUG: Removing existing output file: {output_file}")
            os.remove(output_file)
        
        if excluded_subfolders is None:
            excluded_subfolders = []
        
        # print(f"DEBUG: Updating TF output variables in {root_directory} into {output_file}")
        with open(output_file, 'w', encoding='utf-8') as out:
            for dirpath, dirnames, filenames in os.walk(root_directory):
                # print(f"DEBUG: Processing directory: {dirpath}")
                if any(excluded in dirpath for excluded in excluded_subfolders):
                    # print(f"DEBUG: Skipping excluded directory: {dirpath}")
                    continue
                
                for filename in filenames:
                    if filename.startswith("outputs_") and filename.endswith(".tf"):
                        file_path = os.path.join(dirpath, filename)
                        folder_name = os.path.basename(os.path.dirname(file_path))
                        # print(f"DEBUG: Processing file: {file_path} in folder: {folder_name}")
                        out.write(f"# File: {file_path}\n")
                        out.write("# --------------------------------------------------\n")
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                content = f.read()
                        except Exception as e:
                            out.write(f"[Error reading file: {e}]\n")
                            continue
                        lines = content.splitlines(keepends=True)
                        in_output_block = False
                        current_output = None
                        new_lines = []
                        for line in lines:
                            header_match = re.match(r'^\s*output\s+"([^"]+)"\s*{', line)
                            if header_match:
                                current_output = header_match.group(1)
                                in_output_block = True
                                # print(f"DEBUG: Found output block for variable: {current_output}")
                                new_lines.append(line)
                                continue
                            if in_output_block and re.match(r'^\s*value\s*=.*', line):
                                indent = re.match(r'^(\s*)', line).group(1)
                                new_value_line = f'{indent}value       = module.{folder_name}.{current_output}\n'
                                # print(f"DEBUG: Replacing line with: {new_value_line.strip()}")
                                new_lines.append(new_value_line)
                                continue
                            if in_output_block and re.match(r'^\s*}\s*$', line):
                                in_output_block = False
                                current_output = None
                                new_lines.append(line)
                                continue
                            new_lines.append(line)
                        transformed_content = ''.join(new_lines)
                        out.write(transformed_content)
                        out.write("\n\n")

    create_extraction_folder(EXTRACTION_FOLDER)
    create_extraction_folder(TERRAFORM_SUBFOLDER)
    
    # print("DEBUG: Copying root level files")
    copy_files_by_extension(PROJECT_ROOT, EXTRACTION_FOLDER, [".py", ".json"], include_subdirs=False)
    copy_files_by_extension(PROJECT_ROOT, EXTRACTION_FOLDER, [".sh", ".md"], include_subdirs=False)
    copy_subfolders(PROJECT_ROOT, EXTRACTION_FOLDER, ["app", "lambda"])
    
    # print("DEBUG: Copying Terraform folder level files")
    copy_subfolders(TERRAFORM_PATH, TERRAFORM_SUBFOLDER, ["modules"])
    copy_files_by_extension(TERRAFORM_PATH, TERRAFORM_SUBFOLDER, [".tf"], include_subdirs=False)
    copy_specific_file(TERRAFORM_PATH, TERRAFORM_SUBFOLDER, "secrets.tfvars")
    
    # print("DEBUG: Extraction process completed!")
    
    gather_files(EXTRACTION_FOLDER, EXTRACTED_FILE)
    # print("DEBUG: Deleting extraction folder: " + EXTRACTION_FOLDER)
    shutil.rmtree(EXTRACTION_FOLDER)
    print("Done! aggregated_code.txt")
    
    update_tf_output_variables(INFRASTRUCTURE_FOLDER, OUTPUT_FILENAME)
    print("Done! outputs.tf")
    
if __name__ == "__main__":
    main()
