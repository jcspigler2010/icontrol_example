
#retrieve token
token=$(curl -k --location --request POST 'https://govf5openshift0.cloudmegalodon.us/mgmt/shared/authn/login' \
--header 'Content-Type: application/json' \
--data-raw '{
    "username":"$PW",
    "password":"$USER",
    "loginProviderName":"tmos"
}' | jq -r '.token.token')

#verify token
curl -k --location --request GET 'https://govf5openshift0.cloudmegalodon.us/mgmt/shared/authz/tokens' \
--header 'X-F5-Auth-Token: ${F5_TOKEN}'

curl -k --location --request PATCH 'https://govf5openshift0.cloudmegalodon.us/mgmt/shared/authz/tokens/RUZH3RX5TN45UX56S3ZYFZ43SF' \
--header 'Content-Type: application/json' \
--header 'X-F5-Auth-Token: RUZH3RX5TN45UX56S3ZYFZ43SF' \
--data-raw '{
    "timeout":"36000"
}'


curl -k --location --request POST 'https://govf5openshift0.cloudmegalodon.us/mgmt/tm/apm/sso/saml-sp-connector' \
--header 'X-F5-Auth-Token: $F5_TOKEN' \
--header 'Content-Type: application/json' \
--data-raw '{
     "name": "${TENANT}_sp",
     "partition": "Common",
     "description": "${TENANT}_sp saml sp",
     "importMetadata": "/var/config/rest/downloads/${TENANT}.xml"
}
'

curl -k --location --request POST 'https://govf5openshift0.cloudmegalodon.us/mgmt/tm/apm/sso/saml' \
--header 'X-F5-Auth-Token: $F5_TOKEN' \
--header 'Content-Type: application/json' \
--data-raw '{
    "name": "${TENANT}_idp",
    "partition": "Common",
    "encryptSubject": "false",
    "encryptionTypeSubject": "aes128",
    "entityId": "https://${TENANT}_idp.cloudmegalodon.com",
    "idpCertificate": "/Common/default.crt",
    "idpCertificateReference": {
        "link": "https://localhost/mgmt/tm/sys/file/ssl-cert/~Common~default.crt?ver=15.1.0.2"
    },
    "idpScheme": "https",
    "idpSignkey": "/Common/default.key",
    "idpSignkeyReference": {
        "link": "https://localhost/mgmt/tm/sys/file/ssl-key/~Common~default.key?ver=15.1.0.2"
    },
    "keyTransportAlgorithm": "rsa-oaep",
    "locationSpecific": "false",
    "logLevel": "notice",
    "samlProfiles": [
        "web-browser-sso",
        "ecp"
    ],
    "subjectType": "email-address",
    "subjectValue": "%{session.ad.last.attr.name}"
}
'
