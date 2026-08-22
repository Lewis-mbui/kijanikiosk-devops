pipeline {
  agent {
    docker {
      image 'kijanikiosk-node-agent:22'
      args '--network ci-network'
    }
  }

  environment {
    NODE_ENV  = 'test'
    BUILD_DIR = 'dist'
    APP_NAME  = 'kijanikiosk-payments'
    PKG_VERSION = sh(script: "node -p \"require('./package.json').version\"",
                    returnStdout: true).trim()
    GIT_SHORT   = sh(script: 'git rev-parse --short HEAD',
                    returnStdout: true).trim()
    ARTIFACT_VERSION = "${PKG_VERSION}-${GIT_SHORT}"

    // Jenkins reaches Nexus through the shared Docker network.
    NEXUS_URL = 'http://nexus:8081/repository/npm-kijanikiosk'
  }

  options {
    timeout(time: 15, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '10'))
    disableConcurrentBuilds()
  }

  stages {
    stage('Lint') {
      steps {
        echo "Running lint checks..."
        sh 'npm ci'
        sh 'npm run lint'
      }
    }

    stage('Build') {
      steps {
        echo "Using node version:"
        sh 'node --version'

        echo "Building ${APP_NAME}..."
        sh 'npm run build'

        echo "Verifying build output..."
        sh '''
          set -e
          test -d "${BUILD_DIR}" || { echo "ERROR: build directory not found"; exit 1; }
          FILE_COUNT=$(find "${BUILD_DIR}" -type f | wc -l)
          echo "Build output: ${FILE_COUNT} files in ${BUILD_DIR}/"
          test "${FILE_COUNT}" -gt 0 || { echo "ERROR: build directory is empty"; exit 1; }
        '''

        stash(
          name: 'build-output',
          includes: 'dist/**,package.json,package-lock.json'
        )
      }
    }

    stage('Verify') {
      parallel {
        stage('Test') {
          steps {
            unstash 'build-output'
            echo "Running test suite for ${APP_NAME}..."
            sh 'npm test'
          }

          post {
            always {
              junit(allowEmptyResults: true, testResults: 'test-results/*.xml')
            }
          }
        }

        stage('Security Audit') {
          steps {
            sh 'npm audit --audit-level=high'
          }
        }

      }
    }

    stage('Archive') {
      steps {
        echo "Archiving build artifact for ${APP_NAME} build ${BUILD_NUMBER}..."
        archiveArtifacts artifacts: "${BUILD_DIR}/**", fingerprint: true, onlyIfSuccessful: true
        echo "Jenkins artifact URL: ${BUILD_URL}artifact/"
      }
    }

    stage('Publish') {
      steps {
        echo "Publishing ${APP_NAME} version ${ARTIFACT_VERSION} to Nexus..."

        withCredentials([usernamePassword(
          credentialsId: 'nexus-credentials',
          usernameVariable: 'NEXUS_USER',
          passwordVariable: 'NEXUS_PASS'
        )]) {
          sh '''
            set -e

            # Always remove temporary authentication
            # including when npm publish fails
            trap 'rm -f .npmrc' EXIT

            # Prevent the transformed Base64 credential from being printed.
            set +x

            # Generate base64 token from the injected credentials
            NEXUS_TOKEN=$(echo -n "${NEXUS_USER}:${NEXUS_PASS}" | base64)

            cat > .npmrc <<NPMRC
registry=${NEXUS_URL}/
//nexus:8081/repository/npm-kijanikiosk/:_auth=${NEXUS_TOKEN}
NPMRC

            npm version "${ARTIFACT_VERSION}" --no-git-tag-version

            #publish the package
            npm publish
          '''
        }
      }
    }
  }

  post {
    success {
      echo "SUCCESS: Published ${APP_NAME} version ${ARTIFACT_VERSION} to Nexus."
      echo "Nexus artifact URL: ${NEXUS_URL}/${APP_NAME}/-/${APP_NAME}-${ARTIFACT_VERSION}.tgz"
    }

    failure {
      echo "FAILURE: ${APP_NAME} pipeline failed at build #${BUILD_NUMBER}."
      echo "Check the console log: ${BUILD_URL}"
    }

    changed {
      echo "Build status changed to ${currentBuild.currentResult} - ${JOB_NAME} #${BUILD_NUMBER}"
    }

    always {
      cleanWs()
    }
  }
}