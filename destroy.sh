cd infrastructure
# list all resources to file
terraform state list > ./outputs/terraform_state_list.txt

# remove specific resources
if grep -q "random_integer.random_id" ./outputs/terraform_state_list.txt; then
    terraform state rm random_integer.random_id
fi

# Confirm before destroying all resources
read -p "destroy all resources? (y/n): " confirm
if [ "$confirm" == "y" ]; then
    terraform destroy -var-file=./secrets.tfvars -auto-approve
fi