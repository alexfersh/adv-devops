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
            export namespace=`cat ./helm/values.yaml | grep namespace: | tr -s ' ' | cut -d ' ' -f2`
            export releasename=`cat ./helm/values.yaml | grep releasename: | tr -s ' ' | cut -d ' ' -f2`

            if [[ -z (kubectl get namespace | grep $namespace) ]]
            then
            kubectl create $namespace
            fi

            if [[ -z (helm --namespace=$namespace list | grep $releasename) ]]
            then
            helm install $releasename bitnami/rabbitmq -f rabbitmq-values.yaml --namespace=$namespace

            export servicename=`kubectl --namespace $namespace get svc | grep -w rabbitmq | grep -v headless | cut -d ' ' -f1`
            kubectl --namespace $namespace describe svc $servicename | grep IP: | tr -s ' ' | cut -d ' ' -f2 > clusterip.txt
            export cluster_ip=`cat clusterip.txt`

            export podname=`kubectl --namespace $namespace get pods | grep rabbitmq-0 | cut -d ' ' -f1`
            kubectl --namespace $namespace describe pods $podname | grep RABBITMQ_USERNAME: | tr -s ' ' | cut -d ' ' -f3 > rabbitmq_user.txt
            export rabbitmq_username=`cat rabbitmq_user.txt`
            kubectl --namespace $namespace describe pods $podname | grep RABBITMQ_PASSWORD: | tr -s ' ' | tr -d "<'>" | cut -d ':' -f2 | cut -d ' ' -f9 > rabbitmq_secret.txt
            export rabbitmq_secret=`cat rabbitmq_secret.txt`
            kubectl --namespace $namespace get secret $rabbitmq_secret -o jsonpath="{.data.rabbitmq-password}" | base64 -d > rabbitmq_pass.txt
            export rabbitmq_password=`cat rabbitmq_pass.txt`

            sed -i "s/rabbitmq/$cluster_ip/" ./helm/templates/producer-deployment.yaml
            sed -i "s/rabbitmq/$cluster_ip/" ./helm/templates/consumer-deployment.yaml
            sed -i "s/('guest', 'guest')/('$rabbitmq_username', '$rabbitmq_password')/" ./consumer/consumer.py
            sed -i "s/('guest', 'guest')/('$rabbitmq_username', '$rabbitmq_password')/" ./producer/producer.py

            else
            export podname=`kubectl --namespace $namespace get pods | grep rabbitmq-0 | cut -d ' ' -f1`
            kubectl --namespace $namespace describe pods $podname | grep RABBITMQ_PASSWORD: | tr -s ' ' | tr -d "<'>" | cut -d ':' -f2 | cut -d ' ' -f9 > rabbitmq_secret.txt
            export rabbitmq_secret=`cat rabbitmq_secret.txt`
            export RABBITMQ_PASSWORD=$(kubectl --namespace $namespace get secret $rabbitmq_secret -o jsonpath="{.data.rabbitmq-password}" | base64 -d)
            export RABBITMQ_ERLANG_COOKIE=$(kubectl --namespace $namespace get secret $rabbitmq_secret -o jsonpath="{.data.rabbitmq-erlang-cookie}" | base64 -d)
            helm upgrade $releasename bitnami/rabbitmq -f rabbitmq-values.yaml --install --force --namespace=$namespace --set auth.password=$RABBITMQ_PASSWORD --set auth.erlangCookie=$RABBITMQ_ERLANG_COOKIE

            export servicename=`kubectl --namespace $namespace get svc | grep -w rabbitmq | grep -v headless | cut -d ' ' -f1`
            kubectl --namespace $namespace describe svc $servicename | grep IP: | tr -s ' ' | cut -d ' ' -f2 > clusterip.txt
            export cluster_ip=`cat clusterip.txt`

            export podname=`kubectl --namespace $namespace get pods | grep rabbitmq-0 | cut -d ' ' -f1`
            kubectl --namespace $namespace describe pods $podname | grep RABBITMQ_USERNAME: | tr -s ' ' | cut -d ' ' -f3 > rabbitmq_user.txt
            export rabbitmq_username=`cat rabbitmq_user.txt`
            kubectl --namespace $namespace describe pods $podname | grep RABBITMQ_PASSWORD: | tr -s ' ' | tr -d "<'>" | cut -d ':' -f2 | cut -d ' ' -f9 > rabbitmq_secret.txt
            export rabbitmq_secret=`cat rabbitmq_secret.txt`
            kubectl --namespace $namespace get secret $rabbitmq_secret -o jsonpath="{.data.rabbitmq-password}" | base64 -d > rabbitmq_pass.txt
            export rabbitmq_password=`cat rabbitmq_pass.txt`

            sed -i "s/rabbitmq/$cluster_ip/" ./helm/templates/producer-deployment.yaml
            sed -i "s/rabbitmq/$cluster_ip/" ./helm/templates/consumer-deployment.yaml
            sed -i "s/('guest', 'guest')/('$rabbitmq_username', '$rabbitmq_password')/" ./consumer/consumer.py
            sed -i "s/('guest', 'guest')/('$rabbitmq_username', '$rabbitmq_password')/" ./producer/producer.py

            fi
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
            releasename=`cat ./helm/values.yaml | grep releasename: | tr -s ' ' | cut -d ' ' -f2`
            helm upgrade $releasename-cons-prod ./helm --install --force --namespace=$namespace
            '''
          }
        }
      }
    }
  }

}