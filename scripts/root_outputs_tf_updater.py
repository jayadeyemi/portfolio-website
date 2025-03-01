import os
import re
import shutil

# Define variables
PROJECT_ROOT = "../JumpReact"
EXTRACTION_FOLDER = "../Extraction"
EXTRACTED_FILE = "../aggregated_code.txt"
OUTPUT_FILENAME = ".terraform/outputs.tf"

def main(PROJECT_ROOT=PROJECT_ROOT, EXTRACTION_FOLDER=EXTRACTION_FOLDER, EXTRACTED_FILE=EXTRACTED_FILE, OUTPUT_FILENAME=OUTPUT_FILENAME):
    """Main function to extract files from the project directory."""
    def create_extraction_folder(extraction_path):
        """Create the extraction folder if it doesn't exist."""
        if not os.path.exists(extraction_path):
            os.makedirs(extraction_path)

    def copy_files_by_extension(source_dir, dest_dir, extensions, include_subdirs=False):
        """Copy files with specified extensions from source_dir to dest_dir."""
        if include_subdirs:
            for root, _, files in os.walk(source_dir):
                for file in files:
                    if file.endswith(tuple(extensions)):
                        src_file = os.path.join(root, file)
                        dest_file = os.path.join(dest_dir, file)
                        shutil.copy2(src_file, dest_file)
                        print(f"Copied: {src_file} -> {dest_file}")
        else:
            for file in os.listdir(source_dir):
                src_file = os.path.join(source_dir, file)
                if os.path.isfile(src_file) and file.endswith(tuple(extensions)):
                    dest_file = os.path.join(dest_dir, file)
                    shutil.copy2(src_file, dest_file)
                    print(f"Copied: {src_file} -> {dest_file}")

    def copy_subfolders(source_dir, dest_dir, subfolders):
        """Copy specific subfolders from source_dir to dest_dir."""
        for subfolder in subfolders:
            src_path = os.path.join(source_dir, subfolder)
            dest_path = os.path.join(dest_dir, subfolder)
            if os.path.exists(src_path):
                shutil.copytree(src_path, dest_path, dirs_exist_ok=True)
                print(f"Copied folder: {src_path} -> {dest_path}")

    def copy_specific_file(source_dir, dest_dir, filename):
        """Copy a specific file from source_dir to dest_dir."""
        src_file = os.path.join(source_dir, filename)
        dest_file = os.path.join(dest_dir, filename)
        if os.path.exists(src_file):
            shutil.copy2(src_file, dest_file)
            print(f"Copied: {src_file} -> {dest_file}")
        else:
            print(f"File not found: {src_file}")

    def gather_files(root_directory, output_file):
        if os.path.exists(output_file):
            os.remove(output_file)
        """
        Recursively walk through the root_directory, read each file’s content,
        and append it to the output_file with the file path as a header.
        """
        with open(output_file, 'w', encoding='utf-8') as out:
            for dirpath, _, filenames in os.walk(root_directory):
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
                            out.write(f.read())
                    except Exception as e:
                        # If there's an issue reading (e.g. it's a binary file), note the error
                        out.write(f"[Error reading file: {e}]\n")

                    # Add some spacing before the next file’s content
                    out.write("\n\n")
    TERRAFORM_SUBFOLDER = os.path.join(EXTRACTION_FOLDER, "terraform")
    TERRAFORM_PATH = os.path.join(PROJECT_ROOT, "terraform")

    def update_tf_output_variables(root_directory, output_file, excluded_subfolders=None):
        if os.path.exists(output_file):
            os.remove(output_file)
        
        if excluded_subfolders is None:
            excluded_subfolders = []
        
        with open(output_file, 'w', encoding='utf-8') as out:
            for dirpath, dirnames, filenames in os.walk(root_directory):
                # Skip directories that contain any of the excluded subfolder names in their path
                if any(excluded in dirpath for excluded in excluded_subfolders):
                    continue
                
                for filename in filenames:
                    if filename.startswith("outputs_") and filename.endswith(".tf"):
                        file_path = os.path.join(dirpath, filename)
                        
                        # Determine the module name from the file's parent folder name
                        folder_name = os.path.basename(os.path.dirname(file_path))
                        
                        # Write a header for the file in the output file
                        out.write(f"# File: {file_path}\n")
                        out.write("# --------------------------------------------------\n")
                        
                        # Read the file content
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                content = f.read()
                        except Exception as e:
                            out.write(f"[Error reading file: {e}]\n")
                            continue
                        
                        # Process file content line by line
                        lines = content.splitlines(keepends=True)
                        in_output_block = False
                        current_output = None
                        new_lines = []
                        
                        for line in lines:
                            # Look for the start of an output block and capture the output variable name
                            header_match = re.match(r'^\s*output\s+"([^"]+)"\s*{', line)
                            if header_match:
                                current_output = header_match.group(1)
                                in_output_block = True
                                new_lines.append(line)
                                continue
                            
                            # When inside an output block, replace the value assignment line
                            if in_output_block and re.match(r'^\s*value\s*=.*', line):
                                indent = re.match(r'^(\s*)', line).group(1)
                                # Replace with a module reference in the format: module.<folder_name>.<variable_name>
                                new_value_line = f'{indent}value       = module.{folder_name}.{current_output}\n'
                                new_lines.append(new_value_line)
                                continue
                            
                            # Detect the end of the output block
                            if in_output_block and re.match(r'^\s*}\s*$', line):
                                in_output_block = False
                                current_output = None
                                new_lines.append(line)
                                continue
                            
                            # For all other lines, keep them unchanged
                            new_lines.append(line)
                        
                        transformed_content = ''.join(new_lines)
                        out.write(transformed_content)
                        
                        # Add spacing before the next file’s content
                        out.write("\n\n")

    create_extraction_folder(EXTRACTION_FOLDER)
    create_extraction_folder(TERRAFORM_SUBFOLDER)
    
    # Root level files
    copy_files_by_extension(PROJECT_ROOT, EXTRACTION_FOLDER, [".py", ".json"], include_subdirs=False)
    copy_files_by_extension(PROJECT_ROOT, EXTRACTION_FOLDER, [".sh", ".md"], include_subdirs=False)
    copy_subfolders(PROJECT_ROOT, EXTRACTION_FOLDER, ["app", "lambda"])

    # Terraform folder level files
    copy_subfolders(TERRAFORM_PATH, TERRAFORM_SUBFOLDER, ["modules"])
    copy_files_by_extension(TERRAFORM_PATH, TERRAFORM_SUBFOLDER, [".tf"], include_subdirs=False)
    copy_specific_file(TERRAFORM_PATH, TERRAFORM_SUBFOLDER, "secrets.tfvars")
    
    print("Extraction process completed!")
    
    # Consolidate extracted files into a single file
    gather_files(EXTRACTION_FOLDER, EXTRACTED_FILE)
    # delete the extraction folder
    shutil.rmtree(EXTRACTION_FOLDER)
    print("Done! aggregated_code.txt")
    

    update_tf_output_variables("./terraform", OUTPUT_FILENAME)
    print("Done! outputs.tf")

    
if __name__ == "__main__":
    main()


