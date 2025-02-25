cd terraform
# list all resources
terraform state list
read -p "Remove secret resource? (y/n): " confirm
if [ "$confirm" == "y" ]; then
terraform state rm module.secretsmanager.aws_secretsmanager_secret.spotify_secret
fi

read -p "Remove random_id resource? (y/n): " confirm
if [ "$confirm" == "y" ]; then
terraform state rm random_integer.random_id
fi

read -p "destroy all resources? (y/n): " confirm
if [ "$confirm" == "y" ]; then
terraform destroy -var-file=./terraform.tfvars
fi