#!/bin/bash
# Description: This script is used to execute the project
####################################################################################################
# Variables
####################################################################################################
# Execution Code
FOUR_DIGIT_EXECUTION_CODE=1111 #0/1, 0/1, Any Number, 0/1
    # Explanation:
    # 1st digit: Update S3 file list in the tfvars file? (using files in the app directory): Yes/No
    # 2nd digit: Update outputs.tf in terraform root? (using outputs in the terraform modules): Yes/No
    # 3rd digit: Terraform apply? (using the plan file): Yes/No/Ask
    # 4th digit: Update Cloudfront distribution cache?: Yes/No

# External Directories
PROJECT_ROOT="../portfolio-website"     # Root directory of the project (no trailing slash)
EXTRACTION_FOLDER="./Extraction"        # Extraction folder for the aggregated code (no trailing slash)
EXTRACTED_FILE="../aggregated_code.txt" # Extracted file from the extraction folder

# Internal Directories
IAC_DIR="./infrastructure/" # Relative path from root directory to infrastructure directory (trailing slash)
SCRIPTS_DIR="./scripts/"    # Relative path from root directory to scripts directory (trailing slash)
OUTPUTS_DIR="./outputs/"    # Relative path from IAC directory to store outputs (trailing slash)

# Scripts
ROOT_OUTPUTS_TF_UPDATER="root_outputs_tf_updater.py" # Relative path from scripts directory
S3_FILE_LIST_UPDATER="s3_file_list_updater.py"       # Relative path from scripts directory
EXCLUDED_TF_FOLDERS=""decouplers", "triggers""       # List of folders to exclude by root_outputs_tf_updater.py

# Output files
TFVARS_FILE="secrets.tfvars"                                # Secrets file for terraform variables
TFPLAN_FILE="terraform_plan.txt"                            # Output file for terraform plan
TF_OUTPUTS_FILE="terraform_outputs.txt"                     # Output file for terraform outputs
LOG_FILE="execution.log"                                    # Log file for terraform logs
CLOUDFRONT_INVALIDATION_FILE="cloudfront_invalidation.json" # Output file for cloudfront invalidation
TERRAFORM_STATE_LIST_FILE="terraform_state_list.txt"        # Output file for terraform state list

####################################################################################################
# Execution
####################################################################################################
# Step 0: Initialize variables
TFVARS_FILE_PATH=$IAC_DIR$TFVARS_FILE
UPDATE_ROOT_OUTPUTS_TF_FILE_SCRIPT=$SCRIPTS_DIR$ROOT_OUTPUTS_TF_UPDATER
UPDATE_S3_FILE_LIST_SCRIPT=$SCRIPTS_DIR$S3_FILE_LIST_UPDATER

if [[ $FOUR_DIGIT_EXECUTION_CODE =~ ^[0-9]{4}$ ]]; then
    # Extract the execution code only if it is a 4-digit number
    UPDATE_S3_FILE_LIST=${FOUR_DIGIT_EXECUTION_CODE:0:1}
    UPDATE_ROOT_OUTPUTS_TF_FILE=${FOUR_DIGIT_EXECUTION_CODE:1:1}
    TERRAFORM_APPLY=${FOUR_DIGIT_EXECUTION_CODE:2:1}
    UPDATE_CLOUDFRONT_DISTRIBUTION_CACHE=${FOUR_DIGIT_EXECUTION_CODE:3:1}
else
    # Set default values
    UPDATE_S3_FILE_LIST="0"
    UPDATE_ROOT_OUTPUTS_TF_FILE="0"
    TERRAFORM_APPLY=""
    UPDATE_CLOUDFRONT_DISTRIBUTION_CACHE="0"
fi

# Step 1: Update root outputs.tf file by running script (if required)
if [ "$UPDATE_ROOT_OUTPUTS_TF_FILE" == "1" ]; then
    python3 $UPDATE_ROOT_OUTPUTS_TF_FILE_SCRIPT $PROJECT_ROOT $EXTRACTION_FOLDER $EXTRACTED_FILE $IAC_DIR $TFVARS_FILE $EXCLUDED_TF_FOLDERS
    if [ $? -ne 0 ]; then
        echo "File $UPDATE_ROOT_OUTPUTS_TF_FILE not found at $UPDATE_ROOT_OUTPUTS_TF_FILE_SCRIPT."
        exit 1
    fi
fi

# Step 2: Update the S3 file list in the tfvars file by running script (if required)
if [ "$UPDATE_S3_FILE_LIST" == "1" ]; then
    echo "Updating the S3 file list..."
    python3 $UPDATE_S3_FILE_LIST_SCRIPT $APP_DIR $TFVARS_FILE_PATH
    if [ $? -ne 0 ]; then
        echo "File $UPDATE_S3_FILE_LIST_FILE not found at $UPDATE_S3_FILE_LIST_SCRIPT."
        exit 1
    fi
