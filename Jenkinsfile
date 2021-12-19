pipeline {

  options {
    ansiColor('xterm')
  }

  agent {
    kubernetes {
      yamlFile 'builder.yaml'
    }
  }

  stages {
    stage('Deploy RabbitMQ App to Kubernetes') {     
      steps {
        container('kubectl') {
          withCredentials([file(credentialsId: 'mykubeconfig', variable: 'KUBECONFIG')]) {
            //sh 'sed -i "s/<TAG>/${BUILD_NUMBER}/" project.yaml'
            sh 'kubectl apply -f namespace.yaml'
            sh 'kubectl apply -f rabbitmq-deployment.yaml'
            sh 'kubectl apply -f rabbitmq-service.yaml'
            sh "name_space=`cat namespace.yaml | grep name: | tr -s ' ' | cut -d ' ' -f3`" 
            sh "cluster_ip=`kubectl -n $name_space describe svc rabbitmq-service | grep IP: | tr -s ' ' | cut -d ' ' -f2`"
            sh 'sed -i "s/rabbitmq/$cluster_ip/" producer-deployment.yaml'
            sh 'sed -i "s/rabbitmq/$cluster_ip/" consumer-deployment.yaml'
          }
        }
      }
    }
    stage('Build application images with Kaniko and push them into DockerHub public repository') {
      parallel {
        stage('Kaniko - build & push Producer app image') {
          steps {
            container('kaniko-1') {
              script {
                sh '''
                /kaniko/executor --context `pwd`/producer \
                                 --dockerfile `pwd`/producer/Dockerfile \
                                 --destination=alexfersh/producer:${BUILD_NUMBER} \
                                 --destination=alexfersh/producer:latest \
                                 --cleanup
                '''
              }
            }
          }
        }
        stage('Kaniko - build & push Consumer app image') {
          steps {
            container('kaniko-2') {
              script {
                sh '''
                /kaniko/executor --context `pwd`/consumer \
                                 --dockerfile `pwd`/consumer/Dockerfile \
                                 --destination=alexfersh/consumer:${BUILD_NUMBER} \
                                 --destination=alexfersh/consumer:latest \
                                 --cleanup
                '''
              }
            }
          }
        }
      }
    }
    /***
    stage('Wait for some useful output...') {     
      steps {
        container('kubectl') {
          withCredentials([file(credentialsId: 'mykubeconfig', variable: 'KUBECONFIG')]) {
            sh "cluster_ip=`kubectl describe svc rabbitmq-service | grep IP: | tr -s ' ' | cut -d ' ' -f2`"
            sh 'sed -i "s/rabbitmq/${cluster_ip}/" producer-deployment.yaml'
            sh 'sed -i "s/rabbitmq/${cluster_ip}/" consumer-deployment.yaml'
          }
        }
      }
    }
    ***/
    stage('Deploy Producer and Consumer Apps to Kubernetes') {     
      steps {
        container('kubectl') {
          withCredentials([file(credentialsId: 'mykubeconfig', variable: 'KUBECONFIG')]) {
            //sh 'sed -i "s/<TAG>/${BUILD_NUMBER}/" project.yaml'
            //sh 'sed -i "s/<TAG>/latest/" project.yaml'
            //sh 'kubectl apply -f project.yaml'
            sh 'sed -i "s/<TAG>/latest/" producer-deployment.yaml'
            sh 'sed -i "s/<TAG>/latest/" consumer-deployment.yaml'
            sh 'kubectl apply -f producer-deployment.yaml'
            sh 'kubectl apply -f consumer-deployment.yaml'
          }
        }
      }
    }
  }

}