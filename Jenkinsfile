pipeline {

  options {
    ansiColor('xterm')
  }

  agent {
    kubernetes {
      defaultContainer 'jnlp'
      yamlFile 'builder.yaml'
    }
  }

  stages {
    stage('Deploy RabbitMQ App to Kubernetes') {     
      steps {
        container('helm') {
          withCredentials([file(credentialsId: 'mykubeconfig', variable: 'KUBECONFIG')]) {
            sh '''
            helm repo add bitnami https://charts.bitnami.com/bitnami
            helm repo update
            namespace=`cat ./helm/values.yaml | grep namespace: | tr -s ' ' | cut -d ' ' -f2`
            helm upgrade rabbitmq bitnami/rabbitmq -f rabbitmq-values.yaml --install --force --namespace=$namespace
            kubectl -n $namespace describe svc rabbitmq | grep IP: | tr -s ' ' | cut -d ' ' -f2 > clusterip.txt
            cluster_ip=`cat clusterip.txt`
            sed -i "s/rabbitmq/$cluster_ip/" ./helm/templates/producer-deployment.yaml
            sed -i "s/rabbitmq/$cluster_ip/" ./helm/templates/consumer-deployment.yaml
            '''
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
    stage('Deploy Producer and Consumer Apps to Kubernetes') {     
      steps {
        container('helm') {
          withCredentials([file(credentialsId: 'mykubeconfig', variable: 'KUBECONFIG')]) {
            sh '''
            sed -i "s/<TAG>/latest/" ./helm/templates/producer-deployment.yaml
            sed -i "s/<TAG>/latest/" ./helm/templates/consumer-deployment.yaml
            namespace=`cat ./helm/values.yaml | grep namespace: | tr -s ' ' | cut -d ' ' -f2`
            helm upgrade rabbitmq-cons-prod ./helm --install --force --namespace=$namespace
            '''
          }
        }
      }
    }
  }

}