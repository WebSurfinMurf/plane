#!/bin/bash

# Plane Admin User Creation Script
# Creates the first admin user for Plane

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Plane Admin User Creation${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if backend container is running
if ! docker ps | grep -q plane-backend; then
    echo -e "${RED}Error: Backend container is not running${NC}"
    echo -e "${YELLOW}Please run ./deploy.sh first${NC}"
    exit 1
fi

# Get user input
echo -e "\n${YELLOW}Enter admin user details:${NC}"
read -p "Email: " admin_email
read -p "Username: " admin_username
read -p "First Name: " admin_firstname
read -p "Last Name: " admin_lastname
read -s -p "Password: " admin_password
echo
read -s -p "Confirm Password: " admin_password_confirm
echo

# Validate passwords match
if [ "$admin_password" != "$admin_password_confirm" ]; then
    echo -e "\n${RED}Error: Passwords do not match${NC}"
    exit 1
fi

# Validate email format (basic check)
if ! [[ "$admin_email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "\n${RED}Error: Invalid email format${NC}"
    exit 1
fi

# Create the admin user using Django management command
echo -e "\n${YELLOW}Creating admin user...${NC}"

docker exec plane-backend python manage.py shell <<EOF
from django.contrib.auth import get_user_model
from plane.db.models import User, Workspace, WorkspaceMember

User = get_user_model()

# Check if user already exists
if User.objects.filter(email='$admin_email').exists():
    print("User with this email already exists")
    user = User.objects.get(email='$admin_email')
    user.is_superuser = True
    user.is_staff = True
    user.save()
    print(f"Updated existing user '{user.email}' with admin privileges")
else:
    # Create new admin user
    user = User.objects.create_superuser(
        email='$admin_email',
        username='$admin_username',
        first_name='$admin_firstname',
        last_name='$admin_lastname',
        password='$admin_password'
    )
    print(f"Created admin user: {user.email}")

# Create default workspace if it doesn't exist
if not Workspace.objects.filter(owner=user).exists():
    workspace = Workspace.objects.create(
        name=f"{user.first_name}'s Workspace",
        owner=user,
        slug=f"{user.username}-workspace"
    )
    
    # Add user as workspace admin
    WorkspaceMember.objects.create(
        workspace=workspace,
        member=user,
        role=20  # Admin role
    )
    print(f"Created workspace: {workspace.name}")
else:
    print("Workspace already exists for this user")

print("Setup complete!")
EOF

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Admin User Created Successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "Admin Details:"
    echo -e "  Email:    ${BLUE}$admin_email${NC}"
    echo -e "  Username: ${BLUE}$admin_username${NC}"
    echo ""
    echo -e "You can now log in at: ${YELLOW}https://plane.ai-servicers.com${NC}"
    echo ""
    echo -e "${YELLOW}Additional Users:${NC}"
    echo "You can create more users through:"
    echo "1. The web interface (as admin)"
    echo "2. Enable self-registration in settings"
    echo "3. Run this script again with different details"
else
    echo -e "\n${RED}Failed to create admin user${NC}"
    echo -e "${YELLOW}Check the error messages above${NC}"
    exit 1
fi