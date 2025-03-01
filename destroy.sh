cd terraform
# list all resources
terraform state list

# Confirm before destroying all resources
read -p "destroy all resources? (y/n): " confirm
if [ "$confirm" == "y" ]; then
terraform destroy -var-file=./terraform.tfvars
fi