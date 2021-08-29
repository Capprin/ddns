#!/bin/bash

# variables
HOSTED_ZONE_ID="Z2GSIKUMUM28Z5"
NAME="internal.capprin.net."
TYPE="A"
TTL="300"

# get current IP address
echo "Getting host IP"
IP=$(curl http://checkip.amazonaws.com/)

# sanitize address
if [[ ! $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	echo "Bad IP, exiting..."
	exit 1
fi

# get current record
echo "Getting current record"
aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID | \
jq -r '.ResourceRecordSets[] | select (.Name == "'"$NAME"'") | select (.Type == "'"$TYPE"'") | .ResourceRecords[0].Value' > /tmp/current_route53_value

# compare current and record
if grep -Fxq "$IP" /tmp/current_route53_value; then
	echo "IP unchanged, exiting..."
	exit 1
fi

# prepare payload
echo "Updating record..."
cat > /tmp/route53_changes.json << EOF
    {
      "Comment":"Updated with DDNS shell script",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "ResourceRecords":[
              {
                "Value":"$IP"
              }
            ],
            "Name":"$NAME",
            "Type":"$TYPE",
            "TTL":$TTL
          }
        }
      ]
    }
EOF

# update record
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch file:///tmp/route53_changes.json >> /dev/null
echo "Done."
