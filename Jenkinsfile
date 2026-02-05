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
            defaultValue: true, 
            description: 'Bỏ qua chạy tests'
        )
    }
    
    // Tools configuration
    tools {
        gradle 'Gradle-8.0'
        jdk 'JDK-17'
    }
    
    environment {
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
                    url: 'https://github.com/lendbiz/apigatewayfiny.git',
                    credentialsId: '4b9940ae-420e-427c-8259-5f8da377ea8d'
            }
        }
        
        stage('Build') {
            steps {
                script {
                    echo "Building Spring Boot application for ${params.ENVIRONMENT} environment"
                    echo "Using Spring Profile: ${SPRING_PROFILE}"
                }
                
                sh 'gradle --version'
                
                sh """
                    gradle clean build \
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
                sh 'gradle test'
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
                    def imageTag = "${APP_NAME}:${params.ENVIRONMENT}-${BUILD_NUMBER}"
                    echo "=========================================="
                    echo "Building container image..."
                    echo "Image: ${imageTag}"
                    echo "Spring Profile: ${SPRING_PROFILE}"
                    echo "=========================================="
                    
                    // Tạo Dockerfile inline nếu chưa có
                    sh '''
                        cat > Dockerfile.tmp <<'EOF'
FROM docker.io/openjdk:17-jdk-slim
WORKDIR /app
COPY build/libs/*.jar app.jar
EXPOSE 9200
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
                    '''
                    
                    sh """
                        export CONTAINER_HOST=unix:///var/run/podman.sock
                        podman build -t ${imageTag} -f Dockerfile.tmp .
                    """
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    def imageTag = "${APP_NAME}:${params.ENVIRONMENT}-${BUILD_NUMBER}"
                    def containerName = "${APP_NAME}-${params.ENVIRONMENT}"
                    
                    echo "=========================================="
                    echo "Deploying to ${params.ENVIRONMENT} environment"
                    echo "Spring Profile: ${SPRING_PROFILE}"
                    echo "Container: ${containerName}"
                    echo "Port: ${APP_PORT}:9200"
                    echo "=========================================="
                    
                    // Stop and remove old container if exists
                    sh """
                        export CONTAINER_HOST=unix:///var/run/podman.sock
                        podman stop ${containerName} 2>/dev/null || true
                        podman rm ${containerName} 2>/dev/null || true
                    """
                    
                    // Run new container
                    sh """
                        export CONTAINER_HOST=unix:///var/run/podman.sock
                        podman run -d --name ${containerName} \
                            --network podman \
                            -e SPRING_PROFILES_ACTIVE=${SPRING_PROFILE} \
                            -e SPRING_KAFKA_BOOTSTRAP_SERVERS=${KAFKA_SERVERS} \
                            -p ${APP_PORT}:9200 \
                            --restart unless-stopped \
                            ${imageTag}
                    """
                    
                    // Wait and check logs
                    sh """
                        export CONTAINER_HOST=unix:///var/run/podman.sock
                        echo 'Waiting for application to start...'
                        sleep 10
                        podman logs --tail 30 ${containerName}
                    """
                    
                    echo "=========================================="
                    echo "✓ Deployment completed!"
                    echo "Application URL: http://localhost:${APP_PORT}"
                    echo "View logs: podman logs -f ${containerName}"
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

    }
}
