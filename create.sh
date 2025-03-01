#!/bin/bash
# Description: This script is used to execute the project
####################################################################################################
# variables
####################################################################################################
# Environment variables
UPDATE_ROOT_OUTPUTS_TF_FILE=TRUE # TRUE/FALSE
TERRAFORM_APPLY="TRUE" # TRUE/FALSE/UNSET - If unset, it will ask for confirmation
UPDATE_CLOUDFRONT_DISTRIBUTION_CACHE=TRUE # TRUE/FALSE
UPDATE_S3_FILE_LIST=TRUE # TRUE/FALSE

# Directories
OUTPUTS_DIR="./outputs/" # Relative path from terraform directory to store outputs

# Scripts
UPDATE_ROOT_OUTPUTS_TF_FILE_SCRIPT="./scripts/root_outputs_tf_updater.py" # Relative path from root directory
UPDATE_S3_FILE_LIST_SCRIPT="./scripts/s3_file_list_updater.py" # Relative path from root directory

# Output files
TFVARS_FILE_PATH="./terraform/secrets.tfvars" # Relative path from root directory to secrets.tfvars file
TFPLAN_FILE="terraform_plan.txt" # Output file for terraform plan
TF_OUTPUTS_FILE="terraform_outputs.txt" # Output file for terraform outputs
LOG_FILE="terraform.log" # Log file for terraform logs
CLOUDFRONT_INVALIDATION_FILE="cloudfront_invalidation.json" # Output file for cloudfront invalidation

####################################################################################################
# Step 0: Check if the tfvars file exists and extract the file name
if [ ! -f "$TFVARS_FILE_PATH" ]; then
    echo "File $TFVARS_FILE_PATH not found."
    exit 1
else
    TFVARS_FILE=$(basename "$TFVARS_FILE_PATH")
fi

# Step 1: Update root outputs.tf file by running script
if [ "$UPDATE_ROOT_OUTPUTS_TF_FILE" == "TRUE" ]; then
    echo "Updating root outputs.tf file..."
    python3 $UPDATE_ROOT_OUTPUTS_TF_FILE_SCRIPT
    if [ $? -ne 0 ]; then
        echo "Failed to update root outputs.tf file."
        exit 1
    fi
fi

# Step 2: Update the S3 file list
if [ "$UPDATE_S3_FILE_LIST" == "TRUE" ]; then
    echo "Updating the S3 file list..."
    python3 $UPDATE_S3_FILE_LIST_SCRIPT $APP_DIR $TFVARS_FILE_PATH
    if [ $? -ne 0 ]; then
        echo "Failed to update the S3 file list."
        exit 1
    fi
fi

# Step 2: Obtain the secret ARN from AWS if it exists
if [ ! -f "$TFVARS_FILE_PATH" ]; then
    echo "File $TFVARS_FILE_PATH not found."
    exit 1
else
    SECRET_NAME=$(grep '^secrets_manager_secret_name' "$TFVARS_FILE_PATH" | sed -n 's/.*"\(.*\)".*/\1/p') # Extract secrets_manager_secret_name from the tfvars file
fi


if [ -z "$SECRET_NAME" ]; then
    echo "Secret name not found in $TFVARS_FILE_PATH."
    exit 1
else
    echo "Secret name obtained from $TFVARS_FILE_PATH: $SECRET_NAME"
    SECRET_ARN=$(aws secretsmanager list-secrets --filter Key="name",Values="$SECRET_NAME" --query "SecretList[0].ARN" --output text)
    echo "Secret ARN obtained from AWS: $SECRET_ARN"
fi

# Step 3: If the secret does not exist, then create the secret
if [[ -z "$SECRET_ARN" || "$SECRET_ARN" == "None" ]]; then
    SECRET_ARN=$(aws secretsmanager create-secret --name "$SECRET_NAME" --description "Secret for Spotify project1" --query 'ARN' --output text)
    echo "Secret created with ARN: $SECRET_ARN"
fi

# Step 4: Change to the terraform directory, initialize the terraform project and create the plan
cd terraform
terraform init
terraform plan -out=tfplan -var-file=$TFVARS_FILE
PLAN_EXIT_CODE=$?
if [ $PLAN_EXIT_CODE -ne 0 ]; then
    echo "Terraform plan failed with exit code $PLAN_EXIT_CODE."
    exit $PLAN_EXIT_CODE
fi
mkdir -p $OUTPUTS_DIR
terraform show tfplan > $OUTPUTS_DIR$TFPLAN_FILE

# Step 5: Check if we are applying the plan. If yes - appy directly, if not - exit, else ask for confirmation
if [ "$TERRAFORM_APPLY" == "TRUE" ]; then
    echo "Applying the plan..."
elif [ "$TERRAFORM_APPLY" == "FALSE" ]; then
    echo "TERRAFORM_APPLY is set to FALSE. Exiting..."
    exit 0
else
    read -p "Do you want to apply the plan? (yes/no): " APPLY_PLAN
    if [ "$APPLY_PLAN" != "yes" ]; then
        echo "Exiting..."
        exit 0
    fi
fi

# Step 6: Apply the plan
if [ "$?" -eq 0 ]; then
    # Set the log level to debug, create the logs directory and set the log path
    export TF_LOG=DEBUG
    export TF_LOG_PATH=$OUTPUTS_DIR$LOG_FILE

    terraform apply tfplan
    terraform output > $OUTPUTS_DIR$TF_OUTPUTS_FILE
    echo "Terraform apply completed successfully."

    # Step 7: If the cloudfront distribution cache needs to be updated, then create an invalidation
    if [ "$UPDATE_CLOUDFRONT_DISTRIBUTION_CACHE" == "TRUE" ]; then
    CLOUDFRONT_DISTRIBUTION_ID=$(terraform output cloudfront_distribution_id) # Extract cloudfront_distribution_id from terraform outputs
    echo "Cloudfront distribution ID obtained from terraform outputs: $CLOUDFRONT_DISTRIBUTION_ID"
        if [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
            echo "Cloudfront distribution ID not found in terraform outputs."
        else
            echo "Creating Cloudfront invalidation..."
            aws cloudfront create-invalidation --distribution-id $(echo "$CLOUDFRONT_DISTRIBUTION_ID" | tr -d '"') --paths "/*" --output json > "$OUTPUTS_DIR$CLOUDFRONT_INVALIDATION_FILE"
            if [ $? -ne 0 ]; then
                echo "Failed to create Cloudfront invalidation."
            else
                echo "Cloudfront invalidation created successfully."
            fi
        fi
    fi
else
    echo "Create.sh Failed Somewhere"
fi
