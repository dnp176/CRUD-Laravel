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

                withSonarQubeEnv('sonar-server') {

                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {

                        sh '''
                        /var/jenkins_home/tools/hudson.plugins.sonar.SonarRunnerInstallation/Sonar-Scanner/bin/sonar-scanner \
                        -Dsonar.projectKey=crud-laravel \
                        -Dsonar.projectName=crud-laravel \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=$SONAR_HOST_URL \
                        -Dsonar.token=$SONAR_TOKEN \
                        -Dsonar.sourceEncoding=UTF-8 \
                        -Dsonar.exclusions=**/vendor/**,**/node_modules/**,**/storage/**,**/bootstrap/cache/**,**/public/**,**/*.min.js,**/*.log
                        '''

                    }

                }

            }
        }

    }
}
