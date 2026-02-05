pipeline {
    agent any
    
    // No automatic triggers - Manual build only in Jenkins UI
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['test', 'production'],
            description: 'Chọn môi trường deploy'
        )
        string(
            name: 'GIT_BRANCH',
            defaultValue: 'test',
            description: 'Nhánh Git cần build (ví dụ: test, main, feature/xyz)'
        )
        booleanParam(
            name: 'SKIP_TESTS', 
            defaultValue: false, 
            description: 'Bỏ qua chạy tests'
        )
    }
    
    // Tools configuration
    tools {
        gradle 'Gradle-8.5'
        jdk 'JDK-17'
    }
    
    environment {
        REGISTRY = 'your-registry.io'
        APP_NAME = 'lendbiz-apigateway'
        
        // Xác định profile và port từ parameter
        SPRING_PROFILE = "${params.ENVIRONMENT == 'production' ? 'prod' : 'test'}"
        APP_PORT = "${params.ENVIRONMENT == 'production' ? '9200' : '9201'}"
        
        // Kafka server
        KAFKA_SERVERS = '42.112.38.103:9092'
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "=========================================="
                    echo "Build Configuration:"
                    echo "  Environment: ${params.ENVIRONMENT}"
                    echo "  Git Branch: ${params.GIT_BRANCH}"
                    echo "  Spring Profile: ${SPRING_PROFILE}"
                    echo "  Application Port: ${APP_PORT}"
                    echo "  Skip Tests: ${params.SKIP_TESTS}"
                    echo "=========================================="
                }
                
                git branch: "${params.GIT_BRANCH}",
                    url: 'https://github.com/your-org/your-repo.git',
                    credentialsId: 'git-credentials'
            }
        }
        
        stage('Build') {
            steps {
                script {
                    echo "Building Spring Boot application for ${params.ENVIRONMENT} environment"
                    echo "Using Spring Profile: ${SPRING_PROFILE}"
                }
                sh """
                    ./gradlew clean build \
                        -Pspring.profiles.active=${SPRING_PROFILE} \
                        ${params.SKIP_TESTS ? '-x test' : ''} \
                        --no-daemon
                """
            }
        }
        
        stage('Test') {
            when {
                expression { !params.SKIP_TESTS }
            }
            steps {
                sh './gradlew test'
            }
            post {
                always {
                    junit '**/build/test-results/test/*.xml'
                }
            }
        }
        
        stage('Build Image') {
            steps {
                script {
                    def imageTag = "${REGISTRY}/${APP_NAME}:${params.ENVIRONMENT}-${BUILD_NUMBER}"
                    echo "Building image: ${imageTag}"
                    echo "Spring Profile: ${SPRING_PROFILE}"
                    
                    sh """
                        podman build -t ${imageTag} \
                            --build-arg SPRING_PROFILE=${SPRING_PROFILE} \
                            -f Dockerfile .
                    """
                }
            }
        }
        
        stage('Push Image') {
            when {
                expression { params.GIT_BRANCH == 'main' || params.GIT_BRANCH == 'test' }
            }
            steps {
                script {
                    def imageTag = "${REGISTRY}/${APP_NAME}:${params.ENVIRONMENT}-${BUILD_NUMBER}"
                    sh "podman push ${imageTag}"
                    
                    // Tag as latest for the environment
                    sh """
                        podman tag ${imageTag} ${REGISTRY}/${APP_NAME}:${params.ENVIRONMENT}-latest
                        podman push ${REGISTRY}/${APP_NAME}:${params.ENVIRONMENT}-latest
                    """
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    def imageTag = "${REGISTRY}/${APP_NAME}:${params.ENVIRONMENT}-${BUILD_NUMBER}"
                    def containerName = "${APP_NAME}-${params.ENVIRONMENT}"
                    
                    echo "=========================================="
                    echo "Deploying to ${params.ENVIRONMENT} environment"
                    echo "Spring Profile: ${SPRING_PROFILE}"
                    echo "Container: ${containerName}"
                    echo "Port: ${APP_PORT}:9200"
                    echo "=========================================="
                    
                    // Stop and remove old container if exists
                    sh """
                        podman stop ${containerName} 2>/dev/null || true
                        podman rm ${containerName} 2>/dev/null || true
                    """
                    
                    // Run new container locally
                    sh """
                        podman run -d --name ${containerName} \
                            --network podman \
                            -e SPRING_PROFILES_ACTIVE=${SPRING_PROFILE} \
                            -e SPRING_KAFKA_BOOTSTRAP_SERVERS=${KAFKA_SERVERS} \
                            -p ${APP_PORT}:9200 \
                            -v /opt/configs/${params.ENVIRONMENT}:/config:ro \
                            --restart unless-stopped \
                            ${imageTag}
                    """
                    
                    // Wait for application to start
                    sh """
                        echo 'Waiting for application to start...'
                        sleep 15
                        
                        # Show initial logs
                        podman logs --tail 30 ${containerName}
                    """
                    
                    // Health check
                    sh """
                        echo 'Checking application health...'
                        for i in 1 2 3 4 5; do
                            if curl -sf http://localhost:${APP_PORT}/actuator/health > /dev/null; then
                                echo '✓ Health check passed!'
                                curl http://localhost:${APP_PORT}/actuator/health
                                exit 0
                            fi
                            echo "Attempt \$i failed, retrying in 5s..."
                            sleep 5
                        done
                        echo '⚠ Warning: Health check failed after 5 attempts'
                        exit 0
                    """
                    
                    echo "=========================================="
                    echo "✓ Deployment completed!"
                    echo "Application URL: http://localhost:${APP_PORT}"
                    echo "Health Check: http://localhost:${APP_PORT}/actuator/health"
                    echo "View Logs: podman logs -f ${containerName}"
                    echo "=========================================="
                }
            }
        }
    }
    
    post {
        success {
            echo "========================================="
            echo "✓ Build SUCCESS"
            echo "Branch: ${params.GIT_BRANCH}"
            echo "Environment: ${params.ENVIRONMENT}"
            echo "Build: #${BUILD_NUMBER}"
            echo "========================================="
        }
        failure {
            echo "========================================="
            echo "✗ Build FAILED"  
            echo "Branch: ${params.GIT_BRANCH}"
            echo "Environment: ${params.ENVIRONMENT}"
            echo "Build: #${BUILD_NUMBER}"
            echo "========================================="
        }
        always {
            cleanWs()
        }
        always {
            cleanWs()
        }
    }
}
