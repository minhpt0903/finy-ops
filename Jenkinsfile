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
                    credentialsId: '9732e4f1-97d7-4a9e-9190-2350776a9450'
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
                    def latestTag = "${APP_NAME}:${params.ENVIRONMENT}-latest"
                    
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
                    def imageTag = "${APP_NAME}:${params.ENVIRONMENT}-${BUILD_NUMBER}"
                    def containerName = "${APP_NAME}-${params.ENVIRONMENT}"
                    
                    echo "=========================================="
                    echo "Deploying to ${params.ENVIRONMENT} environment"
                    echo "Spring Profile: ${SPRING_PROFILE}"
                    echo "Container: ${containerName}"
                    echo "Port: ${APP_PORT}:9200"
                    echo "=========================================="
                    
                    // Inject credentials từ Jenkins Credentials cho CẢ test và production
                    echo "🔐 Loading credentials from Jenkins Credentials..."
                    
                    // Xác định credential IDs dựa vào environment
                    def dbCredsId = params.ENVIRONMENT == 'production' ? 'db-production-credentials' : 'db-test-credentials'
                    def dbUrlId = params.ENVIRONMENT == 'production' ? 'db-production-url' : 'db-test-url'
                    
                    withCredentials([
                        usernamePassword(
                            credentialsId: dbCredsId,
                            usernameVariable: 'DB_USER',
                            passwordVariable: 'DB_PASS'
                        ),
                        string(
                            credentialsId: dbUrlId,
                            variable: 'DB_URL'
                        )
                    ]) {
                        sh """
                            export CONTAINER_HOST=unix:///run/podman/podman.sock
                            
                            # Stop old container
                            podman stop ${containerName} 2>/dev/null || true
                            podman rm ${containerName} 2>/dev/null || true
                            
                            # Run new container with injected credentials
                            podman run -d --name ${containerName} \\
                                --network podman \\
                                -e SPRING_PROFILES_ACTIVE=${SPRING_PROFILE} \\
                                -e SPRING_DATASOURCE_URL=\${DB_URL} \\
                                -e SPRING_DATASOURCE_USERNAME=\${DB_USER} \\
                                -e SPRING_DATASOURCE_PASSWORD=\${DB_PASS} \\
                                -p ${APP_PORT}:9200 \\
                                --restart unless-stopped \\
                                ${imageTag}
                            
                            # Wait and show logs
                            echo 'Waiting for application to start...'
                            sleep 10
                            podman logs --tail 30 ${containerName}
                        """
                    }
                    
                    echo "✅ ${params.ENVIRONMENT.toUpperCase()} deployed with injected credentials"
                    
                    echo "=========================================="
                    echo "✅ Deployment completed!"
                    echo "Application URL: http://localhost:${APP_PORT}"
                    echo "Container: ${containerName}"
                    echo "Image: ${imageTag}"
                    echo ""
                    echo "Commands:"
                    echo "  View logs: podman logs -f ${containerName}"
                    echo "  Stop:      podman stop ${containerName}"
                    echo "  Restart:   podman restart ${containerName}"
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
