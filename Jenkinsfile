pipeline {
    agent any

    tools {
        gradle 'Gradle-8.0'
        jdk 'JDK-17'
    }

    environment {
        APP_NAME = 'lendbiz-apigateway'
        SPRING_PROFILE = 'test'
        APP_PORT = '9100'
    }

    stages {

        stage('Checkout') {
            steps {
                withCredentials([string(credentialsId: 'git-finy-api-test-url', variable: 'GIT_URL')]) {
                    script {
                        echo "=========================================="
                        echo "Build Configuration:"
                        echo "  Environment: test"
                        echo "  Git Branch: test"
                        echo "  Spring Profile: ${SPRING_PROFILE}"
                        echo "  Application Port: ${APP_PORT}"
                        echo "=========================================="
                    }
                    git branch: 'test',
                        url: "${GIT_URL}",
                        credentialsId: 'git-credentials'
                }
            }
        }

        stage('Build') {
            steps {
                script {
                    echo "Building Spring Boot application for test environment"
                    echo "Using Spring Profile: ${SPRING_PROFILE}"
                }
                sh 'gradle --version'
                sh """
                    gradle clean build \
                        -Pspring.profiles.active=${SPRING_PROFILE} \
                        -x test \
                        --no-daemon
                """
            }
        }

        stage('Build Image') {
            steps {
                script {
                    def imageTag = "${APP_NAME}:test-${BUILD_NUMBER}"
                    def latestTag = "${APP_NAME}:test-latest"
                    echo "=========================================="
                    echo "Building container image with Podman..."
                    echo "Image: ${imageTag}"
                    echo "Latest: ${latestTag}"
                    echo "=========================================="
                    sh """
                        export CONTAINER_HOST=unix:///run/podman/podman.sock
                        podman build -t ${imageTag} -t ${latestTag} .
                    """
                    echo "✅ Image built successfully"
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    def imageTag = "${APP_NAME}:test-${BUILD_NUMBER}"
                    def containerName = "${APP_NAME}-test"
                    echo "=========================================="
                    echo "Deploying to test environment"
                    echo "Spring Profile: ${SPRING_PROFILE}"
                    echo "Container: ${containerName}"
                    echo "Port: ${APP_PORT}:9100"
                    echo "=========================================="
                }
                withCredentials([
                    usernamePassword(
                        credentialsId: 'db-test-credentials',
                        usernameVariable: 'DB_USER',
                        passwordVariable: 'DB_PASS'
                    ),
                    string(
                        credentialsId: 'db-test-url',
                        variable: 'DB_URL'
                    )
                ]) {
                    sh """
                        export CONTAINER_HOST=unix:///run/podman/podman.sock
                        KAFKA_IP=\$(podman inspect kafka --format '{{.NetworkSettings.Networks.podman.IPAddress}}' 2>/dev/null || echo "10.88.0.1")
                        echo "🔍 Detected Kafka IP: \${KAFKA_IP}"
                        podman stop ${APP_NAME}-test 2>/dev/null || true
                        podman rm ${APP_NAME}-test 2>/dev/null || true
                        podman run -d --name ${APP_NAME}-test \
                            --network podman \
                            --add-host kafka:\${KAFKA_IP} \
                            -e SPRING_PROFILES_ACTIVE=${SPRING_PROFILE} \
                            -e SPRING_DATASOURCE_URL=\${DB_URL} \
                            -e SPRING_DATASOURCE_USERNAME=\${DB_USER} \
                            -e SPRING_DATASOURCE_PASSWORD=\${DB_PASS} \
                            -e SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:9092 \
                            -p ${APP_PORT}:9100 \
                            --restart unless-stopped \
                            ${APP_NAME}:test-${BUILD_NUMBER}
                        echo 'Waiting for application to start...'
                        sleep 10
                        podman logs --tail 30 ${APP_NAME}-test
                    """
                }
                script {
                    echo "✅ TEST deployed with injected credentials"
                    echo "=========================================="
                    echo "✅ Deployment completed!"
                    echo "Application URL: http://localhost:${APP_PORT}"
                    echo "Container: ${APP_NAME}-test"
                    echo "Image: ${APP_NAME}:test-${BUILD_NUMBER}"
                    echo ""
                    echo "  View logs: podman logs -f ${APP_NAME}-test"
                    echo "  Stop:      podman stop ${APP_NAME}-test"
                    echo "  Restart:   podman restart ${APP_NAME}-test"
                    echo "=========================================="
                }
            }
        }

        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'build/libs/*.jar', fingerprint: true
            }
        }
    }

    post {
        success {
            echo "========================================="
            echo "✓ Build SUCCESS"
            echo "Build: #${BUILD_NUMBER}"
            echo "========================================="
        }
        failure {
            echo "========================================="
            echo "✗ Build FAILED"  
            echo "Build: #${BUILD_NUMBER}"
            echo "========================================="
        }
        always {
            cleanWs()
        }
    }
}
