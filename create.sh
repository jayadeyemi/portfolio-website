# Description: This script is used to execute the terraform plan and apply the changes to the AWS account.
# Usage: ./execute.sh

# Step 1: Check if the secret exists in the AWS Secrets Manager service and get the secret arn
secret_arn=$(aws secretsmanager list-secrets --filter Key="name",Values="SpotifyCredentials" --query "SecretList[0].ARN" --output text)
echo $secret_arn

# Step 2: Check if the secret does not exist, then create the secret
if [ -z "$secret_arn" ]; then
    secret_arn=$(aws secretsmanager create-secret --name SpotifyCredentials --secret-string '{}' --query ARN --output text)
    echo $secret_arn
fi

# Step 3: Change to the terraform directory and initialize the terraform
cd terraform
terraform init

# Step 4: Import the existing secret into the terraform state and create the plan
terraform import module.secretsmanager.aws_secretsmanager_secret.spotify_secret $secret_arn
terraform plan -out=tfplan -var-file=terraform.tfvars

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