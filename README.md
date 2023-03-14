<div id="top"></div>
<!--
*** Thanks for checking out the Best-README-Template. If you have a suggestion
*** that would make this better, please fork the repo and create a pull request
*** or simply open an issue with the tag "enhancement".
*** Don't forget to give the project a star!
*** Thanks again! Now go create something AMAZING! :D
-->



<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->


<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/jcspigler2010/f5_saml_staging_icontrol">
    <img src="images/default-ogimage.png" alt="Logo" width="80" height="80">
  </a>

<h3 align="center">F5 iControl APM SAML Resource Staging</h3>

  <p align="center">
    <br />
    <a href="https://github.com/jcspigler2010/f5_saml_staging_icontrol"><strong>Explore the docs »</strong></a>
    <br />
    <br />
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#warning">WARNING!!</a></li>
      </ul>
      <ul>
        <li><a href="#jenkins-build-pipeline-example">Jenkins Build Pipeline Example</a></li>
        <li><a href="#json-example">JSON Example</a></li>
        <li><a href="#api-references">API references</a></li>
        <li><a href="#scripts">Scripts</a></li>
      </ul>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project


<p align="right">(<a href="#top">back to top</a>)</p>


## Link to F5 icontrol documentation

* [F5 iControl](https://clouddocs.f5.com/api/icontrol-rest/)



<p align="right">(<a href="#top">back to top</a>)</p>



<!-- GETTING STARTED -->


Below is an example of using various methods to assert REST calls to F5's iControl interface.  This example shows how to in sequence... 

- load federation metadata
- an external saml SP connector
- a local saml IDP
- a saml resource
- ldap group assign saml resource

### Jenkins Build Pipeline Example

```
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


```