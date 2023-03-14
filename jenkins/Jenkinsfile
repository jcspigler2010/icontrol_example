pipeline {


  agent any
  environment {
  TENANT="DTRA"
  PW="something"
  USER="admin"
}

  stages {
    stage ('Retrieve F5 auth token'){
      steps{
        script{

          F5_TOKEN = sh (
            label: '',
            returnStdout: true,
            script: """curl -k --location --request POST \'https://govf5openshift0.cloudmegalodon.us/mgmt/shared/authn/login\' \\
                --header \'Content-Type: application/json\' \\
                --data-raw \'{
                    "username":"$USER",
                    "password":"$PW",
                    "loginProviderName":"tmos"
                }\' | jq -r \'.token.token\'
                """
        ).trim()
       }
       echo "F5 Token is:  ${F5_TOKEN}"
      }
    }
    stage ('Verify F5 Auth Token and Set timeout'){
      steps{
        script{
          sh "curl -k --location --request GET \'https://govf5openshift0.cloudmegalodon.us/mgmt/shared/authz/tokens\' --header \'X-F5-Auth-Token: $F5_TOKEN\'"

          sh """curl -k --location --request PATCH \'https://govf5openshift0.cloudmegalodon.us/mgmt/shared/authz/tokens/$F5_TOKEN\' \\
            --header \'Content-Type: application/json\' \\
            --header \'X-F5-Auth-Token: $F5_TOKEN\' \\
            --data-raw \'{
                "timeout":"36000"
            }\'"""
          }
      }
    }
    stage ('Upload Federation Meta Data .xml'){
      steps{
        script{

          sh label: '',
          returnStatus: true,
          script: """curl -k --location --request POST \'https://govf5openshift0.cloudmegalodon.us/mgmt/shared/file-transfer/uploads/${TENANT}.xml\' \\
          --header \'X-F5-Auth-Token: $F5_TOKEN\' \\
          --header \'Content-Type: application/octet-stream\' \\
          --header \'Content-Range: 0-5250/5251\' \\
          --data-binary \'@tenant1.xml\'"""
        }
      }
    }
    stage ('Create SAML SP connector'){
      steps{
        script{
          sh label: 'Create saml-sp-connector for VCD Org',
          returnStatus: true,
          script: """curl -k --location --request POST \'https://govf5openshift0.cloudmegalodon.us/mgmt/tm/apm/sso/saml-sp-connector\' \\
          --header \'X-F5-Auth-Token: $F5_TOKEN\' \\
          --header \'Content-Type: application/json\' \\
          --data-raw \'{
               "name": "${TENANT}_sp",
               "partition": "Common",
               "description": "${TENANT}_sp saml sp",
               "importMetadata": "/var/config/rest/downloads/${TENANT}.xml"
          }
          \'
          """
        }
      }
    }
    stage ('Create SAML Local IdP on F5'){
      steps{
        script{
          sh label: 'Create IDP',
          returnStatus: true,
          script: """curl -k --location --request POST \'https://govf5openshift0.cloudmegalodon.us/mgmt/tm/apm/sso/saml\' \\
          --header \'X-F5-Auth-Token: $F5_TOKEN\' \\
          --header \'Content-Type: application/json\' \\
          --data-raw \'{
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
          \'"""
        }
      }
    }
  stage('Link External SAML SP Connector with Local SAML IDP'){
    steps{
      script{
        sh label: 'Link External SAML SP Connector with Local SAML IDP',
        returnStatus: true,
        script: """curl -k --location --request PATCH \'https://govf5openshift0.cloudmegalodon.us/mgmt/tm/apm/sso/saml/~Common~${TENANT}_idp\' \\
        --header \'X-F5-Auth-Token: $F5_TOKEN\' \\
        --header \'Content-Type: application/json\' \\
        --data-raw \'{
            "spConnectors": [
                "/Common/${TENANT}_sp"
            ]

        }\'"""
      }
    }
  }
  stage('Create SAML Resource'){
    steps{
      script{
        sh label: 'Create SAML Resource',
        returnStatus: true,
        script: """curl -k --location --request POST \'https://govf5openshift0.cloudmegalodon.us/mgmt/tm/apm/sso/saml-resource\' \\
        --header \'X-F5-Auth-Token: $F5_TOKEN\' \\
        --header \'Content-Type: application/json\' \\
        --data-raw \'{
            "name": "${TENANT}_SamlResource",
            "locationSpecific": "false",
            "publishOnWebtop": "true",
            "ssoConfigSaml": "/Common/${TENANT}_idp"
        }
        \'"""
      }
    }
  }
  stage('Add SAML Resource to Webtop AD resource assignment'){
    steps{
      script{
        sh label: 'Add SAML Resource to Webtop AD group resource assignment',
        returnStatus: true,
        script: """curl -k --location --request PATCH \'https://govf5openshift0.cloudmegalodon.us/mgmt/tm/apm/policy/agent/resource-assign/~Common~testPolicy_act_ad_group_mapping_ag\' \\
          --header \'X-F5-Auth-Token: $F5_TOKEN\' \\
          --header \'Content-Type: application/json\' \\
          --data-raw \' {
              "rules": [
                          {
                              "expression": "expr { [string tolower [mcget -decode {session.ad.last.attr.memberOf}]] contains [string tolower \\\\\\"CN=test1,\\\\\\"] }",
                              "samlResources": [
                                  "/Common/samlResourceTest2"
                              ]
                          },
                                          {
                              "expression": "expr { [string tolower [mcget -decode {session.ad.last.attr.memberOf}]] contains [string tolower \\\\\\"CN=${TENANT}_users,\\\\\\"] }",
                              "samlResources": [
                                  "/Common/${TENANT}_SamlResource"
                              ]
                          }
                      ]

           }\'"""
      }
    }
  }
  stage('Commit APM Changes'){
    steps{
      script{
        sh label: 'Commit APM changes',
        returnStatus: true,
        script: """curl -k --location --request PATCH \'https://govf5openshift0.cloudmegalodon.us//mgmt/tm/apm/profile/access/~Common~testPolicy\' \\
      --header \'X-F5-Auth-Token: ${F5_TOKEN}\' \\
      --header \'Content-Type: application/json\' \\
      --data-raw \'{
          "generationAction":"increment"

      }\'"""
      }
    }
  }
  }
}
