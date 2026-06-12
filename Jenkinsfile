/* import shared library */
@Library('shared-library')_

pipeline {
    agent none

    environment {
        IMAGE_NAME     = "static-website" 
        IMAGE_TAG      = "${BUILD_NUMBER}"
        CONTAINER_TEST = "webapp-test-${BUILD_NUMBER}"
        TEST_PORT      = "5001"
        STAGING_HOST   = "13.220.117.66"
        PROD_HOST      = "54.205.240.32"
    }

    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timeout(time: 30, unit: 'MINUTES')
    }

    stages {
        stage('Checkout Source') {
            agent any
            steps {
                echo "Récupération automatique du code et des scripts depuis le Fork..."
                // Cette commande dit à Jenkins de récupérer la branche courante du repo configuré dans l'UI
                checkout scm
            }
        }

        stage('Build Image') {
            agent any
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    echo "Construction de l'image Docker..."
                    sh "docker build -t ${DOCKER_USER}/${IMAGE_NAME}:${IMAGE_TAG} ."
                }
            }
        }

        stage('Run container local') {
            agent any
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "Préparation de l'environnement de test local..."
                        OLD_CONTAINER=$(docker ps -q -f "publish=${TEST_PORT}")
                        if [ ! -z "$OLD_CONTAINER" ]; then
                            docker rm -f $OLD_CONTAINER
                        fi

                        docker rm -f ${CONTAINER_TEST} || true
                        
                        docker run --name ${CONTAINER_TEST} -d \
                            -p ${TEST_PORT}:80 \
                            ${DOCKER_USER}/${IMAGE_NAME}:${IMAGE_TAG}
                        sleep 5
                    '''
                }
            }
        }

        stage('Test image') {
            agent any
            steps {
                sh '''
                    echo "Vérification de la santé du conteneur..."
                    docker ps | grep ${CONTAINER_TEST} || (echo "Le conteneur n'a pas démarré !" && exit 1)
                    
                    # Récupération dynamique de l'IP interne du conteneur
                    CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_TEST})
                    
                    # Requête directe sur le port 80 du conteneur
                    curl -f http://${CONTAINER_IP}:80/ | grep -q "Welcome"
                    echo "Test d'intégration local réussi avec succès !"
                '''
            }
        }

        stage('Push Image to DockerHub') {
            agent any
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "Publication de l'image sur DockerHub..."
                        echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                        docker push ${DOCKER_USER}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker tag ${DOCKER_USER}/${IMAGE_NAME}:${IMAGE_TAG} ${DOCKER_USER}/${IMAGE_NAME}:latest
                        docker push ${DOCKER_USER}/${IMAGE_NAME}:latest
                        docker logout
                    '''
                }
            }
        }

        stage('Clean local test artifacts') {
            agent any
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "Nettoyage de l'agent Jenkins..."
                        docker rm -f ${CONTAINER_TEST} || true
                        docker rmi ${DOCKER_USER}/${IMAGE_NAME}:${IMAGE_TAG} || true
                    '''
                }
            }
        }

        stage('Deploy in staging') {
            agent any
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sshagent(credentials: ['staging-ssh']) {
                        sh '''
                            echo "Déploiement sur l'EC2 de Staging..."
                            command1="echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin"
                            command2="docker pull $DOCKER_USER/$IMAGE_NAME:$IMAGE_TAG"
                            command3="docker rm -f webapp || echo 'Aucune application existante à remplacer'"
                            command4="docker run -d -p 80:80 --name webapp --restart always $DOCKER_USER/$IMAGE_NAME:$IMAGE_TAG"
                            command5="sleep 3 && docker ps | grep webapp"
                            
                            ssh -o StrictHostKeyChecking=no ubuntu@${STAGING_HOST} "$command1 && $command2 && $command3 && $command4 && $command5"
                        '''
                    }
                }
            }
        }

        stage('Verify Staging') {
            agent any
            steps {
                sh '''
                    sleep 5
                    curl -f http://${STAGING_HOST}/ | grep -q "Welcome"
                    echo "L'environnement de Staging est opérationnel !"
                '''
            }
        }

        stage('Approval for Production') {
            agent none
            steps {
                timeout(time: 30, unit: 'MINUTES') {
                    input message: 'La validation de la Staging est réussie. Déployer en PRODUCTION ?',
                          ok: 'Oui, déployer !'
                }
            }
        }

        stage('Deploy in prod') {
            agent any
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sshagent(credentials: ['prod-ssh']) {
                        sh '''
                            echo "Déploiement sur l'EC2 de Production..."
                            command1="echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin"
                            command2="docker pull $DOCKER_USER/$IMAGE_NAME:$IMAGE_TAG"
                            command3="docker rm -f webapp || echo 'Aucune application existante à remplacer'"
                            command4="docker run -d -p 80:80 --name webapp --restart always $DOCKER_USER/$IMAGE_NAME:$IMAGE_TAG"
                            command5="sleep 3 && docker ps | grep webapp"
                            
                            ssh -o StrictHostKeyChecking=no ubuntu@${PROD_HOST} "$command1 && $command2 && $command3 && $command4 && $command5"
                        '''
                    }
                }
            }
        }

        stage('Verify Production') {
            agent any
            steps {
                sh '''
                    sleep 5
                    curl -f http://${PROD_HOST}/ | grep -q "Welcome"
                    echo "Production opérationnelle et validée !"
                '''
            }
        }
    }

    post {
        always {
            script {
                slackNotifier currentBuild.result
            }
        }  
    }
}
