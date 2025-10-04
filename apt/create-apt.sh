#!/bin/sh

# temp working directory
TEMP_DIR="/tmp/fvtt_build"
mkdir -p $TEMP_DIR/packages

set -e
# get fvtt version from args fail if none provided
if [ $# -eq 0 ]; then
    echo "No arguments provided. Please provide the FVTT version."
    exit 1
fi
LATEST=$2
URL=$1

if [ -z "$LATEST" ]; then
    LATEST=false
fi

# get version from url
# https://r2.foundryvtt.com/releases/13.347/FoundryVTT-Linux-13.347.zip?verify=1757878009-vWDOwBRtX9eKNkG4BSvpQC66S3BmqoQXKfBZ3ZI639k%3D
VERSION=$(echo "$URL" | grep -oP '(?<=releases/)[0-9]+\.[0-9]+' | head -1)
VERSION_NUM=$(echo $VERSION | tr -d '.')

# download the file
echo "Downloading Foundry VTT version $VERSION from $URL"
wget -O $TEMP_DIR/fvtt_$VERSION.zip "$URL"

# Create necessary directories
echo "Creating necessary directories"
mkdir -p $TEMP_DIR/fvtt_$VERSION

# Unzip the file
echo "Unzipping Foundry VTT version $VERSION"
unzip -o $TEMP_DIR/fvtt_$VERSION.zip -d $TEMP_DIR/fvtt_$VERSION

# Remove unnecessary files
find $TEMP_DIR/fvtt_$VERSION/resources/app/node_modules -name "*.md" -delete
find $TEMP_DIR/fvtt_$VERSION/resources/app/node_modules -name "*.d.ts" -delete
find $TEMP_DIR/fvtt_$VERSION/resources/app/node_modules -name "*.map" -delete
find $TEMP_DIR/fvtt_$VERSION/resources/app/node_modules -type d -name "test" -exec rm -rf {} +
find $TEMP_DIR/fvtt_$VERSION/resources/app/node_modules -type d -name "docs" -exec rm -rf {} +
find $TEMP_DIR/fvtt_$VERSION/resources/app/node_modules -type d -name "examples" -exec rm -rf {} +
rm -f $TEMP_DIR/fvtt_$VERSION/foundryvtt


# create the fvtt.service file with the following
echo "Creating fvtt.service file"

if [ "$VERSION_NUM" -lt 13338 ]; then
    cat <<EOF >$TEMP_DIR/fvtt.service
[Unit]
Description=Foundry VTT Application v1.0.0
After=network.target
Wants=network.target

[Service]
Type=simple
User=fvtt
Group=fvtt
ExecStart=/usr/bin/node /home/fvtt/data/foundrycore/resources/app/main.js --dataPath=/home/fvtt/data/foundrydata --noupdate --port=30000 -serviceKey=32kljrekj43kjl3
ExecStop=/bin/kill -s SIGINT
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
else
    cat <<EOF >$TEMP_DIR/fvtt.service
[Unit]
Description=Foundry VTT Application v1.0.0
After=network.target
Wants=network.target

[Service]
Type=simple
User=fvtt
Group=fvtt
ExecStart=/usr/bin/node /home/fvtt/data/foundrycore/main.js --dataPath=/home/fvtt/data/foundrydata --noupdate --port=30000 -serviceKey=32kljrekj43kjl3
ExecStop=/bin/kill -s SIGINT
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
fi



#create the service key files
cat <<EOF >$TEMP_DIR/fvtt_$VERSION/foundryserver.json
{
    "id": "foundryserver.com", 
    "signature": "P81tGaZHUlvizkkS1SheHtBGayGWAH0z8Xov0q+kMuwANw8Ubg8pICNdYLxNjMF1nnZ5bmcKUng2MX9c5kNz8xrxy5WBHs5fIUXFXaYKJNMdCrwp/tnL4bANTVWTL5zWmhnhaV9T6OezAa5cp9UTQoRbK9vrBwlQcpYL+pp93mCYJOx09gktUCIJVksUAMF1ExC+rpwUt49cl2R0qjnpUjq1ztyVHk5h5P5xDUhb8EeUA3xoh2TyvUo4nn7TklXTmxkU9uMcPbMnTxXhHOVPMHseYM5niWB2fO+q8i8EefBRvtOe3CFs18s75F9+dSggY93Zp/MtfuhDOD4yd0abOYbpSo+vstbJC1FMql0d0GAVJDDB6qKwHeX9bLVv7z/E6vncWLsvujfDURJsgyRjtngziuv+9I8h/9GSmbbGAdO8bPUxibXHSHA5Q0KtmR3cuTMx6Xdb03EPdCndNC5LKylWn1EE7kVBMlkE7oPhKJYVPLMCmsRit2YWWugDz3O/VWd3mbFs9F0cX8HdcfTGel7IFd8d0R4UDEHAZNfk3QPojhMgsM4qHFJwQLUEVdP9RF0/aUMcJDYyGKkuMNk7aPidn8TdvR+asnttCkIkLr9Wn+FR6za8HyDpgUo8kG99mNXtgZZKeH9SidleudkQsj50zZzwxgIhHqltufWwBP8="
}
EOF

mkdir -p $TEMP_DIR/fvtt_$VERSION/hostlicense
cat <<EOF >$TEMP_DIR/fvtt_$VERSION/hostlicense/foundryserver.json
{
    "id": "foundryserver.com", 
    "signature": "P81tGaZHUlvizkkS1SheHtBGayGWAH0z8Xov0q+kMuwANw8Ubg8pICNdYLxNjMF1nnZ5bmcKUng2MX9c5kNz8xrxy5WBHs5fIUXFXaYKJNMdCrwp/tnL4bANTVWTL5zWmhnhaV9T6OezAa5cp9UTQoRbK9vrBwlQcpYL+pp93mCYJOx09gktUCIJVksUAMF1ExC+rpwUt49cl2R0qjnpUjq1ztyVHk5h5P5xDUhb8EeUA3xoh2TyvUo4nn7TklXTmxkU9uMcPbMnTxXhHOVPMHseYM5niWB2fO+q8i8EefBRvtOe3CFs18s75F9+dSggY93Zp/MtfuhDOD4yd0abOYbpSo+vstbJC1FMql0d0GAVJDDB6qKwHeX9bLVv7z/E6vncWLsvujfDURJsgyRjtngziuv+9I8h/9GSmbbGAdO8bPUxibXHSHA5Q0KtmR3cuTMx6Xdb03EPdCndNC5LKylWn1EE7kVBMlkE7oPhKJYVPLMCmsRit2YWWugDz3O/VWd3mbFs9F0cX8HdcfTGel7IFd8d0R4UDEHAZNfk3QPojhMgsM4qHFJwQLUEVdP9RF0/aUMcJDYyGKkuMNk7aPidn8TdvR+asnttCkIkLr9Wn+FR6za8HyDpgUo8kG99mNXtgZZKeH9SidleudkQsj50zZzwxgIhHqltufWwBP8="
}
EOF

#Upload to DO
echo "Uploading to DO"

# Create the package using fpm
fpm -s dir -t deb -n "foundry" -v $VERSION --description "Fvtt application" --after-install postinst.sh --before-install preinst.sh --deb-compression gz --deb-user fvtt --deb-group fvtt --force --package $TEMP_DIR/packages $TEMP_DIR/fvtt_$VERSION/=/home/fvtt/data/foundrycore fvtt.service=/etc/systemd/system/fvtt.service

if [ $LATEST == true ]; then
    s3cmd put $TEMP_DIR/packages/foundry_${VERSION}_amd64.deb s3://foundry-apt/foundry_latest_amd64.deb
    s3cmd setacl s3://foundry-apt/foundry_latest_amd64.deb --acl-public --recursive
fi

# Upload latest package to DO Spaces.
s3cmd put $TEMP_DIR/packages/foundry_${VERSION}_amd64.deb s3://foundry-apt/foundry_${VERSION}_amd64.deb
s3cmd setacl s3://foundry-apt/foundry_${VERSION}_amd64.deb --acl-public --recursive
