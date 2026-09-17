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
        envVar(key: 'DOCKER_HOST', value: 'tcp://localhost:2375'),
        envVar(key: 'DOCKER_TLS_CERTDIR', value: '')
    ]
) {

    node(POD_LABEL) {

        def imageName = 'preetim28/nginx'
        def imageTag = "${env.BUILD_NUMBER}"
        def containerName = "nginx-ci-test-${env.BUILD_NUMBER}"

        try {

            stage('Checkout Repository') {

                container('docker') {

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'github-gitops',
                            usernameVariable: 'GITHUB_USERNAME',
                            passwordVariable: 'GITHUB_TOKEN'
                        )
                    ]) {

                        sh '''
                            echo "===== Cloning gitops-demo ====="

                            git clone \
                              https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com/Preetix28/gitops-demo.git \
                              gitops-demo

                            cd gitops-demo

                            git checkout master

                            echo "===== Repository ====="
                            git log -1 --oneline
                        '''
                    }
                }
            }

            stage('Validate Nginx Configuration') {

                dir('gitops-demo') {

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
            }

            stage('Build Docker Image') {

                dir('gitops-demo') {

                    container('docker') {

                        sh """
                            echo "===== Building Docker image ====="

                            docker build \
                              -t ${imageName}:${imageTag} \
                              .

                            echo "===== Image built ====="

                            docker images ${imageName}:${imageTag}
                        """
                    }
                }
            }

            stage('Run Container') {

                dir('gitops-demo') {

                    container('docker') {

                        sh """
                            echo "===== Starting test container ====="

                            docker run -d \
                              --name ${containerName} \
                              -p 8080:80 \
                              ${imageName}:${imageTag}

                            sleep 5

                            echo "===== Container status ====="

                            docker ps
                        """
                    }
                }
            }

            stage('Functional Tests') {

                dir('gitops-demo') {

                    container('docker') {

                        sh '''
                            echo "===== Installing test dependencies ====="

                            apk add --no-cache curl

                            echo "===== Running functional tests ====="

                            chmod +x tests/test.sh

                            ./tests/test.sh
                        '''
                    }
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

                            echo "===== Pushing image ====="

                            docker push ${imageName}:${imageTag}

                            docker logout

                            echo ""
                            echo "Image pushed:"
                            echo "${imageName}:${imageTag}"
                        """
                    }
                }
            }

            stage('Update GitOps Configuration') {

                dir('gitops-demo') {

                    container('docker') {

                        withCredentials([
                            usernamePassword(
                                credentialsId: 'github-gitops',
                                usernameVariable: 'GITHUB_USERNAME',
                                passwordVariable: 'GITHUB_TOKEN'
                            )
                        ]) {

                            sh """
                                echo "===== Current configuration ====="

                                grep -A5 '^nginx:' \
                                  environments/dev/values.yaml

                                echo ""
                                echo "===== Updating image tag ====="

                                sed -i \
                                  's/^    tag: ".*"/    tag: "${imageTag}"/' \
                                  environments/dev/values.yaml

                                echo ""
                                echo "===== Updated configuration ====="

                                grep -A5 '^nginx:' \
                                  environments/dev/values.yaml

                                echo ""
                                echo "===== Git status ====="

                                git status

                                git config user.name "Jenkins"
                                git config user.email "jenkins@localhost"

                                git add environments/dev/values.yaml

                                git commit \
                                  -m "Update nginx image to ${imageTag}"

                                echo ""
                                echo "===== Pushing GitOps change ====="

                                git push \
                                  https://\$GITHUB_USERNAME:\$GITHUB_TOKEN@github.com/Preetix28/gitops-demo.git \
                                  HEAD:master

                                echo ""
                                echo "===== GitOps update completed ====="
                            """
                        }
                    }
                }
            }

            echo """
            ========================================
            PIPELINE SUCCESSFUL
            ========================================

            Image:
            ${imageName}:${imageTag}

            Image pushed to Docker Hub.

            GitOps repository updated.

            Argo CD will now reconcile the change.

            ========================================
            """

        } finally {

            container('docker') {

                sh """
                    echo "===== Cleaning up test container ====="

                    docker stop ${containerName} || true
                    docker rm ${containerName} || true
                """
            }
        }
    }
}
