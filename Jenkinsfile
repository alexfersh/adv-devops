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
            releasename=`cat ./helm/values.yaml | grep name: | tr -s ' ' | cut -d ' ' -f2`

            helm upgrade $releasename bitnami/rabbitmq -f rabbitmq-values.yaml --install --force --namespace=$namespace

            servicename=`kubectl --namespace $namespace get svc | grep -w rabbitmq | grep -v headless | cut -d ' ' -f1`
            kubectl --namespace $namespace describe svc $servicename | grep IP: | tr -s ' ' | cut -d ' ' -f2 > clusterip.txt
            cluster_ip=`cat clusterip.txt`

            podname=`kubectl --namespace $namespace get pods | grep rabbitmq-0 | cut -d ' ' -f1`
            kubectl --namespace $namespace describe pods $podname | grep RABBITMQ_USERNAME: | tr -s ' ' | cut -d ' ' -f3 > rabbitmq_user.txt
            rabbitmq_username=`cat rabbitmq_user.txt`
            kubectl --namespace $namespace describe pods $podname | grep RABBITMQ_PASSWORD: | tr -s ' ' | tr -d "<'>" | cut -d ':' -f2 | cut -d ' ' -f9 > rabbitmq_secret.txt
            rabbitmq_secret=`cat rabbitmq_secret.txt`
            kubectl --namespace $namespace get secret $rabbitmq_secret -o jsonpath="{.data.rabbitmq-password}" | base64 -d > rabbitmq_pass.txt
            rabbitmq_password=`cat rabbitmq_pass.txt`

            sed -i "s/rabbitmq/$cluster_ip/" ./helm/templates/producer-deployment.yaml
            sed -i "s/rabbitmq/$cluster_ip/" ./helm/templates/consumer-deployment.yaml
            sed -i "s/('guest', 'guest')/('$rabbitmq_username', '$rabbitmq_password')/" ./consumer/consumer.py
            sed -i "s/('guest', 'guest')/('$rabbitmq_username', '$rabbitmq_password')/" ./producer/producer.py
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