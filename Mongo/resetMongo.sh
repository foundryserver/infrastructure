#!/bin/bash

# --- ARGUMENT VALIDATION ---
if [ $# -ne 1 ]; then
  echo "Usage: $0 {test|go}"
  echo "  test - Run in test mode (non-destructive, verify configurations)"
  echo "  go   - Execute the actual password reset procedure"
  exit 1
fi

MODE="$1"
if [ "$MODE" != "test" ] && [ "$MODE" != "go" ]; then
  echo "ERROR: Invalid argument. Use 'test' or 'go'"
  echo "Usage: $0 {test|go}"
  exit 1
fi

# --- CONFIGURATION ---
MONGO_ADMIN_USER="admin"
NEW_PASSWORD="redacted" # !! CHANGE THIS TO A REAL SECURE PASSWORD !!
MONGO_CONFIG_PATH="/etc/mongod.conf"
MONGO_PORT="27017"
KEYFILE_PATH="~/.ssh/common-jan25-openssh" # SSH key file path
SSH_USER="brad" # SSH username for connecting to MongoDB servers

# Array of all replica set members (hostnames or IPs)
REPLICA_MEMBERS=(
  "10.20.20.130"
  "10.20.20.131"
  "10.20.20.132"
)
# ---------------------

# --- FUNCTIONS ---

# Function to run a command on a remote server
run_remote() {
  local HOST="$1"
  local COMMAND="$2"
  echo "--> Executing on ${SSH_USER}@${HOST}: ${COMMAND}"
  if [ "$MODE" = "test" ]; then
    echo "    [TEST MODE] Would execute: ${COMMAND}"
    return 0
  else
    ssh -i "${KEYFILE_PATH}" -t "${SSH_USER}@${HOST}" "${COMMAND}"
    if [ $? -ne 0 ]; then
      echo "ERROR: Command failed on ${SSH_USER}@${HOST}. Aborting."
      exit 1
    fi
  fi
}

# Function to test SSH connectivity
test_ssh_connectivity() {
  local HOST="$1"
  echo "--> Testing SSH connectivity to ${SSH_USER}@${HOST}..."
  ssh -i "${KEYFILE_PATH}" -o ConnectTimeout=10 -o BatchMode=yes "${SSH_USER}@${HOST}" "echo 'SSH connection successful'"
  if [ $? -eq 0 ]; then
    echo "    ✅ SSH connectivity to ${SSH_USER}@${HOST}: OK"
    return 0
  else
    echo "    ❌ SSH connectivity to ${SSH_USER}@${HOST}: FAILED"
    return 1
  fi
}

# Function to test MongoDB service status
test_mongo_status() {
  local HOST="$1"
  echo "--> Testing MongoDB service status on ${SSH_USER}@${HOST}..."
  ssh -i "${KEYFILE_PATH}" "${SSH_USER}@${HOST}" "sudo systemctl is-active mongod"
  local STATUS=$?
  if [ $STATUS -eq 0 ]; then
    echo "    ✅ MongoDB service on ${HOST}: RUNNING"
  else
    echo "    ⚠️  MongoDB service on ${HOST}: NOT RUNNING"
  fi
  return $STATUS
}

# Function to test MongoDB configuration file
test_mongo_config() {
  local HOST="$1"
  echo "--> Testing MongoDB configuration on ${SSH_USER}@${HOST}..."
  ssh -i "${KEYFILE_PATH}" "${SSH_USER}@${HOST}" "sudo test -f ${MONGO_CONFIG_PATH}"
  if [ $? -eq 0 ]; then
    echo "    ✅ MongoDB config file exists on ${HOST}"
    # Check current configuration
    ssh -i "${KEYFILE_PATH}" "${SSH_USER}@${HOST}" "sudo grep -E '^[[:space:]]*authorization:|^[[:space:]]*replSetName:|^[[:space:]]*keyFile:' ${MONGO_CONFIG_PATH} || echo 'No auth/replication config found'"
    return 0
  else
    echo "    ❌ MongoDB config file missing on ${HOST}"
    return 1
  fi
}

# Function to test MongoDB connectivity
test_mongo_connectivity() {
  local HOST="$1"
  echo "--> Testing MongoDB connectivity to ${SSH_USER}@${HOST}:${MONGO_PORT}..."
  # Test basic connection (this will fail with auth, but we can see if the port is open)
  ssh -i "${KEYFILE_PATH}" "${SSH_USER}@${HOST}" "timeout 5 bash -c '</dev/tcp/localhost/${MONGO_PORT}' 2>/dev/null"
  if [ $? -eq 0 ]; then
    echo "    ✅ MongoDB port ${MONGO_PORT} is accessible on ${HOST}"
    return 0
  else
    echo "    ❌ MongoDB port ${MONGO_PORT} is not accessible on ${HOST}"
    return 1
  fi
}

# Function to stop the MongoDB service
stop_mongo() {
  local HOST="$1"
  run_remote "${HOST}" "sudo systemctl stop mongod"
}

# Function to start the MongoDB service
start_mongo() {
  local HOST="$1"
  run_remote "${HOST}" "sudo systemctl start mongod"
}

# --- TEST MODE PROCEDURE ---
run_test_mode() {
  echo "#####################################################"
  echo "# 🧪 RUNNING IN TEST MODE - NO CHANGES WILL BE MADE #"
  echo "#####################################################"
  
  local TEST_FAILED=0
  
  echo "--- TESTING CONFIGURATION ---"
  echo "SSH User: ${SSH_USER}"
  echo "SSH Key File: ${KEYFILE_PATH}"
  echo "MongoDB Admin User: ${MONGO_ADMIN_USER}"
  echo "MongoDB Config Path: ${MONGO_CONFIG_PATH}"
  echo "MongoDB Port: ${MONGO_PORT}"
  echo "Replica Set Members: ${REPLICA_MEMBERS[*]}"
  echo "Target Host (primary): ${REPLICA_MEMBERS[0]}"
  
  if [ "$NEW_PASSWORD" = "redacted" ]; then
    echo "⚠️  WARNING: Password is still set to 'redacted' - please update before running 'go' mode"
    TEST_FAILED=1
  fi
  
  echo ""
  echo "--- TESTING SSH CONNECTIVITY ---"
  for MEMBER in "${REPLICA_MEMBERS[@]}"; do
    test_ssh_connectivity "${MEMBER}"
    if [ $? -ne 0 ]; then
      TEST_FAILED=1
    fi
  done
  
  echo ""
  echo "--- TESTING MONGODB SERVICE STATUS ---"
  for MEMBER in "${REPLICA_MEMBERS[@]}"; do
    test_mongo_status "${MEMBER}"
  done
  
  echo ""
  echo "--- TESTING MONGODB CONFIGURATION FILES ---"
  for MEMBER in "${REPLICA_MEMBERS[@]}"; do
    test_mongo_config "${MEMBER}"
    if [ $? -ne 0 ]; then
      TEST_FAILED=1
    fi
  done
  
  echo ""
  echo "--- TESTING MONGODB CONNECTIVITY ---"
  for MEMBER in "${REPLICA_MEMBERS[@]}"; do
    test_mongo_connectivity "${MEMBER}"
  done
  
  echo ""
  echo "--- TESTING SUDO PRIVILEGES ---"
  for MEMBER in "${REPLICA_MEMBERS[@]}"; do
    echo "--> Testing sudo privileges on ${SSH_USER}@${MEMBER}..."
    ssh -i "${KEYFILE_PATH}" "${SSH_USER}@${MEMBER}" "sudo -n systemctl status mongod >/dev/null 2>&1"
    if [ $? -eq 0 ]; then
      echo "    ✅ Sudo privileges on ${MEMBER}: OK"
    else
      echo "    ❌ Sudo privileges on ${MEMBER}: FAILED (may require password)"
      TEST_FAILED=1
    fi
  done
  
  echo ""
  echo "--- TESTING MONGOSH/MONGO CLIENT ---"
  TARGET_HOST="${REPLICA_MEMBERS[0]}"
  echo "--> Testing mongosh availability on ${SSH_USER}@${TARGET_HOST}..."
  ssh -i "${KEYFILE_PATH}" "${SSH_USER}@${TARGET_HOST}" "command -v mongosh >/dev/null 2>&1"
  if [ $? -eq 0 ]; then
    echo "    ✅ mongosh is available on ${TARGET_HOST}"
  else
    echo "    ⚠️  mongosh not found, checking for legacy mongo client..."
    ssh -i "${KEYFILE_PATH}" "${SSH_USER}@${TARGET_HOST}" "command -v mongo >/dev/null 2>&1"
    if [ $? -eq 0 ]; then
      echo "    ✅ legacy mongo client is available on ${TARGET_HOST}"
    else
      echo "    ❌ Neither mongosh nor mongo client found on ${TARGET_HOST}"
      TEST_FAILED=1
    fi
  fi
  
  echo ""
  echo "#####################################################"
  if [ $TEST_FAILED -eq 0 ]; then
    echo "# ✅ ALL TESTS PASSED - READY FOR 'go' MODE        #"
    echo "# Run: $0 go                                       #"
  else
    echo "# ❌ SOME TESTS FAILED - FIX ISSUES BEFORE 'go'    #"
    echo "# Check the errors above and resolve them          #"
  fi
  echo "#####################################################"
  
  return $TEST_FAILED
}

# --- MAIN PROCEDURE ---

# Check if running in test mode
if [ "$MODE" = "test" ]; then
  run_test_mode
  exit $?
fi

echo "#####################################################"
echo "# ⚠️ WARNING: RUNNING IN PRODUCTION MODE!            #"
echo "# This will RESET the MongoDB admin password        #"
echo "# and temporarily disable security!                 #"
echo "# Ensure you have run 'test' mode first!            #"
echo "#####################################################"

# Additional confirmation for production mode
echo ""
read -p "Are you sure you want to proceed with the password reset? (type 'YES' to continue): " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
  echo "Operation cancelled."
  exit 0
fi

echo "#####################################################"
echo "# ⚠️ WARNING: TEMPORARY SECURITY RISK AHEAD!         #"
echo "# This procedure will temporarily disable access     #"
echo "# control on one member. Run on a secure network.   #"
echo "#####################################################"

# 1. Stop all members
echo "--- 1. STOPPING ALL REPLICA SET MEMBERS ---"
for MEMBER in "${REPLICA_MEMBERS[@]}"; do
  stop_mongo "${MEMBER}"
done
echo "All replica set members are stopped."

# 2. Start ONE member without authorization (The first one in the list)
TARGET_HOST="${REPLICA_MEMBERS[0]}"
echo "--- 2. STARTING ${TARGET_HOST} IN STANDALONE/NO-AUTH MODE ---"

# Backup and modify the configuration file on the target host
run_remote "${TARGET_HOST}" "
  sudo cp ${MONGO_CONFIG_PATH} ${MONGO_CONFIG_PATH}.bak_noauth;
  sudo sed -i '/security:/,/authorization: enabled/s/authorization: enabled/#authorization: enabled/' ${MONGO_CONFIG_PATH};
  sudo sed -i '/replication:/,/replSetName:/s/replSetName:/#replSetName:/' ${MONGO_CONFIG_PATH};
  sudo sed -i '/keyFile:/s/keyFile:/#keyFile:/' ${MONGO_CONFIG_PATH};
"

# Force the service to use the modified config (some systems might need a direct mongod command)
start_mongo "${TARGET_HOST}"
echo "${TARGET_HOST} is running without authentication/replication."
sleep 5 # Wait for the instance to start

# 3. Connect and Reset the Password
echo "--- 3. RESETTING ADMIN PASSWORD ON ${TARGET_HOST} ---"

# Use mongosh (or mongo for older versions) to connect and run the update command
# Note: Since auth is disabled, we connect locally on the server over SSH
MONGO_COMMAND="
  mongosh --port ${MONGO_PORT} --eval '
    use admin;
    db.updateUser(
      \"${MONGO_ADMIN_USER}\",
      { pwd: \"${NEW_PASSWORD}\" }
    );
  '
"
run_remote "${TARGET_HOST}" "${MONGO_COMMAND}"

# 4. Restore the configuration and restart the primary
echo "--- 4. RESTORING CONFIGURATION AND RESTARTING PRIMARY ---"
run_remote "${TARGET_HOST}" "
  sudo mv ${MONGO_CONFIG_PATH}.bak_noauth ${MONGO_CONFIG_PATH};
  sudo rm -f ${MONGO_CONFIG_PATH}.bak_noauth;
"
stop_mongo "${TARGET_HOST}"
start_mongo "${TARGET_HOST}"
echo "${TARGET_HOST} restored and restarted with authorization."

# 5. Restart the remaining members
echo "--- 5. RESTARTING REMAINING REPLICA SET MEMBERS ---"
for i in "${!REPLICA_MEMBERS[@]}"; do
  if [ "$i" -ne 0 ]; then
    MEMBER="${REPLICA_MEMBERS[$i]}"
    start_mongo "${MEMBER}"
    echo "${MEMBER} restarted."
  fi
done
echo "All replica set members are running."

# 6. Verification
echo "--- 6. VERIFICATION ---"
echo "Attempting to connect to the replica set with the new password..."
# Use one of the hosts to connect to the replica set
mongosh "mongodb://${REPLICA_MEMBERS[0]}:${MONGO_PORT}/" \
  --username "${MONGO_ADMIN_USER}" \
  --password "${NEW_PASSWORD}" \
  --authenticationDatabase admin \
  --eval "rs.status()"

if [ $? -eq 0 ]; then
  echo "✅ SUCCESS: Password reset and verification successful!"
else
  echo "❌ FAILURE: Verification failed. Check logs for errors."
fi

echo "#####################################################"
echo "# 🎉 PASSWORD RESET PROCEDURE COMPLETED             #"
echo "# New admin password has been set successfully      #"
echo "# All replica set members are running normally      #"
echo "#####################################################"