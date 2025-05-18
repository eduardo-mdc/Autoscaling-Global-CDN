
echo
echo -e "${YELLOW}PHASE 2: ADMIN VM CONFIGURATION${NC}"
echo -e "${YELLOW}=====================================${NC}"

# Configure admin VM with Ansible
echo -e "${GREEN}Configuring admin VM with Ansible...${NC}"
cd "${PLAYBOOKS_DIR}"
ansible-playbook admin.yml

echo
echo -e "${YELLOW}PHASE 3: KUBERNETES DEPLOYMENT${NC}"
echo -e "${YELLOW}=====================================${NC}"

# Deploy Kubernetes applications
echo -e "${GREEN}Deploying Kubernetes applications...${NC}"
cd "${PLAYBOOKS_DIR}"
ansible-playbook k8s.yml -e "docker_hub_image=${DOCKER_HUB_IMAGE}" -e "docker_hub_tag=${DOCKER_HUB_TAG}"

echo
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Admin VM IP: ${ADMIN_IP}${NC}"
echo -e "${GREEN}SSH command: ssh -i ${SSH_PRIVATE_KEY} ${ADMIN_USERNAME}@${ADMIN_IP}${NC}"

# Get load balancer IP
cd "${TERRAFORM_DIR}"
LB_IP=$(terraform output -raw load_balancer_ip)
echo -e "${GREEN}Load Balancer IP: ${LB_IP}${NC}"
echo -e "${GREEN}Streaming server is available at: http://${LB_IP}${NC}"