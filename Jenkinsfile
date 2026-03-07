pipeline {
    agent any

    environment {
        PROJECT_KEY = "crud-laravel"
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

                        sh """
                        ${scannerHome}/bin/sonar-scanner \
                        -Dsonar.projectKey=${PROJECT_KEY} \
                        -Dsonar.projectName=${PROJECT_KEY} \
                        -Dsonar.sources=. \
                        -Dsonar.sourceEncoding=UTF-8
                        """

                    }

                }

            }
        }

    }
}
