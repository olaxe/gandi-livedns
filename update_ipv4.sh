#!/bin/sh
#
# Updates domain A zone record with WAN IP using Gandi's LiveDNS.

# prevent shell to expand wildcard record
set -f

API="https://dns.api.gandi.net/api/v5/"
IP_SERVICE="http://me.gandi.net"

if [ -n "${DNS_SERVER_CHECKING}" ]; then
  DNS_SERVER_CHECKING=@$DNS_SERVER_CHECKING
fi

if [ -z "${FORCE_IPV4}" ]; then
  WAN_IPV4=$(curl -s4 ${IP_SERVICE})
  if [ -z "${WAN_IPV4}" ]; then
    echo "$(date "+[%Y-%m-%d %H:%M:%S]") [ERROR] Something went wrong. Can not get your IPv4 from ${IP_SERVICE}"
    exit 1
  fi
else
  WAN_IPV4="${FORCE_IPV4}"
fi

for RECORD in $(echo "$RECORD_LIST" | sed -e 's/;/ /g') ; do
  if [ "${RECORD}" = "@" ] || [ "${RECORD}" = "*" ]; then
    SUBDOMAIN="${DOMAIN}"
  else
    SUBDOMAIN="${RECORD}.${DOMAIN}"
  fi

  CURRENT_IPV4=$(dig A "${SUBDOMAIN}" +short "${DNS_SERVER_CHECKING:-}")
  if [ "${CURRENT_IPV4}" = "${WAN_IPV4}" ] ; then
    echo "$(date "+[%Y-%m-%d %H:%M:%S]") [INFO] Current DNS A record for ${RECORD} matches WAN IP (${CURRENT_IPV4}). Nothing to do."
    continue
  fi

  DATA='{"rrset_ttl": '${TTL}', "rrset_values": ["'${WAN_IPV4}'"]}'
  status=$(curl -s -w '%{http_code}' -o /dev/null -XPUT -d "${DATA}" \
    -H"X-Api-Key: ${APIKEY}" \
    -H"Content-Type: application/json" \
    "${API}/domains/${DOMAIN}/records/${RECORD}/A")
  if [ "${status}" = '201' ] ; then
    echo "$(date "+[%Y-%m-%d %H:%M:%S]") [OK] Updated ${RECORD} to ${WAN_IPV4}"
  else
    echo "$(date "+[%Y-%m-%d %H:%M:%S]") [ERROR] API POST returned status ${status}"
  fi
done
