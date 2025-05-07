#!/bin/sh

set -e
# get fvtt version from args fail if none provided
if [ $# -eq 0 ]; then
    echo "No arguments provided. Please provide the FVTT version."
    exit 1
fi
LATEST=$1
VERSION=$2

# Remove unnecessary files
find /home/0-images/fvtt_$VERSION/resources/app/node_modules -name "*.md" -delete
find /home/0-images/fvtt_$VERSION/resources/app/node_modules -name "*.d.ts" -delete
find /home/0-images/fvtt_$VERSION/resources/app/node_modules -name "*.map" -delete
find /home/0-images/fvtt_$VERSION/resources/app/node_modules -type d -name "test" -exec rm -rf {} +
find /home/0-images/fvtt_$VERSION/resources/app/node_modules -type d -name "docs" -exec rm -rf {} +
find /home/0-images/fvtt_$VERSION/resources/app/node_modules -type d -name "examples" -exec rm -rf {} +
rm -f /home/0-images/fvtt_$VERSION/foundryvtt

# create the fvtt.service file with the following

cat <<EOF >/home/0-images/fvtt.service
# Version 1.0.0
[Unit]
Description=Fvtt Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=fvtt
Group=fvtt
WorkingDirectory=/home/fvtt/foundrycore
ExecStart=node /home/fvtt/foundrycore/resources/app/main.js --dataPath=/home/fvtt/foundrydata --noupdate --port=30000 --serviceKey=32kljrekj43kjl3
ExecStop=/bin/kill -s SIGINT $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

#create the service key file

cat <<EOF >/home/0-images/fvtt_$VERSION/foundryserver.json
{
    "id": "foundryserver.com", 
    "signature": "P81tGaZHUlvizkkS1SheHtBGayGWAH0z8Xov0q+kMuwANw8Ubg8pICNdYLxNjMF1nnZ5bmcKUng2MX9c5kNz8xrxy5WBHs5fIUXFXaYKJNMdCrwp/tnL4bANTVWTL5zWmhnhaV9T6OezAa5cp9UTQoRbK9vrBwlQcpYL+pp93mCYJOx09gktUCIJVksUAMF1ExC+rpwUt49cl2R0qjnpUjq1ztyVHk5h5P5xDUhb8EeUA3xoh2TyvUo4nn7TklXTmxkU9uMcPbMnTxXhHOVPMHseYM5niWB2fO+q8i8EefBRvtOe3CFs18s75F9+dSggY93Zp/MtfuhDOD4yd0abOYbpSo+vstbJC1FMql0d0GAVJDDB6qKwHeX9bLVv7z/E6vncWLsvujfDURJsgyRjtngziuv+9I8h/9GSmbbGAdO8bPUxibXHSHA5Q0KtmR3cuTMx6Xdb03EPdCndNC5LKylWn1EE7kVBMlkE7oPhKJYVPLMCmsRit2YWWugDz3O/VWd3mbFs9F0cX8HdcfTGel7IFd8d0R4UDEHAZNfk3QPojhMgsM4qHFJwQLUEVdP9RF0/aUMcJDYyGKkuMNk7aPidn8TdvR+asnttCkIkLr9Wn+FR6za8HyDpgUo8kG99mNXtgZZKeH9SidleudkQsj50zZzwxgIhHqltufWwBP8="
}
EOF

mkdir -p /home/0-images/fvtt_$VERSION/hostlicense
cat <<EOF >/home/0-images/fvtt_$VERSION/hostlicense/foundryserver.json
{
    "id": "foundryserver.com", 
    "signature": "P81tGaZHUlvizkkS1SheHtBGayGWAH0z8Xov0q+kMuwANw8Ubg8pICNdYLxNjMF1nnZ5bmcKUng2MX9c5kNz8xrxy5WBHs5fIUXFXaYKJNMdCrwp/tnL4bANTVWTL5zWmhnhaV9T6OezAa5cp9UTQoRbK9vrBwlQcpYL+pp93mCYJOx09gktUCIJVksUAMF1ExC+rpwUt49cl2R0qjnpUjq1ztyVHk5h5P5xDUhb8EeUA3xoh2TyvUo4nn7TklXTmxkU9uMcPbMnTxXhHOVPMHseYM5niWB2fO+q8i8EefBRvtOe3CFs18s75F9+dSggY93Zp/MtfuhDOD4yd0abOYbpSo+vstbJC1FMql0d0GAVJDDB6qKwHeX9bLVv7z/E6vncWLsvujfDURJsgyRjtngziuv+9I8h/9GSmbbGAdO8bPUxibXHSHA5Q0KtmR3cuTMx6Xdb03EPdCndNC5LKylWn1EE7kVBMlkE7oPhKJYVPLMCmsRit2YWWugDz3O/VWd3mbFs9F0cX8HdcfTGel7IFd8d0R4UDEHAZNfk3QPojhMgsM4qHFJwQLUEVdP9RF0/aUMcJDYyGKkuMNk7aPidn8TdvR+asnttCkIkLr9Wn+FR6za8HyDpgUo8kG99mNXtgZZKeH9SidleudkQsj50zZzwxgIhHqltufWwBP8="
}
EOF

# Create the package using fpm
fpm -s dir -t deb -n "foundry" -v $VERSION --description "Fvtt application" --after-install postinst.sh --deb-compression gz --deb-user fvtt --deb-group fvtt --force --package /home/0-images/packages /home/0-images/fvtt_$VERSION/=/home/fvtt/foundrycore fvtt.service=/etc/systemd/system/fvtt.service

if [ $LATEST == true ]; then
    s3cmd put /home/0-images/packages/foundry_${VERSION}_amd64.deb s3://foundry-apt/foundry_latest_amd64.deb
    s3cmd setacl s3://foundry-apt/foundry_latest_amd64.deb --acl-public --recursive
fi

#Upload to DO
echo "Uploading to DO"
# Upload latest package to DO Spaces
s3cmd put /home/0-images/packages/foundry_${VERSION}_amd64.deb s3://foundry-apt/foundry_${VERSION}_amd64.deb
# Set the ACL to public
echo "Setting ACL to public"
s3cmd setacl s3://foundry-apt/foundry_${VERSION}_amd64.deb --acl-public --recursive
