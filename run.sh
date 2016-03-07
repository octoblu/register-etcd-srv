#!/bin/bash

if [ -z "${RECORD}" ]; then
  echo "Missing RECORD, exiting."
  exit 1
fi

if [ -z "${DOMAIN}" ]; then
  echo "Missing DOMAIN, exiting."
  exit 1
fi

if [ -z "${EC2_FILTER}" ]; then
  echo "Missing EC2_FILTER, exiting."
  exit 1
fi

if [ -z "${AWS_DEFAULT_REGION}" ]; then
  echo "Missing AWS_DEFAULT_REGION, exiting."
  exit 1
fi

HOSTED_ZONE=$(aws route53 list-hosted-zones | jq -r ".HostedZones[] | select(.Name==\"${DOMAIN}.\") .Id")

if [ -z "${HOSTED_ZONE}" ]; then
  echo "Unable to find zone for ${DOMAIN}, exiting."
  exit 1
fi

ETCD_SERVERS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${EC2_FILTER}" | jq -r '.Reservations[].Instances[].PrivateIpAddress' | grep -v null)

VALUES=""
for ETCD_SERVER in ${ETCD_SERVERS}; do
  VALUES="${VALUES} {\"Value\": \"0 0 2380 ${ETCD_SERVER}\"},"
done

TRIM_VALUES=${VALUES%?}

cat change.template | sed -e "s/%VALUES%/${TRIM_VALUES}/g" | sed -e "s/%RECORD%/${RECORD}/g"  | sed -e "s/%DOMAIN%/${DOMAIN}/g" > change.json
aws route53 change-resource-record-sets --debug --hosted-zone ${HOSTED_ZONE} --change-batch file://change.json
