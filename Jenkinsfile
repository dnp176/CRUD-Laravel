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
                        sonar-scanner \
                        -Dsonar.projectKey=crud-laravel \
                        -Dsonar.projectName=crud-laravel \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=http://172.20.0.12:9000 \
                        -Dsonar.login=$SONAR_TOKEN \
                        -Dsonar.profile="Sonar way"
                        """

                    }

                }

            }
        }

    }
}
