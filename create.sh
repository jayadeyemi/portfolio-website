#!/bin/bash

# Description: This script is used to execute the terraform plan and apply the changes to the AWS account.
# Usage: ./execute.sh

# Step 0: Update root outputs.tf file by ruuning script
#run update_root_outputs_tf.py
# exit when the script fails

echo "Updating root outputs.tf file..."
python3 update_root_outputs_tf.py
if [ $? -ne 0 ]; then
    echo "Failed to update root outputs.tf file."
    exit 1
fi
# Path to your tfvars file
tfvars_file="./terraform/secrets.tfvars"

# Extract the value of secrets_manager_secret_name from the file
secret_name=$(grep '^secrets_manager_secret_name' "$tfvars_file" | sed -n 's/.*"\(.*\)".*/\1/p')

# Step 1: Check if the secret exists in the AWS Secrets Manager service and get the secret arn
secret_arn=$(aws secretsmanager list-secrets --filter Key="name",Values="$secret_name" --query "SecretList[0].ARN" --output text)
echo $secret_arn

# Step 2: Check if the secret does not exist, then create the secret
if [[ -z "$secret_arn" || "$secret_arn" == "None" ]]; then
    secret_arn=$(aws secretsmanager create-secret --name "$secret_name" --description "Secret for Spotify project1" --query 'ARN' --output text)
    echo "Secret created with ARN: $secret_arn"
else
    echo "Secret already exists with ARN: $secret_arn"
fi

# Step 3: Change to the terraform directory and initialize the terraform
cd terraform
terraform init

terraform plan -out=tfplan -var-file=secrets.tfvars

# Step 5: Prompt the user to confirm the plan
read -p "Do you want to apply the plan? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    exit 0
fi

# Step 6: Set the log level to debug, create the logs directory and set the log path
export TF_LOG=DEBUG
mkdir -p ./logs
export TF_LOG_PATH=./logs/terraform_debug.log

# Step 7: Apply the plan
terraform apply tfplan