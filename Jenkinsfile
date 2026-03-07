pipeline {
    agent any

    tools {
        sonarRunner 'Sonar-Scanner'
    }

    environment {
        PROJECT_KEY = "crud-laravel"
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('SonarQube Analysis') {
            steps {

                withSonarQubeEnv('sonar-server') {

                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {

                        sh '''
                        sonar-scanner \
                        -Dsonar.projectKey=$PROJECT_KEY \
                        -Dsonar.projectName=$PROJECT_KEY \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=$SONAR_HOST_URL \
                        -Dsonar.login=$SONAR_TOKEN
                        '''

                    }

                }

            }
        }

    }
}
