podTemplate(
    containers: [

        containerTemplate(
            name: 'docker',
            image: 'docker:27-cli',
            ttyEnabled: true,
            command: 'cat'
        ),

        containerTemplate(
            name: 'dind',
            image: 'docker:27-dind',
            privileged: true,
            ttyEnabled: true,
            command: 'dockerd',
            args: '--host=tcp://0.0.0.0:2375 --host=unix:///var/run/docker.sock --tls=false'
        )
    ],

    envVars: [
        envVar(
            key: 'DOCKER_HOST',
            value: 'tcp://localhost:2375'
        ),
        envVar(
            key: 'DOCKER_TLS_CERTDIR',
            value: ''
        )
    ]
) {

    node(POD_LABEL) {

        def IMAGE_NAME = 'preetim28/nginx'
        def IMAGE_TAG = "${env.BUILD_NUMBER}"
        def CONTAINER_NAME = 'nginx-ci-test'

        try {

            stage('Checkout') {
                checkout scm
            }

            stage('Wait for Docker') {
                container('docker') {
                    sh '''
                        echo "===== Waiting for Docker daemon ====="

                        until docker info >/dev/null 2>&1
                        do
                            echo "Docker daemon is not ready..."
                            sleep 2
                        done

                        echo ""
                        echo "===== Docker Version ====="
                        docker version
                    '''
                }
            }

            stage('Validate Nginx Configuration') {
                container('docker') {
                    sh '''
                        echo "===== Validating nginx.conf ====="

                        docker run --rm \
                          -v "$PWD/nginx.conf:/etc/nginx/nginx.conf:ro" \
                          nginx:1.27-alpine \
                          nginx -t
                    '''
                }
            }

            stage('Build Docker Image') {
                container('docker') {
                    sh """
                        echo "===== Building Docker Image ====="

                        docker build \
                          -t ${IMAGE_NAME}:${IMAGE_TAG} \
                          .
                    """
                }
            }

            stage('Run Container') {
                container('docker') {
                    sh """
                        echo "===== Starting Nginx Container ====="

                        docker run -d \
                          --name ${CONTAINER_NAME} \
                          -p 8080:80 \
                          ${IMAGE_NAME}:${IMAGE_TAG}

                        echo ""
                        echo "===== Running Containers ====="
                        docker ps

                        echo ""
                        echo "===== Waiting for Nginx ====="
                        sleep 5
                    """
                }
            }

            stage('Functional Tests') {
                container('docker') {
                    sh '''
                        echo "===== Installing curl ====="
                        apk add --no-cache curl

                        echo ""
                        echo "===== Running Functional Tests ====="

                        chmod +x tests/test.sh

                        ./tests/test.sh
                    '''
                }
            }

            stage('Push Image') {
                container('docker') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-creds',
                            usernameVariable: 'DOCKER_USERNAME',
                            passwordVariable: 'DOCKER_PASSWORD'
                        )
                    ]) {

                        sh """
                            echo "===== Logging into Docker Hub ====="

                            echo "\$DOCKER_PASSWORD" | docker login \
                              -u "\$DOCKER_USERNAME" \
                              --password-stdin

                            echo ""
                            echo "===== Pushing Image ====="

                            docker push ${IMAGE_NAME}:${IMAGE_TAG}

                            echo ""
                            echo "===== Docker Image ====="
                            echo "${IMAGE_NAME}:${IMAGE_TAG}"

                            docker logout
                        """
                    }
                }
            }

            echo "========================================"
            echo "Nginx CI completed successfully."
            echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
            echo "========================================"

        } catch (err) {

            echo "========================================"
            echo "Nginx CI failed."
            echo "========================================"

            throw err

        } finally {

            stage('Cleanup') {
                container('docker') {
                    sh """
                        echo "===== Cleaning up test container ====="

                        docker stop ${CONTAINER_NAME} || true
                        docker rm ${CONTAINER_NAME} || true
                    """
                }
            }
        }
    }
}
