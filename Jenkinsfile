pipeline {
    agent any

    environment {
        PROJECT_KEY = "crud-laravel"
        PROJECT_NAME = "crud-laravel"
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('SonarQube Scan') {
            steps {

                script {

                    def scannerHome = tool 'Sonar-Scanner'

                    withSonarQubeEnv('sonar-server') {

                        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {

                            sh """
                            ${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=${PROJECT_KEY} \
                            -Dsonar.projectName=${PROJECT_NAME} \
                            -Dsonar.sources=. \
                            -Dsonar.host.url=${SONAR_HOST_URL} \
                            -Dsonar.token=${SONAR_TOKEN} \
                            -Dsonar.sourceEncoding=UTF-8 \
                            -Dsonar.exclusions=**/vendor/**,**/node_modules/**,**/storage/**,**/bootstrap/cache/**,**/public/**,**/*.min.js,**/*.log \
                            -Dsonar.php.coverage.reportPaths=coverage.xml
                            """

                        }

                    }

                }

            }
        }

    }
}
