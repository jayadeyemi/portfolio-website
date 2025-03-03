cd infrastructure
DESTROY_LIST_FILE="./outputs/terraform_state_list.txt"
# list all resources to file
terraform state list > $DESTROY_LIST_FILE

# Confirm before removing resources
if [ -f "$DESTROY_LIST_FILE" ]; then
    cat $DESTROY_LIST_FILE
    echo "Above is the List of resources to remove from terraform state."

    read -p "remove terraform state for file: $DESTROY_LIST_FILE? (y/n): " confirm

    if [ "$confirm" == "y" ]; then
      while IFS= read -r line; do
        terraform state rm "$line"
      done < "$DESTROY_LIST_FILE"
    fi
fi

# Confirm before destroying all resources
terraform state list > $DESTROY_LIST_FILE
cat $DESTROY_LIST_FILE
echo "Above is the List of resources to remove from terraform state."
read -p "destroy all resources? (y/n): " confirm
if [ "$confirm" == "y" ]; then
    terraform destroy -var-file=./secrets.tfvars -auto-approve
fi