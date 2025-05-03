# Setup apt package fpm.

```
fpm -s dir -t deb \
 -n "foundry" \
 -v "6.76" \
 --description "Fvtt application" \
 --maintainer "Brad K <admin@foundryserver.com>" \
 --depends "nodejs >= 20.0.0" \
 --after-install postinst.sh \
 --deb-compression gzip \
 ./home/0-images/fvtt_065/=/home/fvtt/foundrycore \
 ./fvtt.service=/etc/systemd/system/fvtt.service
```

```
# Remove unnecessary files
find resources/app/node_modules -name "*.md" -delete
find resources/app/node_modules -name "*.d.ts" -delete
find resources/app/node_modules -name "*.map" -delete
find resources/app/node_modules -type d -name "test" -exec rm -rf {} +
find resources/app/node_modules -type d -name "docs" -exec rm -rf {} +
find resources/app/node_modules -type d -name "examples" -exec rm -rf {} +


```