fi

# Step 3: Get the secret ARN from AWS using the secret name
# if the secret file is at the expected path
if [ ! -f "$TFVARS_FILE_PATH" ]; then
    echo "File $TFVARS_FILE not found at $TFVARS_FILE_PATH."
    exit 1
else
    # Extract the secret name from the tfvars file
    TFVARS_FILE=$(basename "$TFVARS_FILE_PATH")
    SECRET_NAME=$(grep '^secrets_manager_secret_name' "$TFVARS_FILE_PATH" | sed -n 's/.*"\(.*\)".*/\1/p') # Extract secrets_manager_secret_name from the tfvars file
    if [ -z "$SECRET_NAME" ]; then
        # Get the secret ARN from AWS using the secret name
        echo "Secret name not found in $TFVARS_FILE_PATH."
        exit 1
    else
        # Get the secret ARN from AWS using the secret name
        echo "Secret name obtained from $TFVARS_FILE_PATH: $SECRET_NAME"
        SECRET_ARN=$(aws secretsmanager list-secrets --filter Key="name",Values="$SECRET_NAME" --query "SecretList[0].ARN" --output text)
        echo "Secret ARN obtained from AWS: $SECRET_ARN"
        # If the secret does not exist, then create the secret
        if [[ -z "$SECRET_ARN" || "$SECRET_ARN" == "None" ]]; then
            SECRET_ARN=$(aws secretsmanager create-secret --name "$SECRET_NAME" --description "Secret for Spotify project" --query 'ARN' --output text)
            echo "Secret created with ARN: $SECRET_ARN"
        fi
    fi
fi

# Step 4: Change to the terraform directory, initialize the terraform project and create the plan
cd $IAC_DIR
terraform init
terraform state list > $OUTPUTS_DIR$TERRAFORM_STATE_LIST_FILE
terraform plan -out=tfplan -var-file=$TFVARS_FILE

if [ $? -ne 0 ]; then
    echo "Terraform plan failed with exit code $?. Exiting..."
    exit 1
fi

mkdir -p $OUTPUTS_DIR
terraform show tfplan > $OUTPUTS_DIR$TFPLAN_FILE

# Terraform apply function
function terraform_apply() {
    # Set the log level to debug
    export TF_LOG=DEBUG
    # Remove the log file if it already exists
    if [ -f $OUTPUTS_DIR$LOG_FILE ]; then
        rm -f $OUTPUTS_DIR$LOG_FILE
    fi
    # Set the log path
    export TF_LOG_PATH=$OUTPUTS_DIR$LOG_FILE
    # Apply the plan
    terraform apply tfplan
    # Save the terraform outputs to a file
    terraform output > $OUTPUTS_DIR$TF_OUTPUTS_FILE
    echo "Terraform apply completed successfully."
    # Save the terraform state list to a file
    terraform state list > $OUTPUTS_DIR$TERRAFORM_STATE_LIST_FILE
}

# Step 5: Check if we are applying the plan. If yes - apply directly, if not - exit, else ask for confirmation
if [ "$TERRAFORM_APPLY" == "1" ]; then
    terraform_apply
elif [ "$TERRAFORM_APPLY" == "0" ]; then
    echo "TERRAFORM_APPLY is set to FALSE. Continuing without applying the plan."
else
    read -p "Do you want to apply the plan? (yes/no): " APPLY_PLAN
    if [ "$APPLY_PLAN" == "yes" ]; then
        terraform_apply
    fi
fi

# Step 6: Update the Cloudfront distribution cache (if required)
if [ "$UPDATE_CLOUDFRONT_DISTRIBUTION_CACHE" == "1" ]; then
    # Extract the cloudfront_distribution_id from terraform outputs
    CLOUDFRONT_DISTRIBUTION_ID=$(terraform output cloudfront_distribution_id) # Extract cloudfront_distribution_id from terraform outputs
    echo "Cloudfront distribution ID obtained from terraform outputs: $CLOUDFRONT_DISTRIBUTION_ID"
    if [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
        echo "Cloudfront distribution ID not found in terraform outputs."
    else
        # Create a Cloudfront invalidation if the distribution ID is found
        aws cloudfront create-invalidation --distribution-id $(echo "$CLOUDFRONT_DISTRIBUTION_ID" | tr -d '"') --paths "/*" --output json > "$OUTPUTS_DIR$CLOUDFRONT_INVALIDATION_FILE"
        if [ $? -ne 0 ]; then
            echo "Failed to create Cloudfront invalidation."
        else
            echo "Cloudfront invalidation created successfully. Wait for invalidation to complete."
        fi
    fi
fi
