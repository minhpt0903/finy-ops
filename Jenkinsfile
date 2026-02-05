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
        
        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'build/libs/*.jar', fingerprint: true
                
                echo "=========================================="
                echo "✅ Build completed!"
                echo "=========================================="
                echo "JAR file: build/libs/*.jar"
                echo "Environment: ${params.ENVIRONMENT}"
                echo "Spring Profile: ${SPRING_PROFILE}"
                echo ""
                echo "Download JAR from Jenkins UI, then deploy manually:"
                echo ""
                echo "# Build and deploy với Podman:"
                echo "# 1. Download JAR artifact từ Jenkins"
                echo "# 2. Build image:"
                echo "podman build -t ${APP_NAME}:${params.ENVIRONMENT} ."
                echo ""
                echo "# 3. Deploy:"
                echo "podman run -d --name ${APP_NAME}-${params.ENVIRONMENT} \\"
                echo "  --network podman \\"
                echo "  -e SPRING_PROFILES_ACTIVE=${SPRING_PROFILE} \\"
                echo "  -e SPRING_KAFKA_BOOTSTRAP_SERVERS=${KAFKA_SERVERS} \\"
                echo "  -p ${APP_PORT}:9200 \\"
                echo "  --restart unless-stopped \\"
                echo "  ${APP_NAME}:${params.ENVIRONMENT}"
                echo "=========================================="
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
