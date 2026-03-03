pipeline {
    agent any
    
    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

      stage('Environment Setup') {
            steps {
                sh 'cp .env.example .env'
            }
        }
    }
}
