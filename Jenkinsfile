pipeline {
    agent any

    environment {
        PROJECT_KEY = "crud-laravel"
        PROJECT_NAME = "crud-laravel"

        IMAGE_NAME = "dnptestaccount/laravel-db-based-app"
        IMAGE_TAG = "development"
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        // stage('SonarQube Scan') {
        //     steps {
        //
        //         withSonarQubeEnv('sonar-server') {
        //
        //             withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
        //
        //                 sh '''
        //                 /var/jenkins_home/tools/hudson.plugins.sonar.SonarRunnerInstallation/Sonar-Scanner/bin/sonar-scanner \
        //                 -Dsonar.projectKey=crud-laravel \
        //                 -Dsonar.projectName=crud-laravel \
        //                 -Dsonar.sources=. \
        //                 -Dsonar.host.url=$SONAR_HOST_URL \
        //                 -Dsonar.token=$SONAR_TOKEN \
        //                 -Dsonar.sourceEncoding=UTF-8 \
        //                 -Dsonar.exclusions=**/vendor/**,**/node_modules/**,**/storage/**,**/bootstrap/cache/**,**/public/**,**/*.min.js,**/*.log
        //                 '''
        //
        //             }
        //
        //         }
        //
        //     }
        // }

            stage('OWASP Dependency Scan') {
                steps {
                    sh '''
                    /var/jenkins_home/tools/org.jenkinsci.plugins.DependencyCheck.tools.DependencyCheckInstallation/dependency-check/bin/dependency-check.sh \
                    --project "crud-laravel" \
                    --scan . \
                    --format HTML \
                    --out dependency-check-report \
                    --disableYarnAudit \
                    --disableNodeAudit \
                    --nvdApiKey 6b3522fb-5fdc-480e-adfd-a840acd984d0 \
                    --noupdate
                    '''
                }
            }

        // stage('Docker Build Image') {
        //     steps {
        //         sh '''
        //         docker build -t $IMAGE_NAME:$IMAGE_TAG .
        //         '''
        //     }
        // }

        stage('Trivy Image Scan') {
            steps {
                sh '''
                trivy image --severity HIGH,CRITICAL --no-progress $IMAGE_NAME:$IMAGE_TAG
                '''
            }
        }

    }
}
