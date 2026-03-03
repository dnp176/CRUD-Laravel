pipeline {
    agent any

    tools {
        // Optional if configured in Jenkins
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

      stage('Environment Setup') {
            steps {
                sh 'cp .env.example .env'
                sh 'php artisan key:generate'
            }
        }
    }
}
